class Event < ApplicationRecord
    has_many :courses, dependent: :destroy
    has_many :results, through: :courses
    has_many :races, dependent: :destroy

    def self.create_from_xml(xml)
        event_hash = Hash.from_xml(xml)
        @event = Event.create(
            eventor_id: event_hash.dig("ResultList", "Event", "Id"),
            name: event_hash.dig("ResultList", "Event", "Name"),
            date: event_hash.dig("ResultList", "Event", "StartTime", "Date")
        )
        races = event_hash.dig("ResultList", "Event", "Race")
        # in case no races in file
        races = [{"RaceNumber": "1", "Name": "Race 1"}] if races.nil?
        races = [races] if races.is_a? Hash
        races.each do |race|
            Race.create_from_hash(@event, race)
        end
        race_lookup = @event.races.group_by(&:number)
        courses = event_hash.dig("ResultList", "ClassResult")
        courses = [courses] if courses.is_a? Hash
        courses.each do |course|
            Course.create_from_hash(@event, course, race_lookup)
        end
        @event
    end

    def self.load_from_eventor(eventor_id)
        url = "#{EVENTOR_URL}/api/results/event/iofxml?includeSplitTimes=true&eventId=#{eventor_id}"
        xml = URI.open(url, "accept" => "application/xml", "ApiKey" => ENV['EVENTOR_API_KEY']).read
        create_from_xml(xml)
    end
end