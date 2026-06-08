require "rails_helper"

RSpec.describe "Exchange Rates API", type: :request do
  before do
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.today)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.today)
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
end
