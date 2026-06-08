require "rails_helper"

RSpec.describe "Currencies API", type: :request do
  before do
    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")
  end

  describe "GET /api/v1/currencies" do
    it "retorna moedas cadastradas" do
      get api_v1_currencies_path
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.map { |c| c["code"] }.sort).to eq([ "BRL", "USD" ])
    end
  end
end
