class Event < ApplicationRecord
  has_many :courses, dependent: :destroy
  has_many :results, through: :courses
  has_many :races, dependent: :destroy

  def self.load_from_eventor(eventor_id)
    url = "#{EVENTOR_URL}/api/results/event/iofxml?includeSplitTimes=true&eventId=#{eventor_id}"
    request = URI.open(url, "accept" => "application/xml", "ApiKey" => ENV['EVENTOR_API_KEY'])
    xml_parser = Nokogiri::XML::SAX::Parser.new(EventXmlDoc.new)
    xml_parser.parse(request)
    self.find_by(eventor_id: eventor_id)
  end
end