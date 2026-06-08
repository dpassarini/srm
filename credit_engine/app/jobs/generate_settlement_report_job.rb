require "csv"

class GenerateSettlementReportJob < ApplicationJob
  queue_as :default

  def perform(report_id)
    report = SettlementReport.find(report_id)
    report.update_column(:status, "processing")

    begin
      filters = {
        start_date: report.start_date_filter,
        end_date: report.end_date_filter,
        assignee: report.assignee_filter,
        payment_currency_code: report.payment_currency_code_filter
      }

      results = Reports::SettlementReportQuery.new(filters).execute

      csv_data = CSV.generate(headers: true, col_sep: ";") do |csv|
        csv << [
          "ID Operacao",
          "Cedente",
          "Data Operacao",
          "Identificador Titulo",
          "Tipo Recebivel",
          "Moeda Original",
          "Valor de Face",
          "Prazo (Dias)",
          "Taxa Base (% a.m.)",
          "Spread (% a.m.)",
          "Valor Liquido",
          "Moeda de Pagamento",
          "Taxa de Cambio"
        ]

        results.each do |row|
          csv << [
            row["operation_id"],
            row["assignee"],
            row["operation_date"],
            row["receivable_identifier"],
            row["receivable_type"],
            row["original_currency"],
            row["face_value"],
            row["days_to_maturity"],
            (row["base_rate_applied"].to_f * 100).round(4),
            (row["spread_applied"].to_f * 100).round(4),
            row["net_value"],
            row["payment_currency"],
            row["exchange_rate_applied"] || "1.0"
          ]
        end
      end

      report.update_columns(
        csv_content: csv_data,
        status: "completed"
      )
    rescue => e
      Rails.logger.error "Failed to generate settlement report #{report_id}: #{e.message}"
      report.update_column(:status, "failed")
      raise e
    end
  end
end
