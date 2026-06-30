from app.modules.finance.schemas import (
    EmailIngestionRequest,
    IngestionResult,
)
from app.modules.finance.repository import FinanceTransactionRepo
from app.services.parsers.bank_alert import BankAlertParser
from app.services.dedup import DedupService
from app.services.normalization import NormalizationService
from app.services.scoring import ScoringService


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

        transaction = await self.repo.create(
            sender=payload.sender,
            subject=payload.subject,
            parsed=parsed,
            dedup_hash=dedup_hash,
            score=score,
        )

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

        raise ValueError("No parser available for this email")
