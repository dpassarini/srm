require "rails_helper"

RSpec.describe "Settlement Reports API", type: :request do
  include ActiveJob::TestHelper

  before do
    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)

    @operation = Operation.create!(assignee: "Empresa Teste", payment_currency: @brl, total_face_value: 1000.0, total_net_value: 985.2217, status: "liquidated")
    @receivable = @operation.receivables.create!(
      identifier: "DUP-123",
      face_value: 1000.00,
      net_value: 985.2217,
      due_date: Date.current + 30.days,
      days_to_maturity: 30,
      spread_applied: 0.015,
      base_rate_applied: 0.0,
      currency: @brl,
      receivable_type: @duplicata
    )
  end

  describe "POST /api/v1/settlement_reports" do
    it "cria registro de relatorio e agenda o processamento assincrono" do
      expect {
        post api_v1_settlement_reports_path, params: {
          settlement_report: {
            assignee_filter: "Empresa Teste",
            payment_currency_code_filter: "BRL"
          }
        }
      }.to change { SettlementReport.count }.by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("pending")
      expect(json["assignee_filter"]).to eq("Empresa Teste")
      expect(json["payment_currency_code_filter"]).to eq("BRL")
    end
  end

  describe "GET /api/v1/settlement_reports" do
    before do
      SettlementReport.create!(status: "completed", assignee_filter: "Empresa A")
      SettlementReport.create!(status: "pending", assignee_filter: "Empresa B")
    end

    it "retorna a lista de relatorios gerados" do
      get api_v1_settlement_reports_path
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.first["assignee_filter"]).to eq("Empresa B") # ordenado por created_at desc
    end
  end

  describe "Background Processing and CSV Download" do
    it "processa o job em segundo plano, gera o CSV e permite o download" do
      post api_v1_settlement_reports_path, params: {
        settlement_report: {
          assignee_filter: "Empresa Teste"
        }
      }
      report = SettlementReport.last

      perform_enqueued_jobs do
        GenerateSettlementReportJob.perform_later(report.id)
      end

      report.reload
      expect(report.status).to eq("completed")
      expect(report.csv_content).to include("Empresa Teste")
      expect(report.csv_content).to include("DUP-123")

      # Download endpoint
      get download_api_v1_settlement_report_path(report)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to include("Empresa Teste")
      expect(response.body).to include("DUP-123")
    end
  end
end
