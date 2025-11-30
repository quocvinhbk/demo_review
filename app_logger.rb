# frozen_string_literal: true

require 'pry-byebug'

class AppLogger
  def self.call(message, options = {})
    new(message, options).call
  end

  attr_reader :message, :file_path, :empty_line

  def initialize(message, options)
    raise ArgumentError, 'Invalid message' if message.empty?

    @message = message

    file_name = options[:file_name] || 'app.log'
    @file_path = File.join('log', file_name)

    @empty_line = options[:empty_line]
  end

  def call
    File.open(file_path, 'a') { |file| puts_and_write_to_log(file) }
  end

  private

  def puts_and_write_to_log(file)
    puts(message)
    file.puts(message)
    return unless empty_line

    puts
    file.puts
  end
end
