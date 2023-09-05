class Result < ApplicationRecord
  belongs_to :course
  belongs_to :race
  before_save :set_age_class
  before_save :shorten_status

  scope :race_number, ->(number) { joins(:race).where(race: {number: number}) }

  STATUS_MAP = {
    "MissingPunch" => "MP",
    "Disqualified" => "DSQ",
    "DidNotFinish" => "DNF",
    "OverTime" => "OT",
    "DidNotStart" => "DNS"
  }

  handicaps = {}
  CSV.read("al_handicap_factors.csv", headers: true).each do |row|
    age = row["Age"].to_i
    handicaps[age] ||= {}
    handicaps[age]["M"]  = row["M"].to_f
    handicaps[age]["F"]  = row["F"].to_f
  end
  AL_HANDICAPS = handicaps

  # descriptions of statuses built from STATUS_MAP, with spaces added for readability
  STATUS_LOOKUP = STATUS_MAP.invert.transform_values{ |description| description.gsub(/([a-z])([A-Z])/, '\1 \2') }

  def self.get_results_table
    valid_results = []
    invalid_results = []

    splits = self.where(status: "OK").pluck(:splits)
    splits.map!{|spl| spl["splits"]}
    split_placings, cumulative_placings = get_split_placings(splits)

    finishers = self.where(status: "OK")
    placing_map = finishers.placing_map
    finishers.order(:time).each do |result|
      splits = [] # {control, cumulative_time: {time:, place}, interval: {time, place}}
      result.splits["splits"].each_with_index do |split, leg|
        splits << {
          control: split["control"],
          cumulative_time: {time: split["time"], place: cumulative_placings[leg][split["time"]]},
          interval: {time: split["interval"], place: split_placings[leg][split["interval"]]}
        }
      end
      valid_results << {
        place: placing_map[result.time],
        name: result.name,
        time: result.time,
        club: result.organisation&.dig("ShortName"),
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
        club: result.organisation&.dig("ShortName"),
        splits: splits,
        extras: result.splits["extras"],
        finish_time: result.time
      }
    end
    # sort by most controls visited, then time
    invalid_results.sort_by! do |result|
      [
        - result[:splits].count{|split| split[:interval].present?},
        result[:finish_time] || Float::INFINITY
      ]
    end

    return {valid: valid_results, invalid: invalid_results}
  end

  def pace
    distance = self.course.distance.to_f / 1000
    return (time.to_f / distance).round(6)
  end

  def handicap
    return AL_HANDICAPS.dig(age, gender) || 1
  end

  def handicap_pace
    return (self.pace * self.handicap).round(6)
  end

  def name
    return "#{given_name} #{family_name}"
  end

  def birth_date=(birth_date)
    event_date = self.course.event.date
    self.age = nil if birth_date.nil? || event_date.nil?
    event_year = event_date.year
    birth_year = birth_date.to_date.year
    self.age = event_year - birth_year
  end

  def xml_splits=(xml_splits)
    if xml_splits.empty?
      self.splits = {splits: [], extras: []}
      return
    end
    splits = []
    extras = []
    last_time = 0
    xml_splits.each do |xml_split|
      control = xml_split[:control_code]
      time = xml_split[:time]&.to_i
      split = {
        control: control,
        time: time
      }
      if xml_split[:status] == "Additional"
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
      time: self.time
    }
    finish_split[:interval] = self.time - last_time if self.time
    splits << finish_split
    self.splits = {splits: splits, extras: extras}
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
        split_placings[leg][time] ||= index + 1
      end
    end
    cumulative_timings.map!{|timings| timings.compact.sort}
    cumulative_placings = []
    cumulative_timings.each_with_index do |timings, leg|
      cumulative_placings[leg] = {}
      timings.each_with_index do |time, index|
        cumulative_placings[leg][time] ||= index + 1
      end
    end
    return split_placings, cumulative_placings
  end

  def self.placing_map
    times = self.pluck(:time).sort_by { |value| value || Float::INFINITY } # nil time gets placed last
    placing_map = {}
    times.each_with_index do |time, index|
      placing_map[time] ||= index + 1
    end
    placing_map
  end

  def set_age_class
    case age
    when nil
      self.age_range = nil
    when 0..20
      self.age_range = "Junior"
    when 21..34
      self.age_range = "Open"
    when 35..nil
      self.age_range = "Master"
    end
  end

  def shorten_status
    self.status = STATUS_MAP[status] || status
  end
end
