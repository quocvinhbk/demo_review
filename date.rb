# frozen_string_literal: true

require 'date'
require 'active_support/all'

def review_time_to_date(review_time)
  case review_time.downcase
  when /(\d+) weeks? ago/
    Date.today - Regexp.last_match(1).to_i.weeks
  when /(\d+) days? ago/
    Date.today - Regexp.last_match(1).to_i.days
  when /(\d+) months? ago/
    Date.today - Regexp.last_match(1).to_i.months
  when /(\d+) years? ago/
    Date.today - Regexp.last_match(1).to_i.years
  when 'a week ago'
    Date.today - 1.week
  when 'a day ago'
    Date.today - 1.day
  when 'a month ago'
    Date.today - 1.month
  when 'a year ago'
    Date.today - 1.year
  else
    raise ArgumentError, "Unsupported review time: #{review_time}"
  end
end
