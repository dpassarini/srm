require "rails_helper"

RSpec.describe "API V1 Endpoints", type: :request do
  before do
    # Clean the database completely before each test
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.today)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.today)

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  describe "GET /api/v1/currencies" do
    it "retorna moedas cadastradas" do
      get api_v1_currencies_path
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.map { |c| c["code"] }.sort).to eq(["BRL", "USD"])
    end
  end

  describe "GET /api/v1/receivable_types" do
    it "retorna tipos de recebiveis cadastrados" do
      get api_v1_receivable_types_path
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.map { |rt| rt["code"] }.sort).to eq(["cheque", "duplicata"])
    end
  end

  describe "POST /api/v1/exchange_rates" do
    it "cria nova taxa de câmbio e gera taxa reversa correspondente" do
      post api_v1_exchange_rates_path, params: {
        exchange_rate: {
          from_currency_code: "USD",
          to_currency_code: "BRL",
          rate: 5.5,
          reference_date: (Date.today + 1.day).to_s
        }
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["rate"].to_f).to eq(5.5)

      # Verifica se a reversa foi gerada automaticamente para a mesma data
      reverse_rate = ExchangeRate.find_by(
        from_currency: @brl,
        to_currency: @usd,
        reference_date: Date.today + 1.day
      )
      expect(reverse_rate).not_to be_nil
      expect(reverse_rate.rate.to_f).to eq((1.0 / 5.5).round(8))
    end
  end

  describe "POST /api/v1/operations/simulate" do
    it "executa simulação de lote sem salvar no banco" do
      receivables_payload = [
        { identifier: "DUP-001", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
        { identifier: "CHQ-001", face_value: 2000.00, due_date: (Date.today + 60.days).to_s, receivable_type_code: "cheque", currency_code: "BRL" }
      ]

      expect {
        post simulate_api_v1_operations_path, params: {
          operation: {
            assignee: "Empresa XYZ",
            payment_currency_code: "USD",
            base_rate: 0.0,
            receivables: receivables_payload
          }
        }
      }.not_to change { [Operation.count, Receivable.count] }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["assignee"]).to eq("Empresa XYZ")
      expect(json["total_face_value"].to_f).to eq(3000.00)
      expect(json["total_net_value"].to_f).to eq(577.7701) # valor calculado em USD
      expect(json["receivables_attributes"].length).to eq(2)
    end
  end

  describe "POST /api/v1/operations" do
    it "cria e liquida operação atomicamente persistindo no banco" do
      receivables_payload = [
        { identifier: "DUP-002", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" }
      ]

      expect {
        post api_v1_operations_path, params: {
          operation: {
            assignee: "Empresa ABC",
            payment_currency_code: "BRL",
            base_rate: 0.0,
            receivables: receivables_payload
          }
        }
      }.to change { Operation.count }.by(1).and change { Receivable.count }.by(1)

      expect(response).to have_http_status(:created)

      operation = Operation.last
      expect(operation.assignee).to eq("Empresa ABC")
      expect(operation.total_face_value.to_f).to eq(1000.00)
      expect(operation.total_net_value.to_f).to eq(985.2217)

      receivable = operation.receivables.first
      expect(receivable.identifier).to eq("DUP-002")
      expect(receivable.face_value.to_f).to eq(1000.00)
      expect(receivable.net_value.to_f).to eq(985.2217)
    end

    it "falha na criação e mantém atomicidade do banco se houver dados inválidos" do
      receivables_payload = [
        { identifier: "DUP-GOOD", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
        { identifier: "DUP-BAD", face_value: -500.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" } # face value negativo inválido
      ]

      expect {
        post api_v1_operations_path, params: {
          operation: {
            assignee: "Empresa Falha",
            payment_currency_code: "BRL",
            base_rate: 0.0,
            receivables: receivables_payload
          }
        }
      }.not_to change { [Operation.count, Receivable.count] }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
