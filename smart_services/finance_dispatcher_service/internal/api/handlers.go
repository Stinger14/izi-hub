package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/contract"
	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/jobs"
	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/storage"
)

type Handler struct {
	store storage.JobStore
}

func NewHandler(store storage.JobStore) *Handler {
	return &Handler{store: store}
}

func (h *Handler) CreateEmailJob(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var req contract.EmailIngestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	now := time.Now().UTC()
	job := jobs.Job{
		ID:        uuid.NewString(),
		Status:    jobs.StatusQueued,
		Payload:   req,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := h.store.Create(job); err != nil {
		if errors.Is(err, storage.ErrAlreadyExists) {
			http.Error(w, "job already exists", http.StatusConflict)
			return
		}

		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]any{
		"job_id": job.ID,
		"status": job.Status,
	})
}

func (h *Handler) GetJob(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	id := r.PathValue("id")
	job, err := h.store.Get(id)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			http.Error(w, "job not found", http.StatusNotFound)
			return
		}

		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, jobResponse{
		ID:        job.ID,
		Status:    string(job.Status),
		Payload:   job.Payload,
		Result:    job.Result,
		Error:     job.Error,
		CreatedAt: job.CreatedAt,
		UpdatedAt: job.UpdatedAt,
	})
}

type jobResponse struct {
	ID        string                         `json:"id"`
	Status    string                         `json:"status"`
	Payload   contract.EmailIngestionRequest `json:"payload"`
	Result    *contract.IngestionResult      `json:"result,omitempty"`
	Error     string                         `json:"error,omitempty"`
	CreatedAt time.Time                      `json:"created_at"`
	UpdatedAt time.Time                      `json:"updated_at"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
