package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/contract"
	"github.com/Stinger14/izi-hub/smart_services/finance_dispatcher_service/internal/fastapi"
)

func main() {
	baseURL := os.Getenv("FASTAPI_BASE_URL")
	if baseURL == "" {
		baseURL = "http://127.0.0.1:8000"
	}

	client := fastapi.NewClient(baseURL, 10*time.Second)

	receivedAt := time.Now().UTC()
	req := contract.EmailIngestionRequest{
		Sender:     "alertas@popular.com",
		Subject:    "Alerta de consumo",
		Body:       "Consumo por RD$ 1,250.00 en Nacional tarjecta 1234",
		ReceivedAt: &receivedAt,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	result, err := client.IngestEmail(ctx, req)
	if err != nil {
		log.Fatalf("ingestion failed: %v", err)
	}

	fmt.Printf(
		"status=%s duplicate=%t score=%.2f transaction_id=%v\n",
		result.Status,
		result.Duplicate,
		result.Score,
		result.TransactionID,
	)
}
