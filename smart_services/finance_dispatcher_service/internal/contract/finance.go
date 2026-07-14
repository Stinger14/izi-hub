package contract

import "time"

type EmailIngestionRequest struct {
	Sender     string     `json:"sender"`
	Subject    string     `json:"subject"`
	Body       string     `json:"body"`
	ReceivedAt *time.Time `json:"received_at,omitempty"`
}

type IngestionResult struct {
	Status        string  `json:"status"`
	Duplicate     bool    `json:"duplicate"`
	Score         float64 `json:"score"`
	TransactionID *int64  `json:"transaction_id,omitempty"`
}
