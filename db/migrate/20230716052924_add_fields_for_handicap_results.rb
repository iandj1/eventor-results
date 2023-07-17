class AddFieldsForHandicapResults < ActiveRecord::Migration[7.0]
  def change
    add_column :results, :organisation, :json
    add_column :results, :age, :integer
    add_column :results, :eventor_id, :integer
    remove_column :results, :club, :string
    remove_column :results, :name, :string
    add_column :results, :given_name, :string
    add_column :results, :family_name, :string
  end
end
