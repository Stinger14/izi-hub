from decimal import Decimal

from app.services.parsers.bank_alert_usd import BankAlertParserUsd


def test_can_parse_true_for_english_usd_alert():
    parser = BankAlertParserUsd()

    assert parser.can_parse(
        sender="alerts@bank.com",
        subject="Purchase Alert",
        body="Card purchase of $45.00 at Whole Foods Market",
    )


def test_can_parse_false_for_spanish_dop_alert():
    parser = BankAlertParserUsd()

    assert not parser.can_parse(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
    )


def test_parse_extracts_usd_amount_and_currency():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Purchase Alert",
        body="Card purchase of $1,250.00 at Whole Foods Market",
    )

    assert parsed.amount == Decimal("1250.00")
    assert parsed.currency == "USD"


def test_extract_type_treats_withdrawal_as_withdrawal():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Withdrawal Alert",
        body="Withdrawal of $200.00 from Main St ATM",
    )

    assert parsed.transaction_type == "withdrawal"


def test_extract_type_treats_transfer_received_as_transfer():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Transfer Alert",
        body="Transfer received of $500.00 from John Doe",
    )

    assert parsed.transaction_type == "transfer"


def test_extract_type_treats_purchase_keywords_as_purchase():
    parser = BankAlertParserUsd()

    for body in (
        "Purchase of $45.00 at Whole Foods Market",
        "Card purchase of $45.00 at Whole Foods Market",
        "Debit of $45.00 at Whole Foods Market",
    ):
        parsed = parser.parse(
            sender="alerts@bank.com", subject="Alert", body=body
        )
        assert parsed.transaction_type == "purchase"


def test_extract_type_treats_income_keywords_as_deposit():
    parser = BankAlertParserUsd()

    for body in (
        "Deposit of $45.00 from Employer Inc",
        "Payment received of $45.00 from Employer Inc",
        "Credit of $45.00 from Employer Inc",
    ):
        parsed = parser.parse(
            sender="alerts@bank.com", subject="Alert", body=body
        )
        assert parsed.transaction_type == "deposit"


def test_extract_merchant_matches_at_and_from_patterns():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Purchase Alert",
        body="Card purchase of $45.00 at Whole Foods Market",
    )

    assert parsed.merchant == "Whole Foods Market"


def test_extract_account_hint_matches_ending_in_pattern():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Purchase Alert",
        body="Card purchase of $45.00 at Whole Foods Market, card ending in 1234",
    )

    assert parsed.account_hint == "1234"


def test_extract_bank_sniffs_domain_from_sender():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="alerts@bank.com",
        subject="Purchase Alert",
        body="Card purchase of $45.00 at Whole Foods Market",
    )

    assert parsed.bank_name == "Bank"


def test_extract_bank_returns_none_when_sender_has_no_domain():
    parser = BankAlertParserUsd()

    parsed = parser.parse(
        sender="not-an-email",
        subject="Purchase Alert",
        body="Card purchase of $45.00 at Whole Foods Market",
    )

    assert parsed.bank_name is None
