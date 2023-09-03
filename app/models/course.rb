class Course < ApplicationRecord
  belongs_to :event
  has_many :results, dependent: :destroy

  def self.create_from_hash(event, course_hash, race_lookup)
    @course = Course.find_or_create_by(
      event: event,
      name: course_hash.dig("Class", "Name")&.split(":")&.first,
      distance: course_hash.dig("Course", "Length")
    )
    results = course_hash["PersonResult"]
    results = [results] if results.is_a? Hash
    results.each do |result|
      Result.create_from_hash(@course, result, race_lookup)
    end
    @course
  end

  def control_sequence(race_no)
    results.race_number(race_no).each do |result|
      splits = result.splits["splits"]
      next if splits.empty?
      return splits.map{|split| split["control"]}
    end
    return []
  end
end
