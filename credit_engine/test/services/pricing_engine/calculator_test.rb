require "test_helper"

class PricingEngineCalculatorTest < ActiveSupport::TestCase
  setup do
    # Garante banco limpo e populado com os dados essenciais para o teste
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    # 1 USD = 5 BRL (então 1 BRL = 0.2 USD)
    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.today)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.today)

    @duplicata_type = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque_type = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  test "calcula duplicata mercantil em BRL sem conversao de moeda" do
    # Valor Presente = 1000 / (1 + 0.01 + 0.015)^1.0 = 1000 / 1.025 = 975.6098
    result = PricingEngine::Calculator.calculate_receivable(
      face_value: 1000.00,
      due_date: Date.today + 30.days,
      receivable_type_code: "duplicata",
      currency_code: "BRL",
      payment_currency_code: "BRL",
      base_rate: 0.0100, # 1% a.m.
      operation_date: Date.today
    )

    assert_equal 1000.00, result[:face_value]
    assert_equal 975.6098, result[:net_value_original]
    assert_equal 975.6098, result[:net_value]
    assert_equal 30, result[:days_to_maturity]
    assert_equal 0.0150, result[:spread_applied]
    assert_nil result[:exchange_rate_applied]
  end

  test "calcula cheque pre-datado em BRL sem conversao de moeda" do
    # Valor Presente = 1000 / (1 + 0.0 + 0.025)^2.0 = 1000 / 1.025^2 = 1000 / 1.050625 = 951.8144
    result = PricingEngine::Calculator.calculate_receivable(
      face_value: 1000.00,
      due_date: Date.today + 60.days,
      receivable_type_code: "cheque",
      currency_code: "BRL",
      payment_currency_code: "BRL",
      base_rate: 0.0,
      operation_date: Date.today
    )

    assert_equal 951.8144, result[:net_value_original]
    assert_equal 951.8144, result[:net_value]
    assert_equal 60, result[:days_to_maturity]
    assert_equal 0.0250, result[:spread_applied]
  end

  test "calcula titulo cross-currency BRL para USD usando taxa de cambio direta" do
    # PV em BRL = 1000 / (1 + 0.015)^1.0 = 985.2217
    # Convertido para USD (taxa BRL -> USD = 0.2): 985.2217 * 0.2 = 197.0443
    result = PricingEngine::Calculator.calculate_receivable(
      face_value: 1000.00,
      due_date: Date.today + 30.days,
      receivable_type_code: "duplicata",
      currency_code: "BRL",
      payment_currency_code: "USD",
      base_rate: 0.0,
      operation_date: Date.today
    )

    assert_equal 985.2217, result[:net_value_original]
    assert_equal 197.0443, result[:net_value]
    assert_equal 0.2, result[:exchange_rate_applied]
  end

  test "calcula lote de titulos (operacao) com sucesso" do
    receivables_data = [
      { face_value: 1000.00, due_date: Date.today + 30.days, receivable_type_code: "duplicata", currency_code: "BRL" },
      { face_value: 2000.00, due_date: Date.today + 60.days, receivable_type_code: "cheque", currency_code: "BRL" }
    ]

    # Titulo 1 BRL -> USD: 985.2217 * 0.2 = 197.0443
    # Titulo 2 BRL -> USD: PV BRL = 2000 / (1 + 0.025)^2 = 1903.6288 BRL -> USD: 1903.6288 * 0.2 = 380.7258
    # Total Face Value BRL = 3000
    # Total Net Value USD = 197.0443 + 380.7258 = 577.7701
    operation_hash = PricingEngine::Calculator.calculate_operation(
      assignee: "Cedente Teste",
      payment_currency_code: "USD",
      receivables: receivables_data,
      operation_date: Date.today
    )

    assert_equal "Cedente Teste", operation_hash[:assignee]
    assert_equal 3000.00, operation_hash[:total_face_value]
    assert_equal 577.7701, operation_hash[:total_net_value]
    assert_equal 2, operation_hash[:receivables_attributes].length
  end

  test "falha se a data de vencimento for anterior a operacao" do
    assert_raises RuntimeError do
      PricingEngine::Calculator.calculate_receivable(
        face_value: 1000.00,
        due_date: Date.today - 1.day,
        receivable_type_code: "duplicata",
        currency_code: "BRL",
        payment_currency_code: "BRL",
        operation_date: Date.today
      )
    end
  end
end
