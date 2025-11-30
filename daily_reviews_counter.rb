#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'

require 'csv'
require 'json'
require 'dotenv/load'
require 'fileutils'

require_relative 'app_logger'
require_relative 'constant'
require_relative 'slack_notify'

class DailyReviewsCounter
  def self.call
    new.call
  end

  attr_reader :output_files

  def initialize
    @output_files = load_output_files
  end

  def call
    location_reviews_count = 0
    competitor_reviews_count = 0

    output_files.each do |file|
      file_name = File.basename(file, '.json')
      parts = file_name.split('_')

      if parts[0] == 'location'
        location_reviews_count += parts[2].to_i
      elsif parts[0] == 'competitor'
        competitor_reviews_count += parts[2].to_i
      end
    end

    message = "Total reviews daily for locations: #{location_reviews_count}"
    AppLogger.call("@@@@@ #{message}")
    SlackNotify.call(":abacus: #{message}")

    message = "Total reviews daily for competitors: #{competitor_reviews_count}"
    AppLogger.call("@@@@@ #{message}")
    SlackNotify.call(":abacus: #{message}")
  end

  private

  def load_output_files
    Dir.glob(File.join(OUTPUT_PATH, '*.json')).select { |path| File.file?(path) }
  end
end
