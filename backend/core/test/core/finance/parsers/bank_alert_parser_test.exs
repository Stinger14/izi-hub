defmodule Core.Finance.Parsers.BankAlertParserTest do
  use ExUnit.Case, async: true

  alias Core.Finance.EmailMessage
  alias Core.Finance.Parsers.BankAlertParser

  defp message(attrs) do
    struct!(
      %EmailMessage{message_id: "<msg@bank.com>", from: "alerts@bank.com", subject: "Alert"},
      attrs
    )
  end

  test "parses a USD purchase alert" do
    message =
      message(
        from: "alerts@bank.com",
        subject: "Card purchase alert",
        text_body: """
        Card purchase alert
        Merchant: Cafe Central
        Amount: USD 54.25
        """
      )

    assert {:ok, result} = BankAlertParser.parse(message)
    assert result.currency == "USD"
    assert result.amount == Decimal.new("54.25")
    assert result.type == "expense"
    assert result.merchant == "Cafe Central"
  end

  test "parses a DOP purchase alert from a Dominican bank sender" do
    message =
      message(
        from: "alertas@popular.com",
        subject: "Alerta de consumo",
        text_body: "Consumo por RD$ 1,250.00 en Supermercado Nacional"
      )

    assert {:ok, result} = BankAlertParser.parse(message)
    assert result.currency == "DOP"
    assert result.amount == Decimal.new("1250.00")
    assert result.type == "expense"
    assert result.merchant == "Supermercado Nacional"
  end

  test "parses a DOP alert from qik" do
    message =
      message(
        from: "alertas@qik.com.do",
        subject: "Alerta de retiro",
        text_body: "Retiro por RD$ 2,000.00 en Cajero tarjeta 1234"
      )

    assert {:ok, result} = BankAlertParser.parse(message)
    assert result.currency == "DOP"
    assert result.type == "expense"
  end

  test "defaults to DOP currency when no explicit currency marker is present" do
    message =
      message(
        from: "alerts@bank.com",
        subject: "Deposit alert",
        text_body: "Deposit of $100.00 from Employer"
      )

    assert {:ok, result} = BankAlertParser.parse(message)
    assert result.currency == "DOP"
  end

  test "rejects emails from senders outside the supported bank scope" do
    message =
      message(
        from: "newsletter@retailer.com",
        subject: "Big purchase sale",
        text_body: "Purchase anything today and save"
      )

    assert BankAlertParser.parse(message) == :no_match
  end
end
