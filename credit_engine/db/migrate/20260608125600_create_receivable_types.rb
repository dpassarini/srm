class CreateReceivableTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :receivable_types do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.decimal :base_spread, precision: 6, scale: 4, null: false

      t.timestamps
    end
    add_index :receivable_types, :code, unique: true
  end
end
