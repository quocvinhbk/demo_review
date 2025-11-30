# frozen_string_literal: true

require 'spec_helper'
require_relative '../time'

RSpec.describe ReviewTimeParser do
  let(:parser) { described_class.new }
  let(:now) { Time.parse('2025-01-15 12:00:00 UTC') }

  before do
    allow(Time).to receive(:current).and_return(now)
  end

  describe '.parse' do
    it 'delegates to instance method' do
      expect_any_instance_of(described_class).to receive(:parse).with('test')
      described_class.parse('test')
    end
  end

  describe '#parse' do
    context 'with numeric patterns with prefix' do
      [
        'Edited 2 years ago',
        'Updated 3 months ago',
        'We edited 5 days ago',
        'Modified 1 hour ago',
        'Changed 30 minutes ago',
        'Revised 45 seconds ago',
        'Edited 2 weeks ago',
        'Some random text 10 years ago',
      ].each do |input|
        it "parses '#{input}' correctly" do
          expected = case input
                     when 'Edited 2 years ago' then now - 2.years
                     when 'Updated 3 months ago' then now - 3.months
                     when 'We edited 5 days ago' then now - 5.days
                     when 'Modified 1 hour ago' then now - 1.hour
                     when 'Changed 30 minutes ago' then now - 30.minutes
                     when 'Revised 45 seconds ago' then now - 45.seconds
                     when 'Edited 2 weeks ago' then now - 2.weeks
                     when 'Some random text 10 years ago' then now - 10.years
                     end
          expect(parser.parse(input)).to eq(expected)
        end
      end
    end

    context 'with singular patterns with prefix' do
      [
        'Edited a year ago',
        'Updated a month ago',
        'We edited a day ago',
        'Modified an hour ago',
        'Changed a minute ago',
        'Revised a second ago',
        'Edited a week ago',
        'Some random text a year ago',
      ].each do |input|
        it "parses '#{input}' correctly" do
          expected = case input
                     when 'Edited a year ago', 'Some random text a year ago' then now - 1.year
                     when 'Updated a month ago' then now - 1.month
                     when 'We edited a day ago' then now - 1.day
                     when 'Modified an hour ago' then now - 1.hour
                     when 'Changed a minute ago' then now - 1.minute
                     when 'Revised a second ago' then now - 1.second
                     when 'Edited a week ago' then now - 1.week
                     end
          expect(parser.parse(input)).to eq(expected)
        end
      end
    end

    context 'with legacy numeric patterns' do
      [
        '2 years ago',
        '3 months ago',
        '5 days ago',
        '1 hour ago',
        '30 minutes ago',
        '45 seconds ago',
        '2 weeks ago',
      ].each do |input|
        it "parses '#{input}' correctly" do
          expected = case input
                     when '2 years ago' then now - 2.years
                     when '3 months ago' then now - 3.months
                     when '5 days ago' then now - 5.days
                     when '1 hour ago' then now - 1.hour
                     when '30 minutes ago' then now - 30.minutes
                     when '45 seconds ago' then now - 45.seconds
                     when '2 weeks ago' then now - 2.weeks
                     end
          expect(parser.parse(input)).to eq(expected)
        end
      end
    end

    context 'with legacy singular patterns' do
      [
        'just now',
        'a second ago',
        'a minute ago',
        'an hour ago',
        'a day ago',
        'a week ago',
        'a month ago',
        'a year ago',
      ].each do |input|
        it "parses '#{input}' correctly" do
          expected = case input
                     when 'just now' then now
                     when 'a second ago' then now - 1.second
                     when 'a minute ago' then now - 1.minute
                     when 'an hour ago' then now - 1.hour
                     when 'a day ago' then now - 1.day
                     when 'a week ago' then now - 1.week
                     when 'a month ago' then now - 1.month
                     when 'a year ago' then now - 1.year
                     end
          expect(parser.parse(input)).to eq(expected)
        end
      end
    end

    context 'with case insensitive input' do
      it 'handles uppercase input' do
        expect(parser.parse('EDITED 2 YEARS AGO')).to eq(now - 2.years)
      end

      it 'handles mixed case input' do
        expect(parser.parse('EdItEd A yEaR aGo')).to eq(now - 1.year)
      end
    end

    context 'with whitespace variations' do
      it 'handles extra spaces' do
        expect(parser.parse('  Edited  2  years  ago  ')).to eq(now - 2.years)
      end

      it 'handles single spaces' do
        expect(parser.parse('Edited 2 years ago')).to eq(now - 2.years)
      end
    end

    context 'with invalid formats' do
      [
        'invalid format',
        '2 years',
        'ago 2 years',
        '2 years ago invalid',
        '2 years ago extra text',
        '',
        nil,
      ].each do |invalid_input|
        it "raises ArgumentError for '#{invalid_input}'" do
          expect { parser.parse(invalid_input) }.to raise_error(ArgumentError, /Unsupported review time format/)
        end
      end
    end

    context 'with edge cases' do
      it 'handles zero values' do
        expect(parser.parse('0 seconds ago')).to eq(now)
      end

      it 'handles large numbers' do
        expect(parser.parse('999 years ago')).to eq(now - 999.years)
      end

      it 'handles single digit numbers' do
        expect(parser.parse('1 year ago')).to eq(now - 1.year)
      end
    end
  end

  describe 'private methods' do
    describe '#parse_numeric_with_prefix' do
      it 'returns correct time for numeric patterns' do
        result = parser.send(:parse_numeric_with_prefix, 'Edited 5 years ago', now)
        expect(result).to eq(now - 5.years)
      end

      it 'returns nil for non-matching patterns' do
        result = parser.send(:parse_numeric_with_prefix, 'invalid', now)
        expect(result).to be_nil
      end
    end

    describe '#parse_singular_with_prefix' do
      it 'returns correct time for singular patterns' do
        result = parser.send(:parse_singular_with_prefix, 'Edited a year ago', now)
        expect(result).to eq(now - 1.year)
      end

      it 'returns nil for non-matching patterns' do
        result = parser.send(:parse_singular_with_prefix, 'invalid', now)
        expect(result).to be_nil
      end
    end

    describe '#extract_unit_from_pattern' do
      {
        'a second ago' => :second,
        'a minute ago' => :minute,
        'an hour ago' => :hour,
        'a day ago' => :day,
        'a week ago' => :week,
        'a month ago' => :month,
        'a year ago' => :year,
        'unknown' => :second,
      }.each do |pattern, expected_unit|
        it "extracts #{expected_unit} from '#{pattern}'" do
          expect(parser.send(:extract_unit_from_pattern, pattern)).to eq(expected_unit)
        end
      end
    end
  end
end

RSpec.describe '#review_time_to_time' do
  let(:now) { Time.parse('2025-01-15 12:00:00 UTC') }

  before do
    allow(Time).to receive(:current).and_return(now)
  end

  it 'delegates to ReviewTimeParser.parse' do
    expect(ReviewTimeParser).to receive(:parse).with('test input')
    review_time_to_time('test input')
  end

  it 'returns correct time for valid input' do
    expect(review_time_to_time('2 years ago')).to eq(now - 2.years)
  end

  it 'raises ArgumentError for invalid input' do
    expect { review_time_to_time('invalid') }.to raise_error(ArgumentError)
  end
end
