module Api
  module V1
    class CurrenciesController < BaseController
      def index
        currencies = Currency.all.order(:code)
        render json: currencies, only: [:id, :code, :name, :symbol]
      end
    end
  end
end
