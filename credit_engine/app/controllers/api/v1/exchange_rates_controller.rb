module Api
  module V1
    class ExchangeRatesController < BaseController
      def index
        rates = ExchangeRate.includes(:from_currency, :to_currency)
                            .order(reference_date: :desc, created_at: :desc)
                            .limit(50)

        render json: rates.as_json(
          only: [:id, :rate, :reference_date],
          include: {
            from_currency: { only: [:code, :symbol] },
            to_currency: { only: [:code, :symbol] }
          }
        )
      end

      def create
        from_curr = Currency.find_by!(code: exchange_rate_params[:from_currency_code])
        to_curr = Currency.find_by!(code: exchange_rate_params[:to_currency_code])
        rate = BigDecimal(exchange_rate_params[:rate].to_s)
        ref_date = exchange_rate_params[:reference_date].present? ? Date.parse(exchange_rate_params[:reference_date]) : Date.today

        if rate <= 0
          raise "A taxa cambial deve ser maior que zero."
        end

        # Use transaction to save both direct and reverse rates
        ActiveRecord::Base.transaction do
          # 1. Save direct rate
          @rate_direct = ExchangeRate.find_or_initialize_by(
            from_currency: from_curr,
            to_currency: to_curr,
            reference_date: ref_date
          )
          @rate_direct.rate = rate
          @rate_direct.save!

          # 2. Save reverse rate
          @rate_reverse = ExchangeRate.find_or_initialize_by(
            from_currency: to_curr,
            to_currency: from_curr,
            reference_date: ref_date
          )
          @rate_reverse.rate = (BigDecimal("1.0") / rate).round(8)
          @rate_reverse.save!
        end

        render json: @rate_direct.as_json(
          only: [:id, :rate, :reference_date],
          include: {
            from_currency: { only: [:code] },
            to_currency: { only: [:code] }
          }
        ), status: :created
      end

      private

      def exchange_rate_params
        params.require(:exchange_rate).permit(:from_currency_code, :to_currency_code, :rate, :reference_date)
      end
    end
  end
end
