class CreateInitialTables < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.integer :eventor_id, index: {unique: true}
      t.string :name
      t.date :date

      t.timestamps
    end
    create_table :courses do |t|
      t.belongs_to :event, foreign_key: true
      t.string :name
      t.integer :distance
      # t.integer :entries
      # t.integer :participants

      t.timestamps
    end
    create_table :results do |t|
      t.belongs_to :course, foreign_key: true
      t.string :name
      t.string :club
      t.integer :time
      t.string :status
      t.json :splits
      t.string :gender, index: true
      t.string :age_range, index: true
      t.datetime :start_time

      t.timestamps
    end
  end
end
