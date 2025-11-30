# frozen_string_literal: true

require 'time'
require 'active_support/all'

# Time parsing patterns for Google review timestamps
module TimePatterns
  # Numeric patterns with optional prefix (e.g., "2 years ago", "Edited 2 years ago")
  NUMERIC_PATTERNS = {
    seconds: /^(?:[a-zA-Z]+\s+)*(\d+)\s+seconds?\s+ago$/,
    minutes: /^(?:[a-zA-Z]+\s+)*(\d+)\s+minutes?\s+ago$/,
    hours: /^(?:[a-zA-Z]+\s+)*(\d+)\s+hours?\s+ago$/,
    days: /^(?:[a-zA-Z]+\s+)*(\d+)\s+days?\s+ago$/,
    weeks: /^(?:[a-zA-Z]+\s+)*(\d+)\s+weeks?\s+ago$/,
    months: /^(?:[a-zA-Z]+\s+)*(\d+)\s+months?\s+ago$/,
    years: /^(?:[a-zA-Z]+\s+)*(\d+)\s+years?\s+ago$/,
  }.freeze

  # "a/an [time] ago" patterns with optional prefix
  SINGULAR_PATTERNS = {
    second: /^(?:[a-zA-Z]+\s+)*a\s+second\s+ago$/,
    minute: /^(?:[a-zA-Z]+\s+)*a\s+minute\s+ago$/,
    hour: /^(?:[a-zA-Z]+\s+)*an?\s+hour\s+ago$/,
    day: /^(?:[a-zA-Z]+\s+)*a\s+day\s+ago$/,
    week: /^(?:[a-zA-Z]+\s+)*a\s+week\s+ago$/,
    month: /^(?:[a-zA-Z]+\s+)*a\s+month\s+ago$/,
    year: /^(?:[a-zA-Z]+\s+)*a\s+year\s+ago$/,
  }.freeze

  # Legacy patterns without prefix for backward compatibility
  LEGACY_NUMERIC_PATTERNS = {
    seconds: /^(\d+)\s+seconds?\s+ago$/,
    minutes: /^(\d+)\s+minutes?\s+ago$/,
    hours: /^(\d+)\s+hours?\s+ago$/,
    days: /^(\d+)\s+days?\s+ago$/,
    weeks: /^(\d+)\s+weeks?\s+ago$/,
    months: /^(\d+)\s+months?\s+ago$/,
    years: /^(\d+)\s+years?\s+ago$/,
  }.freeze

  # Legacy "a/an [time] ago" patterns without prefix
  LEGACY_SINGULAR_PATTERNS = {
    'just now' => 0,
    'a second ago' => 1,
    'a minute ago' => 1,
    'an hour ago' => 1,
    'a day ago' => 1,
    'a week ago' => 1,
    'a month ago' => 1,
    'a year ago' => 1,
  }.freeze
end

# Converts Google review time strings to actual Time objects
class ReviewTimeParser
  include TimePatterns

  def self.parse(review_time)
    new.parse(review_time)
  end

  def parse(review_time)
    if review_time.nil? || review_time.strip.empty?
      raise ArgumentError, "Unsupported review time format: #{review_time.inspect}"
    end

    normalized_time = review_time.downcase.strip
    now = Time.current

    # Try numeric patterns with prefix first
    result = parse_numeric_with_prefix(normalized_time, now)
    return result if result

    # Try singular patterns with prefix
    result = parse_singular_with_prefix(normalized_time, now)
    return result if result

    # Try legacy numeric patterns
    result = parse_legacy_numeric(normalized_time, now)
    return result if result

    # Try legacy singular patterns
    result = parse_legacy_singular(normalized_time, now)
    return result if result

    # If nothing matches, raise error
    raise ArgumentError, "Unsupported review time format: #{review_time}"
  end

  private

  def parse_numeric_with_prefix(time_str, now)
    NUMERIC_PATTERNS.each do |unit, pattern|
      if time_str.match?(pattern)
        value = time_str.match(pattern)[1].to_i
        return now - value.send(unit)
      end
    end
    nil
  end

  def parse_singular_with_prefix(time_str, now)
    SINGULAR_PATTERNS.each do |unit, pattern|
      return now - 1.send(unit) if time_str.match?(pattern)
    end
    nil
  end

  def parse_legacy_numeric(time_str, now)
    LEGACY_NUMERIC_PATTERNS.each do |unit, pattern|
      if time_str.match?(pattern)
        value = time_str.match(pattern)[1].to_i
        return now - value.send(unit)
      end
    end
    nil
  end

  def parse_legacy_singular(time_str, now)
    LEGACY_SINGULAR_PATTERNS.each do |pattern, multiplier|
      if time_str == pattern
        return multiplier.zero? ? now : now - multiplier.send(extract_unit_from_pattern(pattern))
      end
    end
    nil
  end

  def extract_unit_from_pattern(pattern)
    # Use a hash map to reduce cyclomatic complexity
    unit_map = {
      'second' => :second,
      'minute' => :minute,
      'hour' => :hour,
      'day' => :day,
      'week' => :week,
      'month' => :month,
      'year' => :year,
    }
    unit_map.each do |key, value|
      return value if pattern.include?(key)
    end
    :second # fallback
  end
end

# Backward compatibility function
def review_time_to_time(review_time)
  ReviewTimeParser.parse(review_time)
end
