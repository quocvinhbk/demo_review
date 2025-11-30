#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'

require 'dotenv/load'
require 'net/http'
require 'json'

require_relative 'application_environment'

class SlackNotify
  attr_reader :webhook_url, :channel, :message

  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
    @webhook_url ||= ENV.fetch('SLACK_WEBHOOK_URL')
    @channel ||= ENV.fetch('SLACK_CHANNEL')
  end

  def call
    return if webhook_url.nil? || channel.nil?
    if ApplicationEnvironment.development?
      puts "🔔 Slack notification: #{message}"
      return
    end

    uri = URI(webhook_url)
    payload = {
      text: message,
      channel: channel,
    }.to_json

    Net::HTTP.post(uri, payload, 'Content-Type' => 'application/json')
  end
end
