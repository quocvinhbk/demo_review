#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'

require 'csv'
require 'json'
require 'dotenv/load'

require_relative 'app_logger'
require_relative 'constant'

class ReviewFormatter
  def self.call
    new.call
  end

  attr_reader :location_details_path, :location_details, :location_id, :input_path, :location_file,
              :competitor_id, :competitor_file, :location_detail, :competitor_detail, :data

  def initialize
    @location_details_path = load_location_details_file
    @location_detail = {}
    @competitor_detail = {}
    @data = []
  end

  def call
    @location_details = JSON.parse(File.read(location_details_path))
    location_ids = location_details.map { |location| location['id'] }
    location_ids.each do |location_id|
      @location_id = location_id
      load_input_files
      next if input_path.nil?

      process_file
    end
  end

  private

  def load_location_details_file
    Dir.glob(File.join(INPUT_PATH, '*.json')).find do |path|
      File.file?(path) && File.basename(path).start_with?('locations')
    end
  end

  def load_input_files
    @input_path = Dir.glob(File.join(INPUT_PATH, '*')).find { |path| location_directory?(path) }
    return if input_path.nil?

    @location_file = Dir.glob(File.join(input_path, '*.json')).find { |path| location_file?(path) }

    detail = location_details.find { |location| location['id'] == location_id }
    detail = detail['competitors']&.first
    if detail.nil?
      @competitor_id = nil
      @competitor_file = nil
    else
      @competitor_id = detail['id']
      @competitor_file = Dir.glob(File.join(input_path, '*.json')).find { |path| competitor_file?(path) }
    end
  end

  def location_directory?(path)
    File.directory?(path) && File.basename(path).eql?(location_id.to_s)
  end

  def location_file?(path)
    File.file?(path) && File.basename(path).start_with?("location_#{location_id}_")
  end

  def competitor_file?(path)
    File.file?(path) && File.basename(path).start_with?("competitor_#{competitor_id}_")
  end

  def process_file
    AppLogger.call("@@@@@ Start >>>>> location_id: #{location_id}")
    location_detail_fetcher
    competitor_detail_fetcher
    output_dir = create_output_dir
    location_formatter(output_dir)
    competitor_formatter(output_dir) if competitor_detail.any?
    AppLogger.call("@@@@@ Done >>>>> location_id: #{location_id}", empty_line: true)
  end

  def location_detail_fetcher
    detail = location_details.find { |location| location['id'] == location_id }
    @location_detail = {
      'location_id' => detail['id'],
      'location_name' => detail['name'],
      'location_address' => detail['address'],
      'location_type' => detail['type'],
      'location_brand_name' => detail['brand_name'],
      'location_url' => detail['url'],
    }
  end

  def competitor_detail_fetcher
    detail = location_details.find { |location| location['id'] == location_id }
    detail = detail['competitors']&.first
    @competitor_detail = if detail.nil?
                           {}
                         else
                           {
                             'competitor_id' => detail['id'],
                             'competitor_name' => detail['name'],
                             'competitor_address' => detail['address'],
                             'competitor_url' => detail['url'],
                           }.merge(location_detail)
                         end
  end

  def location_formatter(output_path)
    return if location_file.nil?

    json_data = JSON.parse(File.read(location_file))
    @data = json_data.map { |location| location.merge(location_detail) }

    base_name = File.basename(location_file, '.json')
    file_name = generate_file_name(base_name)

    write_to_json(output_path, file_name)
  end

  def competitor_formatter(output_path)
    return if competitor_file.nil?

    json_data = JSON.parse(File.read(competitor_file))
    @data = json_data.map { |competitor| competitor.merge(competitor_detail) }

    base_name = File.basename(competitor_file, '.json')
    file_name = generate_file_name(base_name)

    write_to_json(output_path, file_name)
  end

  def create_output_dir
    output_dir = File.join(OUTPUT_PATH)
    FileUtils.mkdir_p(output_dir)
    output_dir
  end

  def write_to_json(output_path, file_name)
    json_path = File.join(output_path, "#{file_name}.json")
    File.open(json_path, 'w') do |file|
      file.puts(JSON.pretty_generate(data))
    end
    AppLogger.call("@@@@@ Done >>>>> write json: #{json_path}")
  end

  def write_to_csv(output_path, file_name)
    csv_path = File.join(output_path, "#{file_name}.csv")
    expanded_data = data.map { |hash| flatten_hash(hash) }
    headers = expanded_data.flat_map(&:keys).uniq

    CSV.open(csv_path, 'w', write_headers: true, headers: headers) do |csv|
      expanded_data.each do |row|
        csv << headers.map { |header| row[header] || '' }
      end
    end
    AppLogger.call("@@@@@ Done >>>>> write csv: #{csv_path}")
  end

  def flatten_hash(hash, parent_key = nil, result = {})
    hash.each do |key, value|
      new_key = [parent_key, key].compact.join('_')
      case value
      when Hash
        flatten_hash(value, new_key, result)
      when Array
        value.each_with_index { |v, i| flatten_hash(v, "#{new_key}_#{i}", result) } unless value.empty?
      else
        result[new_key] = value
      end
    end
    result
  end

  def generate_file_name(base_name)
    timestamp = (Date.today - 1).strftime('%Y%m%d')
    "#{base_name}_#{timestamp}"
  end
end
