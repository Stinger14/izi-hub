from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.finance.repository import FinanceTransactionRepo
from app.services.ingestion_service import EmailIngestionService
from app.services.dedup import DedupService
from app.services.normalization import NormalizationService
from app.services.scoring import ScoringService


def get_email_ingestion_service(
    db: AsyncSession = Depends(get_db),
) -> EmailIngestionService:
    repo = FinanceTransactionRepo(db)

    return EmailIngestionService(
        repo=repo,
        dedup_service=DedupService(),
        normalization_service=NormalizationService(),
        scoring_service=ScoringService(),
    )
