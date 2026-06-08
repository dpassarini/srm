require "rails_helper"

RSpec.describe GenerateSettlementReportJob, type: :job do
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

  describe "#perform" do
    it "gera o conteudo do relatorio em formato CSV e muda o status para completed" do
      report = SettlementReport.create!(
        assignee_filter: "Empresa Teste",
        status: "pending",
        file_name: "extrato_teste.csv"
      )

      described_class.new.perform(report.id)

      report.reload
      expect(report.status).to eq("completed")
      expect(report.csv_content).to be_present

      # Parse and check CSV
      rows = CSV.parse(report.csv_content, col_sep: ";")
      expect(rows.length).to eq(2) # Header + 1 Data Row
      expect(rows[0]).to include("ID Operacao", "Cedente", "Valor de Face", "Valor Liquido")
      expect(rows[1]).to include(@operation.id.to_s, "Empresa Teste", "1000.0", "985.2217")
    end

    it "muda o status do relatorio para failed se a query falhar" do
      report = SettlementReport.create!(
        assignee_filter: "Empresa Teste",
        status: "pending",
        file_name: "extrato_teste.csv"
      )

      query_double = instance_double(Reports::SettlementReportQuery)
      allow(Reports::SettlementReportQuery).to receive(:new).and_return(query_double)
      allow(query_double).to receive(:execute).and_raise(StandardError.new("Query error"))

      expect {
        described_class.new.perform(report.id)
      }.to raise_error(StandardError, "Query error")

      report.reload
      expect(report.status).to eq("failed")
    end

    it "re-eleva o erro se a busca do relatorio falhar" do
      report = SettlementReport.create!(
        assignee_filter: "Empresa Teste",
        status: "pending",
        file_name: "extrato_teste.csv"
      )

      allow(SettlementReport).to receive(:find).with(report.id).and_raise(StandardError.new("Database connection lost"))

      expect {
        described_class.new.perform(report.id)
      }.to raise_error(StandardError, "Database connection lost")
    end
  end
end
