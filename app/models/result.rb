class Result < ApplicationRecord
  belongs_to :course

  STATUS_MAP = {
    "MissingPunch" => "MP",
    "Disqualified" => "DSQ",
    "DidNotFinish" => "DNF",
    "OverTime" => "OT",
    "DidNotStart" => "DNS"
  }

  # descriptions of statuses built from STATUS_MAP, with spaces added for readability
  STATUS_LOOKUP = STATUS_MAP.invert.transform_values{ |description| description.gsub(/([a-z])([A-Z])/, '\1 \2') }

  def self.create_from_hash(course, result_hash)
    name = result_hash.dig("Person", "Name", "Given").to_s + " " + result_hash.dig("Person", "Name", "Family").to_s
    birth_date = result_hash.dig("Person", "BirthDate")
    time = result_hash.dig("Result", "Time")&.to_i
    status = result_hash.dig("Result", "Status")
    @result = Result.create(
      course: course,
      name: name,
      club: result_hash.dig("Organisation", "ShortName"),
      time: time,
      status: STATUS_MAP[status] || status,
      splits: process_splits(result_hash.dig("Result", "SplitTime"), time),
      gender: result_hash.dig("Person", "sex"),
      age_range: birth_date && get_age_class(birth_date, course.event.date),
      start_time: result_hash.dig("Result", "StartTime")
    )
    @result
  end

  def self.get_results_table
    valid_results = []
    invalid_results = []

    splits = self.where(status: "OK").pluck(:splits)
    splits.map!{|spl| spl["splits"]}
    split_placings, cumulative_placings = get_split_placings(splits)

    self.where(status: "OK").order(:time).each do |result|
      splits = [] # {control, cumulative_time: {time:, place}, interval: {time, place}}
      result.splits["splits"].each_with_index do |split, leg|
        splits << {
          control: split["control"],
          cumulative_time: {time: split["time"], place: cumulative_placings[leg][split["time"]]},
          interval: {time: split["interval"], place: split_placings[leg][split["interval"]]}
        }
      end
      valid_results << {
        name: result.name,
        time: result.time,
        club: result.club,
        splits: splits,
        extras: result.splits["extras"]
      }
    end

    self.where.not(status: "OK").order(:time).each do |result|
      splits = [] # {control, cumulative_time: {time:, place}, interval: {time, place}}
      result.splits["splits"].each do |split|
        splits << {
          control: split["control"],
          cumulative_time: split["time"],
          interval: split["interval"]
        }
      end
      invalid_results << {
        name: result.name,
        status: result.status,
        club: result.club,
        splits: splits,
        extras: result.splits["extras"],
        finish_time: result.time
      }
    end
    # sort by most controls visited, then
    invalid_results.sort_by! do |result|
      [
        - result[:splits].count{|split| split[:interval].present?},
        result[:finish_time] || Float::INFINITY
      ]
    end

    return {valid: valid_results, invalid: invalid_results}
  end

  private

  def self.get_split_placings(splits)
    split_timings = []
    cumulative_timings = []
    splits.each do |competitor|
      competitor.each_with_index do |split, leg_no|
        split_timings[leg_no] ||= []
        split_timings[leg_no] << split["interval"]
        cumulative_timings[leg_no] ||= []
        cumulative_timings[leg_no] << split["time"]
      end
    end
    split_timings.map!{|timings| timings.compact.sort}
    split_placings = []
    split_timings.each_with_index do |timings, leg|
      split_placings[leg] = {}
      timings.each_with_index do |time, index|
        next if split_placings[leg][time]
        split_placings[leg][time] = index + 1
      end
    end
    cumulative_timings.map!{|timings| timings.compact.sort}
    cumulative_placings = []
    cumulative_timings.each_with_index do |timings, leg|
      cumulative_placings[leg] = {}
      timings.each_with_index do |time, index|
        next if cumulative_placings[leg][time]
        cumulative_placings[leg][time] = index + 1
      end
    end
    return split_placings, cumulative_placings
  end

  def self.get_age_class(birth_date, event_date)
    return nil if birth_date.nil?
    event_year = event_date.year
    birth_year = birth_date.to_date.year
    age = event_year - birth_year
    case age
    when 0..20
      then "Junior"
    when 21..34
      then "Open"
    when 35..
      then "Master"
    end
  end

  def self.process_splits(xml_splits, finish_time)
    return {splits: [], extras: []} if xml_splits.nil?
    splits = []
    extras = []
    last_time = 0
    xml_splits.each do |xml_split|
      control = xml_split["ControlCode"]
      time = xml_split["Time"]&.to_i
      split = {
        control: control,
        time: time
      }
      if xml_split["status"] == "Additional"
        extras << split
        next
      end
      if time
        interval = time - last_time
        last_time = time
        split[:interval] = interval
      end
      splits << split
    end
    finish_split = {
      control: "F",
      time: finish_time
    }
    finish_split[:interval] = finish_time - last_time if finish_time
    splits << finish_split
    return {splits: splits, extras: extras}
  end
end
