class ResultsController < ApplicationController
  before_action :find_or_load_event

  GENDER_MAP = {
    "F" => "Women",
    "M" => "Men"
  }

  JUNIOR_LEAGUE_SCORING = YAML::load(File.open('junior_league_scoring.yml'), aliases: true)

  def show
    courses = @event.courses
    @results_tables = {}
    @course_lengths = {}
    @control_sequences = {}
    @by_class = params[:by_class] == "true"
    if @by_class
      # results by class
      courses.each do |course|
        course.results.distinct.pluck(:gender).each do |gender|
          course.results.where(gender: gender).distinct.pluck(:age_range).each do |age_range|
            next if gender.nil? || age_range.nil?
            gender_name = GENDER_MAP[gender] || gender
            class_name = "#{course.name}: #{gender_name} #{age_range}"
            @results_tables[class_name] = course.results.where(gender: gender, age_range: age_range).get_results_table
            @course_lengths[class_name] = course.distance
            @control_sequences[class_name] = course.control_sequence
          end
        end
      end
    else
      # results by course
      courses.each do |course|
        @results_tables[course.name] = course.results.get_results_table
        @course_lengths[course.name] = course.distance
        @control_sequences[course.name] = course.control_sequence
      end
    end
  end

  def handicap_index
  end

  def handicap_download
    puts params
    courses = @event.courses.find(params[:course].compact_blank)
    # results = Result.where(course: courses).to_a.sort_by!{ |result| result.handicap_pace }
    @results = Result.where(course: courses, status: "OK").to_a.sort_by!{ |result| result.handicap_pace }

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
        # stream = render_to_string(:template=>"calculations/show" )
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
          results = course.results.where(status: "OK", age_range: "Junior", gender: gender).order(:time)
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
              result.id,
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
      redirect_to params.permit(:by_class)
      return
    end
    if params[:resetcache] == "all"
      Event.destroy_all
      redirect_to params.permit(:by_class)
      return
    end
    if not @event
      @event = Event.load_from_eventor(@eventor_id)
    end
  end
end
