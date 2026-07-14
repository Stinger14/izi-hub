package fastapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/contract"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

type APIError struct {
	StatusCode int
	Body       string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("fastapi returned %d: %s", e.StatusCode, e.Body)
}

func NewClient(baseURL string, timeout time.Duration) *Client {
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (c *Client) IngestEmail(ctx context.Context, req contract.EmailIngestionRequest) (contract.IngestionResult, error) {
	var result contract.IngestionResult

	payload, err := json.Marshal(req)
	if err != nil {
		return result, fmt.Errorf("marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		c.baseURL+"/api/v1/finance/ingestion/email",
		bytes.NewReader(payload),
	)
	if err != nil {
		return result, fmt.Errorf("create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return result, fmt.Errorf("send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return result, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return result, &APIError{
			StatusCode: resp.StatusCode,
			Body:       strings.TrimSpace(string(body)),
		}
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return result, fmt.Errorf("decode response: %w", err)
	}

	return result, nil
}
