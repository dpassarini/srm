require "rails_helper"

RSpec.describe "Operations API", type: :request do
  include ActiveJob::TestHelper

  before do
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.current)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.current)

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  describe "POST /api/v1/operations/simulate" do
    it "executa simulação de lote sem salvar no banco" do
      receivables_payload = [
        { identifier: "DUP-001", face_value: 1000.00, due_date: (Date.current + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
        { identifier: "CHQ-001", face_value: 2000.00, due_date: (Date.current + 60.days).to_s, receivable_type_code: "cheque", currency_code: "BRL" }
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
      }.not_to change { [ Operation.count, Receivable.count ] }

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
        { identifier: "DUP-002", face_value: 1000.00, due_date: (Date.current + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" }
      ]

      perform_enqueued_jobs do
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
      end

      expect(response).to have_http_status(:created)

      operation = Operation.last
      expect(operation.status).to eq("liquidated")
      expect(operation.assignee).to eq("Empresa ABC")
      expect(operation.total_face_value.to_f).to eq(1000.00)
      expect(operation.total_net_value.to_f).to eq(985.2217)

      receivable = operation.receivables.first
      expect(receivable.identifier).to eq("DUP-002")
      expect(receivable.face_value.to_f).to eq(1000.00)
      expect(receivable.net_value.to_f).to eq(985.2217)
    end

    it "cria operação e depois falha na liquidação se houver dados inválidos" do
      receivables_payload = [
        { identifier: "DUP-GOOD", face_value: 1000.00, due_date: (Date.current + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
        { identifier: "DUP-BAD", face_value: -500.00, due_date: (Date.current + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" } # face value negativo inválido
      ]

      perform_enqueued_jobs do
        expect {
          post api_v1_operations_path, params: {
            operation: {
              assignee: "Empresa Falha",
              payment_currency_code: "BRL",
              base_rate: 0.0,
              receivables: receivables_payload
            }
          }
        }.to change { Operation.count }.by(1)
      end

      operation = Operation.last
      expect(operation.status).to eq("failed")
      expect(Receivable.count).to eq(0)
    end
  end
end
