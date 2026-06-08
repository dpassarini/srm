class CreateSettlementReports < ActiveRecord::Migration[8.1]
  def change
    create_table :settlement_reports do |t|
      t.string :assignee_filter
      t.string :payment_currency_code_filter
      t.string :start_date_filter
      t.string :end_date_filter
      t.string :status, default: "pending", null: false
      t.string :file_name
      t.text :csv_content

      t.timestamps
    end
  end
end
