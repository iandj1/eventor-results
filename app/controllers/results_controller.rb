class ResultsController < ApplicationController
  GENDER_MAP = {
    "F" => "Women",
    "M" => "Men"
  }

  def show
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
    if not @event
      @event = Event.load_from_eventor(@eventor_id)
    end
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
end
