#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'

require 'csv'
require 'dotenv/load'
require 'fileutils'

require_relative 'app_logger'
require_relative 'review_scraper'

class Main
  def self.call(latest_retrieval_from_date)
    puts "ok"
    # new(latest_retrieval_from_date).call
  end

  attr_reader :urls, :max_retries, :latest_retrieval_from_date

  def initialize(latest_retrieval_from_date)
    @latest_retrieval_from_date = latest_retrieval_from_date
    @urls = load_urls_from_csv('input.csv')
    @max_retries ||= ENV.fetch('REVIEW_SCRAPER_MAX_RETRIES', 5).to_i
  end

  def call
    urls.each_with_index do |url, index|
      retries = 0
      begin
        output_dir = File.join('output', "#{index + 1}_json")
        FileUtils.rm_rf(output_dir) if File.directory?(output_dir)
        FileUtils.mkdir_p(output_dir)
        if url == 'skip_this_one'
          AppLogger.call('@@@@@ Skip this one. Next.', { empty_line: true })
          next
        end
        ReviewScraper.new(latest_retrieval_from_date, output_dir, url).call
      rescue => e
        AppLogger.call("@@@@@ Errors: #{e.message}")
        retries += 1
        if retries < max_retries
          AppLogger.call("@@@@@ Retrying (#{retries}/#{max_retries})...")
          sleep(rand(55..75))
          retry
        else
          AppLogger.call("Max retries reached (#{retries}/#{max_retries}). Giving up.")
          AppLogger.call("@@@@@ Abort url: #{url}.", { empty_line: true })
        end
      end
      sleep(rand(3..5)) unless just_one?
    end
  end

  private

  def load_urls_from_csv(file_path)
    urls = []
    CSV.foreach(file_path, col_sep: ';', headers: true) do |row|
      next if row['url'].nil? || row['url'].empty?

      urls << row['url']
    end
    urls
  end

  def just_one?
    @just_one ||= urls.size
    @just_one == 1
  end
end

latest_retrieval_from_date = ENV.fetch('LATEST_RETRIEVAL_FROM_DATE', Date.today.strftime('%Y-%m-%d'))

Main.call(latest_retrieval_from_date)
