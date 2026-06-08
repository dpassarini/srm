module Api
  module V1
    class OperationsController < BaseController
      # GET /api/v1/operations (Analytical History with server-side pagination and filters)
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page

        scope = Operation.includes(:payment_currency, receivables: [:currency, :receivable_type])

        # Filters
        if params[:assignee].present?
          scope = scope.where("assignee ILIKE ?", "%#{params[:assignee]}%")
        end

        if params[:payment_currency_code].present?
          scope = scope.joins(:payment_currency).where(currencies: { code: params[:payment_currency_code] })
        end

        if params[:start_date].present?
          scope = scope.where("operations.created_at >= ?", Time.zone.parse(params[:start_date]).beginning_of_day)
        end

        if params[:end_date].present?
          scope = scope.where("operations.created_at <= ?", Time.zone.parse(params[:end_date]).end_of_day)
        end

        total_count = scope.count
        operations = scope.order(created_at: :desc).limit(per_page).offset(offset)

        render json: {
          operations: operations.as_json(
            include: {
              payment_currency: { only: [:code, :symbol] },
              receivables: {
                include: {
                  currency: { only: [:code, :symbol] },
                  receivable_type: { only: [:code, :name] }
                }
              }
            }
          ),
          meta: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          }
        }
      end

      # POST /api/v1/operations/simulate
      def simulate
        data = PricingEngine::Calculator.calculate_operation(
          assignee: operation_params[:assignee],
          payment_currency_code: operation_params[:payment_currency_code],
          receivables: (operation_params[:receivables] || []).map(&:to_h),
          base_rate: operation_params[:base_rate] || 0.0
        )
        render json: data
      end

      # POST /api/v1/operations (Liquidation inside ACID transaction)
      def create
        # 1. Run calculations through Strategy Pattern Pricing Engine
        data = PricingEngine::Calculator.calculate_operation(
          assignee: operation_params[:assignee],
          payment_currency_code: operation_params[:payment_currency_code],
          receivables: (operation_params[:receivables] || []).map(&:to_h),
          base_rate: operation_params[:base_rate] || 0.0
        )

        # 2. Build the ActiveRecord objects
        @operation = Operation.new(
          assignee: data[:assignee],
          payment_currency_id: data[:payment_currency_id],
          total_face_value: data[:total_face_value],
          total_net_value: data[:total_net_value]
        )

        data[:receivables_attributes].each do |rec_attr|
          @operation.receivables.build(rec_attr.except(:net_value_original))
        end

        # 3. Save inside a database transaction to ensure ACID atomic property
        ActiveRecord::Base.transaction do
          @operation.save!
        end

        render json: @operation.as_json(
          include: {
            payment_currency: { only: [:code, :symbol] },
            receivables: {
              include: {
                currency: { only: [:code, :symbol] },
                receivable_type: { only: [:code, :name] }
              }
            }
          }
        ), status: :created
      end

      private

      def operation_params
        # Strong parameters mapping for operations and nested receivables
        params.require(:operation).permit(
          :assignee,
          :payment_currency_code,
          :base_rate,
          receivables: [:identifier, :face_value, :due_date, :receivable_type_code, :currency_code]
        )
      end
    end
  end
end
