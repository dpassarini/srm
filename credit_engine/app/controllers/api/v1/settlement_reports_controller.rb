module Api
  module V1
    class SettlementReportsController < BaseController
      def index
        reports = SettlementReport.order(created_at: :desc).limit(20)
        render json: reports
      end

      def create
        report = SettlementReport.new(report_params)
        report.status = "pending"
        report.file_name = "extrato_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"

        if report.save
          GenerateSettlementReportJob.perform_later(report.id)
          render json: report, status: :created
        else
          render json: { error: report.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def download
        report = SettlementReport.find(params[:id])
        if report.status == "completed" && report.csv_content.present?
          send_data report.csv_content,
            filename: report.file_name,
            type: "text/csv; charset=utf-8",
            disposition: "attachment"
        else
          render json: { error: "Relatório não está pronto ou falhou" }, status: :bad_request
        end
      end

      private

      def report_params
        params.require(:settlement_report).permit(
          :assignee_filter,
          :payment_currency_code_filter,
          :start_date_filter,
          :end_date_filter
        )
      end
    end
  end
end
