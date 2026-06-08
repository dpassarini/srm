module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ArgumentError, with: :render_bad_request
      rescue_from RuntimeError, with: :render_bad_request

      private

      def render_not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def render_unprocessable_entity(exception)
        render json: {
          error: "Entidade Não Processável",
          details: exception.record.errors.full_messages
        }, status: :unprocessable_entity
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def render_internal_server_error(exception)
        Rails.logger.error "ERROR: #{exception.message}\n#{exception.backtrace.join("\n")}"
        render json: { error: "Ocorreu um erro interno no servidor" }, status: :internal_server_error
      end
    end
  end
end
