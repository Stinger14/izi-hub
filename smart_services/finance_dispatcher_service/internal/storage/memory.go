package storage

import (
	"errors"
	"sync"
	"time"

	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/contract"
	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/jobs"
)

var ErrNotFound = errors.New("job not found")
var ErrAlreadyExists = errors.New("job already exists")
var ErrInvalidTransition = errors.New("invalid job status transition")

type JobStore interface {
	Create(job jobs.Job) error
	Get(id string) (jobs.Job, error)
	MarkRunning(id string, now time.Time) error
	MarkSucceeded(id string, result contract.IngestionResult, now time.Time) error
	MarkDuplicated(id string, result contract.IngestionResult, now time.Time) error
	MarkFailed(id string, message string, now time.Time) error
}

type MemoryStore struct {
	mu   sync.RWMutex
	jobs map[string]jobs.Job
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		jobs: make(map[string]jobs.Job),
	}
}

func (s *MemoryStore) Create(job jobs.Job) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.jobs[job.ID]; exists {
		return ErrAlreadyExists
	}

	s.jobs[job.ID] = job
	return nil
}

func (s *MemoryStore) Get(id string) (jobs.Job, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	job, ok := s.jobs[id]
	if !ok {
		return jobs.Job{}, ErrNotFound
	}

	return job, nil
}

func (s *MemoryStore) MarkRunning(id string, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, ok := s.jobs[id]
	if !ok {
		return ErrNotFound
	}

	if job.Status != jobs.StatusQueued {
		return ErrInvalidTransition
	}

	job.Status = jobs.StatusRunning
	job.UpdatedAt = now
	s.jobs[id] = job

	return nil
}

func (s *MemoryStore) MarkSucceeded(id string, result contract.IngestionResult, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, ok := s.jobs[id]
	if !ok {
		return ErrNotFound
	}

	if job.Status != jobs.StatusRunning {
		return ErrInvalidTransition
	}

	job.Status = jobs.StatusSucceeded
	job.Result = &result
	job.Error = ""
	job.UpdatedAt = now
	s.jobs[id] = job

	return nil
}

func (s *MemoryStore) MarkDuplicated(id string, result contract.IngestionResult, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, ok := s.jobs[id]
	if !ok {
		return ErrNotFound
	}

	if job.Status != jobs.StatusRunning {
		return ErrInvalidTransition
	}

	job.Status = jobs.StatusDuplicate
	job.Result = &result
	job.Error = ""
	job.UpdatedAt = now
	s.jobs[id] = job

	return nil
}

func (s *MemoryStore) MarkFailed(id string, message string, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, ok := s.jobs[id]
	if !ok {
		return ErrNotFound
	}

	if job.Status != jobs.StatusRunning {
		return ErrInvalidTransition
	}

	job.Status = jobs.StatusFailed
	job.Result = nil
	job.Error = message
	job.UpdatedAt = now
	s.jobs[id] = job

	return nil
}
