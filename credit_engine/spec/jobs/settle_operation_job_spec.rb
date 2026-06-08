require "rails_helper"

RSpec.describe SettleOperationJob, type: :job do
  before do
    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.current)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.current)

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @operation = Operation.create!(assignee: "Empresa Teste", payment_currency: @brl, total_face_value: 0.0, total_net_value: 0.0, status: "pending")
  end

  describe "#perform" do
    let(:valid_receivables_params) do
      [
        {
          "identifier" => "DUP-001",
          "face_value" => 1000.0,
          "due_date" => (Date.current + 30.days).to_s,
          "receivable_type_code" => "duplicata",
          "currency_code" => "BRL"
        }
      ]
    end

    it "liquida a operacao com sucesso atualizando os totais e recebiveis" do
      expect {
        described_class.new.perform(@operation.id, 0.0, valid_receivables_params)
      }.to change { Receivable.count }.by(1)

      @operation.reload
      expect(@operation.status).to eq("liquidated")
      expect(@operation.total_face_value.to_f).to eq(1000.0)
      expect(@operation.total_net_value.to_f).to eq(985.2217)

      receivable = @operation.receivables.first
      expect(receivable.identifier).to eq("DUP-001")
      expect(receivable.face_value.to_f).to eq(1000.0)
      expect(receivable.net_value.to_f).to eq(985.2217)
    end

    it "marca o status da operacao como failed e propaga o erro em caso de falha de validacao" do
      invalid_receivables_params = [
        {
          "identifier" => "DUP-BAD",
          "face_value" => -500.0, # valor negativo invalido
          "due_date" => (Date.current + 30.days).to_s,
          "receivable_type_code" => "duplicata",
          "currency_code" => "BRL"
        }
      ]

      expect {
        described_class.new.perform(@operation.id, 0.0, invalid_receivables_params)
      }.to raise_error(ActiveRecord::RecordInvalid)

      @operation.reload
      expect(@operation.status).to eq("failed")
      expect(Receivable.count).to eq(0)
    end
  end
end
