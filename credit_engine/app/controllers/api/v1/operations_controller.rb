module Api
  module V1
    class OperationsController < BaseController
      # GET /api/v1/operations (Analytical History with server-side pagination and filters)
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page

        scope = Operation.includes(:payment_currency, receivables: [ :currency, :receivable_type ])

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
              payment_currency: { only: [ :code, :symbol ] },
              receivables: {
                include: {
                  currency: { only: [ :code, :symbol ] },
                  receivable_type: { only: [ :code, :name ] }
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

      # POST /api/v1/operations (Asynchronous Liquidation)
      def create
        # 1. Resolve payment currency
        currency = Currency.find_by!(code: operation_params[:payment_currency_code])

        # 2. Build pending operation
        @operation = Operation.new(
          assignee: operation_params[:assignee],
          payment_currency: currency,
          total_face_value: 0.0,
          total_net_value: 0.0,
          status: "pending"
        )

        # 3. Save pending operation record
        ActiveRecord::Base.transaction do
          @operation.save!
        end

        # 4. Enqueue background settlement job
        SettleOperationJob.perform_later(
          @operation.id,
          operation_params[:base_rate] || 0.0,
          (operation_params[:receivables] || []).map(&:to_h)
        )

        render json: @operation.as_json(
          include: {
            payment_currency: { only: [ :code, :symbol ] },
            receivables: {
              include: {
                currency: { only: [ :code, :symbol ] },
                receivable_type: { only: [ :code, :name ] }
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
          receivables: [ :identifier, :face_value, :due_date, :receivable_type_code, :currency_code ]
        )
      end
    end
  end
end
