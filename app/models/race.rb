class Race < ApplicationRecord
  belongs_to :event
  has_many :results

  def self.create_from_hash(event, race_hash)
    @race = Race.create(
      event: event,
      number: race_hash.dig("RaceNumber"),
      name: race_hash.dig("Name")&.strip
    )
  end
end
