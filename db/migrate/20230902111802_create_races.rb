class CreateRaces < ActiveRecord::Migration[7.0]
  def change
    create_table :races do |t|
      t.integer :number
      t.string :name
      t.belongs_to :event, foreign_key: true

      t.timestamps
    end

    change_table :results do |t|
      t.belongs_to :race, foreign_key: true
    end
  end
end
