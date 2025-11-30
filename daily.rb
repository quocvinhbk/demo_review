#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'

require 'csv'
require 'dotenv/load'
require 'fileutils'
require 'concurrent'

require_relative 'app_logger'
require_relative 'review_daily_scraper'
require_relative 'review_formatter'
require_relative 'constant'
require_relative 'slack_notify'
require_relative 'daily_reviews_counter'

class Daily
  def self.call(latest_retrieval_from_date, latest_retrieval_to_date)
    AppLogger.call("@@@@@ Latest retrieval from date: #{latest_retrieval_from_date}")
    AppLogger.call("@@@@@ Latest retrieval to date: #{latest_retrieval_to_date}")
    # new(latest_retrieval_from_date, latest_retrieval_to_date).call
  end

  attr_reader :location_details_path, :location_details, :max_retries, :latest_retrieval_from_date, :latest_retrieval_to_date, :max_threads

  def initialize(latest_retrieval_from_date, latest_retrieval_to_date)
    @location_details_path = load_location_details_file
    @latest_retrieval_from_date = latest_retrieval_from_date
    @latest_retrieval_to_date = latest_retrieval_to_date
    @max_retries ||= ENV.fetch('REVIEW_SCRAPER_MAX_RETRIES', 5).to_i
    @max_threads ||= ENV.fetch('REVIEW_SCRAPER_MAX_CRAWL_THREADS', 2).to_i
  end

  def call
    raw_location_details = JSON.parse(File.read(location_details_path))
    competior_location_data = build_competior_location_data(raw_location_details)
    duplicate_competitors = build_duplicate_competitors(raw_location_details)
    location_details = build_location_details(raw_location_details, duplicate_competitors)

    crawl_location(location_details)
    copy_duplicate_competitor_files(duplicate_competitors, competior_location_data)
  end

  def crawl_location(location_details)
    pool = Concurrent::FixedThreadPool.new(max_threads)

    location_details.each do |location|
      pool.post do
        begin
          crawl_single_location_group(location)
        rescue => e
          AppLogger.call("Error when crawling location group: #{e.message}")
        end
      end
    end

    pool.shutdown
    pool.wait_for_termination

    AppLogger.call("@@@@@ All location groups finished crawling.")
  end

  def crawl_single_location_group(location)
    location_retries = 0

    begin
      location_id = location['id']
      location_url = location['url']
      output_dir = File.join('input', location_id.to_s)

      FileUtils.rm_rf(output_dir) if File.directory?(output_dir)
      FileUtils.mkdir_p(output_dir)

      # Scrape reviews for the location
      options = {
        latest_retrieval_from_date: latest_retrieval_from_date,
        latest_retrieval_to_date: latest_retrieval_to_date,
        output_dir: output_dir
      }
      ReviewDailyScraper.new(location_id, location_url, options).call()
    rescue => e
      AppLogger.call("@@@@@ Location Errors: #{e.message}")
      location_retries += 1
      if location_retries < max_retries
        AppLogger.call("@@@@@ Retrying location (#{location_retries}/#{max_retries})...")
        sleep_long_time
        retry
      else
        AppLogger.call("Max retries reached (#{location_retries}/#{max_retries}). Giving up.")
        AppLogger.call("@@@@@ Abort location_url: #{location_url}.", { empty_line: true })
        SlackNotify.call("❌: Abort id: #{location_id}: #{location_url}.")
      end
    end

    # Process competitors
    crawl_competitors(location)
  end

  def crawl_competitors(location)
    if location['competitors']
      location['competitors'].each do |competitor|
        competitor_retries = 0
        competitor_url = competitor['url']
        competitor_id = competitor['id']
        location_id = location['id']

        begin
          options = {
            latest_retrieval_from_date: latest_retrieval_from_date,
            latest_retrieval_to_date: latest_retrieval_to_date,
            output_dir: File.join('input', location_id.to_s),
            review_type: 'competitor',
          }
          review_daily_scraper = ReviewDailyScraper.new(competitor_id, competitor_url, options)
          review_daily_scraper.call
        rescue => e
          AppLogger.call("@@@@@ Competitor Errors: #{e.message}")
          competitor_retries += 1
          if competitor_retries < max_retries
            AppLogger.call("@@@@@ Retrying competitor (#{competitor_retries}/#{max_retries})...")
            sleep_long_time
            retry
          else
            AppLogger.call("Max retries reached (#{competitor_retries}/#{max_retries}). Giving up.")
            AppLogger.call("@@@@@ Abort competitor_url: #{competitor_url}.", { empty_line: true })
            SlackNotify.call("❌: Abort id: #{competitor_id}: #{competitor_url}.")
          end
        end
      end
    end
  end

  def load_location_details_file
    Dir.glob(File.join(INPUT_PATH, '*.json')).find do |path|
      File.file?(path) && File.basename(path).start_with?('locations')
    end
  end

  # EXAMPLE RETURN {1004=>[5004], 3004=>[5003, 8003, 9002]}
  def build_duplicate_competitors(location_details)
    duplicate_competitors = location_details.each_with_object({}) do |location, details|
      location['competitors']&.each do |competitor|
        address = competitor['address']
        details[address] ||= []
        details[address] << competitor['id']
      end
    end

    duplicate_competitors.each_value.each_with_object({}) do |id_array, result_hash|
      next if id_array.length == 1

      result_hash[id_array[0]] = id_array[1..-1]
    end
  end

  def build_location_details(raw_location_details, duplicate_competitors)
    ids_to_reject = duplicate_competitors.values.flatten
    raw_location_details.each do |location|
      location['competitors'].reject! do |competitor|
        ids_to_reject.include?(competitor['id'])
      end
    end
  end

  # EXAMPLE RETURN {24001=>24, 28001=>28}
  def build_competior_location_data(raw_location_details)
    competior_location_data = {}
    raw_location_details.each do |location|
      location['competitors'].each do |competitor|
        competior_location_data[competitor['id']] = location['id']
      end
    end

    competior_location_data
  end

  def copy_duplicate_competitor_files(duplicate_competitors, competior_location_data)
    master_file_map = {}
    Dir.glob(File.join(INPUT_PATH, '*', 'competitor_*.json')).each do |file_path|
      filename = File.basename(file_path)
      match = filename.match(/competitor_(\d+)_/)
      master_file_map[match[1].to_i] = file_path if filename.match(/competitor_(\d+)_/)
    end

    duplicate_competitors.each do |source_id, duplicate_ids|
      source_file_path = master_file_map[source_id]
      if source_file_path.nil?
        puts "⚠️ WARNING: Source file for Master ID #{source_id} not found in input directory. Skipping."
        next
      end

      duplicate_ids.each do |duplicate_id|
        location_id = competior_location_data[duplicate_id]
        new_filename = source_file_path.split('/')[-1].sub(source_id.to_s, duplicate_id.to_s)
        destination_path = File.join(INPUT_PATH, location_id.to_s, new_filename)

        FileUtils.mkdir_p(File.dirname(destination_path))
        FileUtils.cp(source_file_path, destination_path)

        puts "   ✅ Successfully copied #{source_id} to #{duplicate_id}"
      end
    end
  end

  def sleep_long_time
    sleep(rand(55..75))
  end
end

class DailyMain
  def self.call
    new.call
  end

  attr_reader :latest_retrieval_from_date, :latest_retrieval_to_date

  def initialize
    @latest_retrieval_from_date ||= ENV.fetch('LATEST_RETRIEVAL_FROM_DATE', (Date.today - 1).strftime('%Y-%m-%d'))
    @latest_retrieval_to_date ||= ENV.fetch('LATEST_RETRIEVAL_TO_DATE', (Date.today - 1).strftime('%Y-%m-%d'))
  end

  def call
    start_time_total = Time.now

    log_and_notify('Starting reviews daily scraper')
    Daily.call(latest_retrieval_from_date, latest_retrieval_to_date)
    log_and_notify('Done reviews daily scraper')

    log_and_notify('Starting reviews formatter')
    ReviewFormatter.call
    log_and_notify('Done reviews formatter')

    DailyReviewsCounter.call

    message = "Total duration: #{format_duration(Time.now - start_time_total)}"
    log_and_notify(message)
  end

  def log_and_notify(message)
    AppLogger.call("@@@@@ #{message}", empty_line: true)
    SlackNotify.call("🔄: #{message}")
  end

  def format_duration(duration_seconds)
    total_seconds = duration_seconds.to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end

DailyMain.call
