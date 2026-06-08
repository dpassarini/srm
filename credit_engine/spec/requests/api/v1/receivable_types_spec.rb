require "rails_helper"

RSpec.describe "Receivable Types API", type: :request do
  before do
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  describe "GET /api/v1/receivable_types" do
    it "retorna tipos de recebiveis cadastrados" do
      get api_v1_receivable_types_path
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.map { |rt| rt["code"] }.sort).to eq([ "cheque", "duplicata" ])
    end
  end
end
