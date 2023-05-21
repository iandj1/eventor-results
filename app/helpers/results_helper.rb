module ResultsHelper
  def format_time(time)
    return '-' if time.nil?
    if negative = time < 0
      time = -time
    end
    mins = (time/60).to_s
    mins = "-#{mins}" if negative
    secs = time%60
    secs = '0' + secs.to_s if secs < 10
    return "#{mins}:#{secs}"
  end
end
