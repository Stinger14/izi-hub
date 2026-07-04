from app.services.parsers.bank_alert import BankAlertParser


def test_extract_type_treats_compra_as_purchase():
    parser = BankAlertParser()

    parsed = parser.parse(
        sender="alertas@popular.com",
        subject="Alerta de compra",
        body="Compra por RD$ 850.00 en Cafeteria tarjeta 1234",
    )

    assert parsed.transaction_type == "purchase"


def test_extract_bank_matches_qik_case_insensitively():
    parser = BankAlertParser()

    parsed = parser.parse(
        sender="alertas@qik.com.do",
        subject="Alerta de consumo",
        body="Consumo por RD$ 850.00 en Cafeteria tarjeta 1234",
    )

    assert parsed.bank_name == "QiK"
