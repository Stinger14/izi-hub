package jobs

import (
	"time"

	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/contract"
)

type Status string

const (
	StatusQueued    Status = "queued"
	StatusRunning   Status = "running"
	StatusSucceeded Status = "succeeded"
	StatusFailed    Status = "failed"
	StatusDuplicate Status = "duplicate"
)

type Job struct {
	ID        string
	Status    Status
	Payload   contract.EmailIngestionRequest
	Result    *contract.IngestionResult
	Error     string
	CreatedAt time.Time
	UpdatedAt time.Time
}
