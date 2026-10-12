from app.modules.finance.models import FinanceTransaction


def test_created_at_uses_callable_default():
    assert callable(FinanceTransaction.created_at.default.arg)


def test_finance_transaction_datetime_columns_are_timezone_aware():
    assert FinanceTransaction.occurred_at.type.timezone is True
    assert FinanceTransaction.created_at.type.timezone is True
