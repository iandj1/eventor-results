class EventXmlOxDoc < ::Ox::Sax

  def start_element(name)
    if name == :ResultList
      # start of file
      @xpath = []
      @event_h = {}
      @race_lookup = {}
    end

    @xpath << name

    case @xpath
    when [:ResultList, :Event, :Race]
      @race_h = {}
    when [:ResultList, :ClassResult]
      @course_h = {}
      @results = []
    when [:ResultList, :ClassResult, :PersonResult]
      @result_h = {}
      @organisation_h = nil
    when [:ResultList, :ClassResult, :PersonResult, :Organisation]
      @organisation_h = {}
    when [:ResultList, :ClassResult, :PersonResult, :Result]
      @splits = []
    when [:ResultList, :ClassResult, :PersonResult, :Result, :SplitTime]
      @split = {}
    end
  end

  def attr(name, value)
    case @xpath
    when [:ResultList, :ClassResult, :PersonResult, :Person]
      @result_h[:gender] = value if name == :sex
    when [:ResultList, :ClassResult, :PersonResult, :Result]
      @result_race_no = value if name == :raceNumber
    when [:ResultList, :ClassResult, :PersonResult, :Result, :SplitTime]
      @split[:status] = value if name == :status
    end
  end

  def text(string)
    case @xpath
    when [:ResultList, :Event, :Id]
      @event_h[:eventor_id] = string
    when [:ResultList, :Event, :Name]
      @event_h[:name] = string
    when [:ResultList, :Event, :StartTime, :Date]
      @event_h[:date] = string

    when [:ResultList, :Event, :Race, :RaceNumber]
      @race_h[:number] = string
    when [:ResultList, :Event, :Race, :Name]
      @race_h[:name] = string

    when [:ResultList, :ClassResult, :Class, :Name]
      @course_h[:name] = string&.split(":")&.first
    when [:ResultList, :ClassResult, :Course, :Length]
      @course_h[:distance] = string

    when [:ResultList, :ClassResult, :PersonResult, :Person, :Id]
      @result_h[:eventor_id] = string
    when [:ResultList, :ClassResult, :PersonResult, :Person, :Name, :Family]
      @result_h[:family_name] = string
    when [:ResultList, :ClassResult, :PersonResult, :Person, :Name, :Given]
      @result_h[:given_name] = string
    when [:ResultList, :ClassResult, :PersonResult, :Person, :BirthDate]
      @result_h[:birth_date] = string
    when [:ResultList, :ClassResult, :PersonResult, :Organisation, :Id]
      @organisation_h["Id"] = string
    when [:ResultList, :ClassResult, :PersonResult, :Organisation, :Name]
      @organisation_h["Name"] = string
    when [:ResultList, :ClassResult, :PersonResult, :Organisation, :ShortName]
      @organisation_h["ShortName"] = string
    when [:ResultList, :ClassResult, :PersonResult, :Result, :Time]
      @result_h[:time] = string
    when [:ResultList, :ClassResult, :PersonResult, :Result, :Status]
      @result_h[:status] = string
    when [:ResultList, :ClassResult, :PersonResult, :Result, :StartTime]
      @result_h[:start_time] = string
    when [:ResultList, :ClassResult, :PersonResult, :Result, :SplitTime, :ControlCode]
      @split[:control_code] = string
    when [:ResultList, :ClassResult, :PersonResult, :Result, :SplitTime, :Time]
      @split[:time] = string
    end
  end

  def end_element(name)
    case @xpath
    when [:ResultList, :Event]
      @event = Event.create(@event_h)
      @race_lookup.values.map{|race| race.update!(event: @event)}
    when [:ResultList, :Event, :Race]
      @race_h[:event] = @event
      @race_h[:name]&.strip!
      @race_lookup[@race_h[:number]] = Race.new(@race_h)
    when [:ResultList, :ClassResult]
      @course_h[:event] = @event
      @course = Course.find_or_create_by(@course_h)
      @results.each do |result_h|
        r = Result.new(course: @course)
        r.update!(result_h)
      end
    when [:ResultList, :ClassResult, :PersonResult]
      @result_h[:race] = @race_lookup[@result_race_no]
      @results << @result_h
    when [:ResultList, :ClassResult, :PersonResult, :Organisation]
      @result_h[:organisation] = @organisation_h
    when [:ResultList, :ClassResult, :PersonResult, :Result, :SplitTime]
      @splits << @split
    when [:ResultList, :ClassResult, :PersonResult, :Result]
      @result_h[:xml_splits] = @splits
    end
    @xpath.pop
  end
end
