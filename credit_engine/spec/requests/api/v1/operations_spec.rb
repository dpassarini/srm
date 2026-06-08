require "rails_helper"

RSpec.describe "Operations API", type: :request do
  include ActiveJob::TestHelper

  before do
    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.current)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.current)

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  describe "GET /api/v1/operations" do
    before do
      @op1 = Operation.create!(assignee: "Empresa Alfa", payment_currency: @brl, total_face_value: 1000.0, total_net_value: 985.22, status: "liquidated", created_at: Date.current - 5.days)
      @op2 = Operation.create!(assignee: "Empresa Beta", payment_currency: @usd, total_face_value: 2000.0, total_net_value: 1950.0, status: "pending", created_at: Date.current - 2.days)
      @op3 = Operation.create!(assignee: "Outra Empresa", payment_currency: @brl, total_face_value: 3000.0, total_net_value: 2955.66, status: "failed", created_at: Date.current)
    end

    it "retorna a lista paginada de operacoes ordenada por data decrescente" do
      get api_v1_operations_path, params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["operations"].length).to eq(2)
      expect(json["operations"].first["assignee"]).to eq("Outra Empresa") # op3 (Date.current)
      expect(json["operations"].second["assignee"]).to eq("Empresa Beta") # op2 (Date.current - 2.days)
      expect(json["meta"]["total_count"]).to eq(3)
      expect(json["meta"]["total_pages"]).to eq(2)
    end

    it "filtra pelo cedente (assignee) ignorando maiusculas/minusculas" do
      get api_v1_operations_path, params: { assignee: "alfa" }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["operations"].length).to eq(1)
      expect(json["operations"].first["assignee"]).to eq("Empresa Alfa")
    end

    it "filtra por moeda de pagamento" do
      get api_v1_operations_path, params: { payment_currency_code: "USD" }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["operations"].length).to eq(1)
      expect(json["operations"].first["assignee"]).to eq("Empresa Beta")
    end

    it "filtra por intervalo de datas" do
      get api_v1_operations_path, params: {
        start_date: (Date.current - 4.days).to_s,
        end_date: (Date.current - 1.day).to_s
      }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["operations"].length).to eq(1)
      expect(json["operations"].first["assignee"]).to eq("Empresa Beta")
    end
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

    it "retorna bad_request (400) se houver erro de simulacao (ex: data de vencimento retroativa)" do
      receivables_payload = [
        { identifier: "DUP-001", face_value: 1000.00, due_date: (Date.current - 5.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" }
      ]

      post simulate_api_v1_operations_path, params: {
        operation: {
          assignee: "Empresa XYZ",
          payment_currency_code: "BRL",
          base_rate: 0.0,
          receivables: receivables_payload
        }
      }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("não pode ser anterior à data da operação")
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

    it "retorna not_found (404) se a moeda informada nao existir" do
      post api_v1_operations_path, params: {
        operation: {
          assignee: "Empresa ABC",
          payment_currency_code: "EUR", # Moeda inexistente
          base_rate: 0.0,
          receivables: []
        }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "retorna unprocessable_entity (422) se a operacao for invalida (ex: sem cedente)" do
      post api_v1_operations_path, params: {
        operation: {
          assignee: "", # Cedente em branco invalido
          payment_currency_code: "BRL",
          base_rate: 0.0,
          receivables: []
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Entidade Não Processável")
      expect(json["details"]).to include("Assignee can't be blank")
    end
  end
end
