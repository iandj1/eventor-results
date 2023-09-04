class EventXmlDoc < Nokogiri::XML::SAX::Document
  def start_document
    @xpath = []
    @status = nil
    @event_h = {}
    @race_lookup = {}
  end

  def start_element(name, attrs = [])
    @xpath << name
    attrs = attrs.to_h

    case @xpath
    when ["ResultList", "Event", "Race"]
      @race_h = {}
    when ["ResultList", "ClassResult"]
      @course_h = {}
      @results = []
    when ["ResultList", "ClassResult", "PersonResult"]
      @result_h = {}
      @organisation_h = nil
    when ["ResultList", "ClassResult", "PersonResult", "Person"]
      @result_h[:gender] = attrs["sex"]
    when ["ResultList", "ClassResult", "PersonResult", "Organisation"]
      @organisation_h = {}
    when ["ResultList", "ClassResult", "PersonResult", "Result"]
      @result_race_no = attrs["raceNumber"]
      @splits = []
    when ["ResultList", "ClassResult", "PersonResult", "Result", "SplitTime"]
      @split = {}
      @split["status"] = "Additional" if attrs["status"] == "Additional"
    end
  end

  def characters(string)
    case @xpath
    when ["ResultList", "Event", "Id"]
      @event_h[:eventor_id] = string
    when ["ResultList", "Event", "Name"]
      @event_h[:name] ||= '' # handle ampersands in names
      @event_h[:name] += string
    when ["ResultList", "Event", "StartTime", "Date"]
      @event_h[:date] = string

    when ["ResultList", "Event", "Race", "RaceNumber"]
      @race_h[:number] = string
    when ["ResultList", "Event", "Race", "Name"]
      @race_h[:name] ||= ''
      @race_h[:name] += string

    when ["ResultList", "ClassResult", "Class", "Name"]
      @course_h[:name] ||= ''
      @course_h[:name] += string
    when ["ResultList", "ClassResult", "Course", "Length"]
      @course_h[:distance] = string

    when ["ResultList", "ClassResult", "PersonResult", "Person", "Id"]
      @result_h[:eventor_id] = string
    when ["ResultList", "ClassResult", "PersonResult", "Person", "Name", "Family"]
      @result_h[:family_name] ||= '' # handle ampersands in names
      @result_h[:family_name] += string
    when ["ResultList", "ClassResult", "PersonResult", "Person", "Name", "Given"]
      @result_h[:given_name] ||= '' # handle ampersands in names
      @result_h[:given_name] += string
    when ["ResultList", "ClassResult", "PersonResult", "Person", "BirthDate"]
      @result_h[:birth_date] = string
    when ["ResultList", "ClassResult", "PersonResult", "Organisation", "Id"]
      @organisation_h["Id"] = string
    when ["ResultList", "ClassResult", "PersonResult", "Organisation", "Name"]
      @organisation_h["Name"] ||= '' # handle ampersands in names
      @organisation_h["Name"] += string
    when ["ResultList", "ClassResult", "PersonResult", "Organisation", "ShortName"]
      @organisation_h["ShortName"] ||= '' # handle ampersands in names
      @organisation_h["ShortName"] += string
    when ["ResultList", "ClassResult", "PersonResult", "Result", "Time"]
      @result_h[:time] = string
    when ["ResultList", "ClassResult", "PersonResult", "Result", "Status"]
      @result_h[:status] = string
    when ["ResultList", "ClassResult", "PersonResult", "Result", "StartTime"]
      @result_h[:start_time] = string
    when ["ResultList", "ClassResult", "PersonResult", "Result", "SplitTime", "ControlCode"]
      @split["ControlCode"] = string
    when ["ResultList", "ClassResult", "PersonResult", "Result", "SplitTime", "Time"]
      @split["Time"] = string
    end
  end

  def end_element(name)
    case @xpath
    when ["ResultList", "Event"]
      @event = Event.create(@event_h)
      @race_lookup.values.map{|race| race.update!(event: @event)}
    when ["ResultList", "Event", "Race"]
      @race_h[:event] = @event
      @race_h[:name]&.strip!
      @race_lookup[@race_h[:number]] = Race.new(@race_h)
    when ["ResultList", "ClassResult"]
      @course_h[:event] = @event
      @course_h[:name] = @course_h[:name]&.split(":")&.first
      @course = Course.create(@course_h)
      @results.each do |result_h|
        r = Result.new(course: @course)
        r.update!(result_h)
      end
    when ["ResultList", "ClassResult", "PersonResult"]
      @result_h[:race] = @race_lookup[@result_race_no]
      @results << @result_h
    when ["ResultList", "ClassResult", "PersonResult", "Organisation"]
      @result_h[:organisation] = @organisation_h
    when ["ResultList", "ClassResult", "PersonResult", "Result", "SplitTime"]
      @splits << @split
    when ["ResultList", "ClassResult", "PersonResult", "Result"]
      @result_h[:xml_splits] = @splits
    end
    @xpath.pop
  end
end
