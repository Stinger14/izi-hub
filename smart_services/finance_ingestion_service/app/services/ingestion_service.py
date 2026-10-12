import logging

from app.core.config import settings
from app.modules.finance.exceptions import (
    DuplicateTransactionError,
    NoParserMatchedError,
)
from app.modules.finance.izihub_client import forward_to_izihub
from app.modules.finance.repository import FinanceTransactionRepo
from app.modules.finance.schemas import (
    EmailIngestionRequest,
    IngestionResult,
)
from app.services.dedup import DedupService
from app.services.normalization import NormalizationService
from app.services.parsers.bank_alert import BankAlertParser
from app.services.scoring import ScoringService

logger = logging.getLogger(__name__)


class EmailIngestionService:
    def __init__(
        self,
        repo: FinanceTransactionRepo,
        dedup_service: DedupService,
        normalization_service: NormalizationService,
        scoring_service: ScoringService,
    ):
        self.repo = repo
        self.dedup_service = dedup_service
        self.normalization_service = normalization_service
        self.scoring_service = scoring_service
        self.parsers = [
            BankAlertParser(),
        ]

    async def ingest(self, payload: EmailIngestionRequest) -> IngestionResult:
        parser = self._select_parser(payload)

        parsed = parser.parse(
            sender=payload.sender,
            subject=payload.subject,
            body=payload.body,
        )

        parsed = self.normalization_service.normalize(parsed)

        if parsed.occurred_at is None and payload.received_at is not None:
            parsed.occurred_at = payload.received_at

        dedup_hash = self.dedup_service.create_hash(
            parsed=parsed,
            sender=payload.sender,
            subject=payload.subject,
        )

        if await self.repo.exists_by_hash(dedup_hash):
            return IngestionResult(
                status="duplicate",
                duplicate=True,
                score=0,
                transaction_id=None,
            )

        score = self.scoring_service.score(parsed)

        try:
            transaction = await self.repo.create(
                sender=payload.sender,
                subject=payload.subject,
                parsed=parsed,
                dedup_hash=dedup_hash,
                score=score,
            )
        except DuplicateTransactionError:
            return IngestionResult(
                status="duplicate",
                duplicate=True,
                score=0,
                transaction_id=None,
            )

        if payload.ingestion_token:
            await forward_to_izihub(payload, settings)

        return IngestionResult(
            status="ingested",
            duplicate=False,
            score=score,
            transaction_id=transaction.id,
        )

    def _select_parser(self, payload: EmailIngestionRequest):
        for parser in self.parsers:
            if parser.can_parse(payload.sender, payload.subject, payload.body):
                return parser

        logger.debug(
            "no parser matched sender=%s subject=%r", payload.sender, payload.subject
        )
        raise NoParserMatchedError("No parser available for this email")
