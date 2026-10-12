from fastapi import APIRouter, Depends, HTTPException

from app.core.security import verify_ingestion_api_key
from app.modules.finance.dependencies import get_email_ingestion_service
from app.modules.finance.exceptions import NoParserMatchedError
from app.modules.finance.schemas import (
    EmailIngestionRequest,
    IngestionResult,
)
from app.services.ingestion_service import EmailIngestionService

router = APIRouter(prefix="/finance/ingestion", tags=["Email ingestion"])


@router.post(
    "/email",
    response_model=IngestionResult,
    dependencies=[Depends(verify_ingestion_api_key)],
)
async def ingest_email(
    payload: EmailIngestionRequest,
    service: EmailIngestionService = Depends(get_email_ingestion_service),
):
    try:
        return await service.ingest(payload)
    except NoParserMatchedError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
