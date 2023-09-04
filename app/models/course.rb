class Course < ApplicationRecord
  belongs_to :event
  has_many :results, dependent: :destroy

  def control_sequence(race_no)
    results.race_number(race_no).each do |result|
      splits = result.splits["splits"]
      next if splits.empty?
      return splits.map{|split| split["control"]}
    end
    return []
  end
end
