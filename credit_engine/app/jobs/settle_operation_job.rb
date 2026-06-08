class SettleOperationJob < ApplicationJob
  queue_as :default

  def perform(operation_id, base_rate, receivables_params)
    operation = Operation.find(operation_id)
    operation.update!(status: "processing")

    begin
      # 1. Run calculations through Strategy Pattern Pricing Engine
      data = PricingEngine::Calculator.calculate_operation(
        assignee: operation.assignee,
        payment_currency_code: operation.payment_currency.code,
        receivables: receivables_params,
        base_rate: base_rate.to_f
      )

      # 2. Save inside a database transaction to ensure ACID atomic property
      ActiveRecord::Base.transaction(requires_new: true) do
        data[:receivables_attributes].each do |rec_attr|
          operation.receivables.create!(rec_attr.except(:net_value_original))
        end

        operation.update!(
          total_face_value: data[:total_face_value],
          total_net_value: data[:total_net_value],
          status: "liquidated"
        )
      end
    rescue => e
      Rails.logger.error "Failed to settle operation #{operation_id}: #{e.message}"
      operation.update_column(:status, "failed")
      raise e # Let Sidekiq handle retry/failure tracking
    end
  end
end
