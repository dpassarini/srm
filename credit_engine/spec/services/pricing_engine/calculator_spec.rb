require "rails_helper"

RSpec.describe PricingEngine::Calculator, type: :service do
  before do
    # Clean the database completely before each test
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    # 1 USD = 5 BRL (so 1 BRL = 0.2 USD)
    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.current)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.current)

    @duplicata_type = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque_type = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  describe ".calculate_receivable" do
    it "calcula duplicata mercantil em BRL sem conversao de moeda" do
      result = described_class.calculate_receivable(
        face_value: 1000.00,
        due_date: Date.current + 30.days,
        receivable_type_code: "duplicata",
        currency_code: "BRL",
        payment_currency_code: "BRL",
        base_rate: 0.0100,
        operation_date: Date.current
      )

      expect(result[:face_value]).to eq(1000.00)
      expect(result[:net_value_original]).to eq(975.6098)
      expect(result[:net_value]).to eq(975.6098)
      expect(result[:days_to_maturity]).to eq(30)
      expect(result[:spread_applied]).to eq(0.0150)
      expect(result[:exchange_rate_applied]).to be_nil
    end

    it "calcula cheque pre-datado em BRL sem conversao de moeda" do
      result = described_class.calculate_receivable(
        face_value: 1000.00,
        due_date: Date.current + 60.days,
        receivable_type_code: "cheque",
        currency_code: "BRL",
        payment_currency_code: "BRL",
        base_rate: 0.0,
        operation_date: Date.current
      )

      expect(result[:net_value_original]).to eq(951.8144)
      expect(result[:net_value]).to eq(951.8144)
      expect(result[:days_to_maturity]).to eq(60)
      expect(result[:spread_applied]).to eq(0.0250)
    end

    it "calcula titulo cross-currency BRL para USD usando taxa de cambio direta" do
      result = described_class.calculate_receivable(
        face_value: 1000.00,
        due_date: Date.current + 30.days,
        receivable_type_code: "duplicata",
        currency_code: "BRL",
        payment_currency_code: "USD",
        base_rate: 0.0,
        operation_date: Date.current
      )

      expect(result[:net_value_original]).to eq(985.2217)
      expect(result[:net_value]).to eq(197.0443)
      expect(result[:exchange_rate_applied]).to eq(0.2)
    end

    it "falha se a data de vencimento for anterior a operacao" do
      expect {
        described_class.calculate_receivable(
          face_value: 1000.00,
          due_date: Date.current - 1.day,
          receivable_type_code: "duplicata",
          currency_code: "BRL",
          payment_currency_code: "BRL",
          operation_date: Date.current
        )
      }.to raise_error(RuntimeError, /não pode ser anterior à data da operação/)
    end
  end

  describe ".calculate_operation" do
    it "calcula lote de titulos (operacao) com sucesso" do
      receivables_data = [
        { face_value: 1000.00, due_date: (Date.current + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
        { face_value: 2000.00, due_date: (Date.current + 60.days).to_s, receivable_type_code: "cheque", currency_code: "BRL" }
      ]

      operation_hash = described_class.calculate_operation(
        assignee: "Cedente Teste",
        payment_currency_code: "USD",
        receivables: receivables_data,
        operation_date: Date.current
      )

      expect(operation_hash[:assignee]).to eq("Cedente Teste")
      expect(operation_hash[:total_face_value]).to eq(3000.00)
      expect(operation_hash[:total_net_value]).to eq(577.7701)
      expect(operation_hash[:receivables_attributes].length).to eq(2)
    end
  end
end
