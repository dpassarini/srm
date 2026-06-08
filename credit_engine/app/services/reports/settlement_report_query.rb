module Reports
  class SettlementReportQuery
    def initialize(filters = {})
      @start_date = filters[:start_date]
      @end_date = filters[:end_date]
      @assignee = filters[:assignee]
      @payment_currency_code = filters[:payment_currency_code]
    end

    def execute
      sql = <<~SQL
        SELECT 
          o.id AS operation_id,
          o.assignee AS assignee,
          o.created_at AS operation_date,
          r.identifier AS receivable_identifier,
          rt.name AS receivable_type,
          c_orig.code AS original_currency,
          r.face_value AS face_value,
          r.days_to_maturity AS days_to_maturity,
          r.base_rate_applied AS base_rate_applied,
          r.spread_applied AS spread_applied,
          r.net_value AS net_value,
          c_pay.code AS payment_currency,
          r.exchange_rate_applied AS exchange_rate_applied
        FROM operations o
        JOIN currencies c_pay ON c_pay.id = o.payment_currency_id
        JOIN receivables r ON r.operation_id = o.id
        JOIN currencies c_orig ON c_orig.id = r.currency_id
        JOIN receivable_types rt ON rt.id = r.receivable_type_id
        WHERE 1=1
      SQL

      params = []
      
      if @assignee.present?
        sql += " AND o.assignee ILIKE ?"
        params << "%#{@assignee}%"
      end

      if @payment_currency_code.present?
        sql += " AND c_pay.code = ?"
        params << @payment_currency_code
      end

      if @start_date.present?
        sql += " AND o.created_at >= ?"
        params << Time.zone.parse(@start_date).beginning_of_day
      end

      if @end_date.present?
        sql += " AND o.created_at <= ?"
        params << Time.zone.parse(@end_date).end_of_day
      end

      sql += " ORDER BY o.created_at DESC, r.identifier ASC"

      sanitized_sql = ActiveRecord::Base.sanitize_sql_array([sql, *params])
      ActiveRecord::Base.connection.select_all(sanitized_sql).to_a
    end
  end
end
