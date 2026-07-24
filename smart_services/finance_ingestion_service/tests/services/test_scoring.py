from decimal import Decimal

from app.modules.finance.schemas import ParsedBankAlert
from app.services.scoring import ScoringService


def build_parsed(**overrides) -> ParsedBankAlert:
    defaults = dict(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("100.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text="raw",
    )
    defaults.update(overrides)
    return ParsedBankAlert(**defaults)


def test_dop_amount_at_threshold_scores_large_amount_bump():
    service = ScoringService()

    parsed = build_parsed(amount=Decimal("10000"), currency="DOP")

    assert service.score(parsed) >= 0.4


def test_dop_amount_below_threshold_does_not_score_large_amount_bump():
    service = ScoringService()

    parsed = build_parsed(amount=Decimal("9999"), currency="DOP")

    assert service.score(parsed) < 0.4


def test_usd_amount_at_threshold_scores_large_amount_bump():
    service = ScoringService()

    parsed = build_parsed(amount=Decimal("200"), currency="USD")

    assert service.score(parsed) >= 0.4


def test_usd_amount_below_dop_scale_but_above_usd_threshold_scores_bump():
    service = ScoringService()

    # Regression case: 500 would never have cleared the old hardcoded 10_000
    # DOP-scale threshold, but is well above the real USD large-amount bar.
    parsed = build_parsed(amount=Decimal("500"), currency="USD")

    assert service.score(parsed) >= 0.4


def test_usd_amount_below_usd_threshold_does_not_score_bump():
    service = ScoringService()

    parsed = build_parsed(amount=Decimal("199"), currency="USD")

    assert service.score(parsed) < 0.4


def test_unknown_currency_falls_back_to_dop_scale_threshold():
    service = ScoringService()

    parsed = build_parsed(amount=Decimal("10000"), currency="EUR")

    assert service.score(parsed) >= 0.4
