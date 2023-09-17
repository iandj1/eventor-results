class ResultsController < ApplicationController
  before_action :find_or_load_event
  caches_action :show, :cache_path => Proc.new { |c| c.results_params }

  GENDER_MAP = {
    "F" => "Women",
    "M" => "Men"
  }

  JUNIOR_LEAGUE_SCORING = YAML::load(File.open('junior_league_scoring.yml'), aliases: true)

  def show
    courses = @event.courses
    @race = params[:race]&.to_i || 1
    @races = @event.races # need to show race days on results page
    @results_tables = {}
    @course_lengths = {}
    @control_sequences = {}
    @by_class = params[:by_class] == "true"
    @event_name = "#{@event.name}#{@races.count == 1 ? "": ": "+@races.find_by(number: @race).name}"
    control_sequence_hash = @event.courses.group_by{|course| course.control_sequence(@race)}
    @dup_courses = control_sequence_hash.any?{|key, value| key.present? && value.length > 1}
    @merge_courses = params[:merge_courses] == "true"
    if @by_class
      # results by class
      courses.each do |course|
        course.results.race_number(@race).distinct.pluck(:gender).each do |gender|
          course.results.race_number(@race).where(gender: gender).distinct.pluck(:age_range).each do |age_range|
            next if gender.nil? || age_range.nil?
            gender_name = GENDER_MAP[gender] || gender
            class_name = "#{course.name}: #{gender_name} #{age_range}"
            @results_tables[class_name] = course.results.race_number(@race).where(gender: gender, age_range: age_range).get_results_table
            @course_lengths[class_name] = course.distance if @race == 1 # eventor doesn't give us lengths for multiday events :(
            @control_sequences[class_name] = course.control_sequence(@race)
          end
        end
      end
    elsif @merge_courses
      control_sequence_hash.each do |sequence, courses|
        next if sequence == []
        course_name = courses.pluck(:name).join(', ')
        @results_tables[course_name] = @event.results.where(course: courses).race_number(@race).get_results_table
        @course_lengths[course_name] = courses.first.distance if @race == 1 # eventor doesn't give us lengths for multiday events :(
        @control_sequences[course_name] = sequence
      end
      control_sequence_hash[[]]&.each do |course|
        @results_tables[course.name] = course.results.race_number(@race).get_results_table
        @course_lengths[course.name] = course.distance if @race == 1 # eventor doesn't give us lengths for multiday events :(
        @control_sequences[course.name] = course.control_sequence(@race)
      end
    else
      # results by course
      courses.each do |course|
        @results_tables[course.name] = course.results.race_number(@race).get_results_table
        @course_lengths[course.name] = course.distance if @race == 1 # eventor doesn't give us lengths for multiday events :(
        @control_sequences[course.name] = course.control_sequence(@race)
      end
    end
  end

  def handicap_index
  end

  def handicap_download
    race_no = 1 # since we don't get lengths for race 2 and beyond
    courses = @event.courses.find(params[:course].compact_blank)
    @results = Result.race_number(race_no).where(course: courses, status: "OK").where.not(time: nil).to_a.sort_by!{ |result| result.handicap_pace }

    # if params[:format] == "csv"
    respond_to do |format|
      format.csv do
        headers = ['name', 'handicap', 'time', 'pace', 'handicap pace']
        csv_data = CSV.generate(headers: true) do |csv|
          csv << headers
          @results.each do |result|
            csv << [result.name, result.handicap, result.time, result.pace, result.handicap_pace]
          end
        end
        send_data csv_data, filename: "#{@event.name} - Handicap.csv"
        return
      end

      format.xml do
        stream = render_to_string(:handicap)
        send_data(stream, :type=>"text/xml", filename: "#{@event.name} - Handicap.xml")
      end
    end
  end

  def junior_league
    csv_data = CSV.generate(col_sep: ";") do |csv|
      @event.courses.each do |course|
        GENDER_MAP.keys.each do |gender|
          course_name = course.name.downcase
          next if JUNIOR_LEAGUE_SCORING[course_name].nil? # this shouldn't be possible
          results = course.results.race_number(1).where(status: "OK", age_range: "Junior", gender: gender).order(:time)
          placing_map = results.placing_map
          results.each do |result|
            if result.age < 10
              age = 10
            else
              age = ((result.age + 1) / 2) * 2
            end
            age_class = GENDER_MAP[gender][0] + age.to_s
            placing = placing_map[result.time]
            score = JUNIOR_LEAGUE_SCORING[course_name][placing - 1] || 1 # all finishers get 1 point
            csv << [
              age_class,
              result.eventor_id,
              result.name,
              result.organisation&.dig("Id"),
              result.organisation&.dig("Name"),
              score
            ]
          end
        end
      end
    end
    send_data csv_data, filename: "#{@event.name} - Junior League Scores.csv"
  end

  private
  def find_or_load_event
    @eventor_id = params[:eventor_id]
    # reject non integer ids
    if @eventor_id.to_i.to_s != @eventor_id
      raise ActionController::RoutingError.new('Not Found')
    end
    @event = Event.find_by(eventor_id: params[:eventor_id])
    if @event && params[:resetcache] == "yes"
      @event.destroy
      Rails.cache.delete_matched("views*results/#{@eventor_id}*") # glob format is unique to redis. MemoryStore will need regex instead
      redirect_to results_params
      return
    end
    if params[:resetcache] == "all"
      Event.destroy_all
      Rails.cache.delete_matched("views*results/*")
      redirect_to results_params
      return
    end
    if not @event
      @event = Event.load_from_eventor(@eventor_id)
    end
  end

  protected
  def results_params
    params.permit(:eventor_id, :by_class, :race, :merge_courses)
  end
end
