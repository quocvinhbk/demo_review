# frozen_string_literal: true

require 'pry-byebug'

require 'json'
require 'dotenv/load'
require 'selenium-webdriver'

require_relative 'app_logger'
require_relative 'time'

class ReviewDailyScraper
  attr_reader :latest_retrieval_from_date, :latest_retrieval_to_date, :location_id, :output_dir, :review_type, :url, :output_dir,
              :category_names, :driver, :headless_mode, :read_timeout, :waiting_timeout,
              :total_reviews_xpath, :overview_tab_xpath, :reviews_tab_xpath,
              :sort_reviews_xpath, :newest_path, :refine_reviews_path, :category_span_path,
              :reviews_path, :more_button_path, :review_description_path, :review_date_path, :rating_path,
              :n_review_user_path, :url_user_path, :owner_reply_path, :owner_reply_date_path,
              :skip_review_size, :first_time_check, :reviews, :data

  def initialize(location_id, url, options = {})
    opts = {
      latest_retrieval_from_date: nil,
      latest_retrieval_to_date: nil,
      output_dir: nil,
      review_type: 'location',
    }.merge(options)

    raise ArgumentError, 'Invalid URL' if url.to_s.empty?

    AppLogger.call("@@@@@ output_dir: #{opts[:output_dir]}")

    @location_id = location_id
    @url = url
    @review_type = opts[:review_type]
    @latest_retrieval_from_date = opts[:latest_retrieval_from_date]
    @latest_retrieval_to_date = opts[:latest_retrieval_to_date]
    @output_dir = opts[:output_dir]

    @category_names = []
    @reviews = []
    @data = []
    initialize_env
    initialize_driver
  end

  def call
    AppLogger.call("@@@@@ Start >>>>> get url: #{url}")
    driver.get(url)
    sleep_short_time
    Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
      driver.execute_script('return document.readyState') == 'complete'
    end

    sleep_short_time
    unless valid_element_reviews?
      AppLogger.call("@@@@@ With review_id: #{location_id}. Not found Reviews tab. Exiting ReviewDailyScraper#call.", { empty_line: true })
      raise "Not found Reviews tab. Exiting ReviewDailyScraper#call. With review_id: #{location_id}."
    end

    if driver.find_elements(:xpath, total_reviews_xpath).any?
      total_reviews_element = driver.find_element(:xpath, total_reviews_xpath)
      total_reviews = total_reviews_element.attribute('aria-label')
    end

    reviews_tab_button = driver.find_element(:xpath, reviews_tab_xpath)
    reviews_tab_button.click
    sleep_short_time
    Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
      driver.execute_script('return document.readyState') == 'complete'
    end

    sort_reviews_button = driver.find_element(:xpath, sort_reviews_xpath)
    sort_reviews_button.click
    sleep 1
    newest_element = driver.find_element(:css, newest_path)
    newest_element.click
    sleep 5
    Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
      driver.execute_script('return document.readyState') == 'complete'
    end

    category_buttons = driver.find_elements(:css, refine_reviews_path)
    category_buttons.each do |category_button|
      Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
        driver.execute_script('return document.readyState') == 'complete' &&
          category_button.find_elements(:css, category_span_path).any?
      end
      category_span = category_button.find_element(:css, category_span_path).text
      category_name = category_span.gsub(/\s+/, ' ').squeeze(' ').strip
      category_names << category_name
    end

    file_name = File.join(Dir.pwd, output_dir, "#{review_type}_#{location_id}_all.json")
    reviews = driver.find_elements(:css, reviews_path)
    review_counter = reviews.size
    invalid_review_date = false

    loop do
      break if invalid_review_date == true

      if review_counter <= skip_review_size && skip_review_size != 0
        AppLogger.call("@@@@@ Skip #{review_counter} reviews. Next.")
        last_review = reviews.last
        scroll_into_element(last_review)
        sleep 5
        Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
          driver.execute_script('return document.readyState') == 'complete'
        end
        reviews.each do |review|
          driver.execute_script("arguments[0].remove();", review)
        end
        reviews = driver.find_elements(:css, reviews_path)
        review_counter += reviews.size
        next
      end
      AppLogger.call("@@@@@ After skip #{skip_review_size} reviews.")

      if reviews.empty?
        AppLogger.call('@@@@@ No new reviews loaded. Exiting loop.')
        AppLogger.call("@@@@@ Total reviews: #{total_reviews}")
        AppLogger.call("@@@@@ Current reviews data: #{data.size}")
        break
      end

      AppLogger.call("@@@@@ Total reviews: #{total_reviews}")
      AppLogger.call("@@@@@ Current reviews count: #{reviews.size}")
      reviews.each do |review|
        if invalid_review?(review)
          invalid_review_date = true
          break
        end

        scrape_data(review)
      end
      AppLogger.call("@@@@@ Current reviews data: #{data.size}")
      save_to_json(file_name, data) if data.any?

      last_review = reviews.last
      scroll_into_element(last_review)
      sleep 5
      Selenium::WebDriver::Wait.new(timeout: waiting_timeout).until do
        driver.execute_script('return document.readyState') == 'complete'
      end
      reviews.each do |review|
        driver.execute_script("arguments[0].remove();", review)
      end

      reviews = driver.find_elements(:css, reviews_path)

      if first_time_check == 'true'
        AppLogger.call('@@@@@ For the first_time. Exiting loop.')
        AppLogger.call("@@@@@ Total reviews: #{total_reviews}")
        AppLogger.call("@@@@@ Current reviews data: #{data.size}")
        break
      end
    end

    if data.any?
      target_file_name = File.join(Dir.pwd, output_dir, "#{review_type}_#{location_id}_#{data.size}.json")
      File.rename(file_name, target_file_name)
    end
    AppLogger.call("@@@@@ Done >>>>> get url: #{url}", { empty_line: true })
  ensure
    driver.quit
  end

  private

  def initialize_env
    @headless_mode ||= ENV.fetch('REVIEW_SCRAPER_HEADLESS_MODE', true)
    @waiting_timeout ||= ENV.fetch('REVIEW_SCRAPER_WAITING_TIMEOUT', 50).to_i
    @total_reviews_xpath ||= ENV.fetch('REVIEW_SCRAPER_TOTAL_REVIEWS_XPATH',
      '//div[contains(@class, "F7nice")]//span[contains(@aria-label, "reviews")]')
    @overview_tab_xpath ||= ENV.fetch('REVIEW_SCRAPER_OVERVIEW_TAB_XPATH',
      '//div[contains(@class, "RWPxGd")]//button[contains(@aria-label, "Overview")]')
    @reviews_tab_xpath ||= ENV.fetch('REVIEW_SCRAPER_REVIEWS_TAB_XPATH',
      '//div[contains(@class, "RWPxGd")]//button[contains(@aria-label, "Reviews")]')
    @sort_reviews_xpath ||= ENV.fetch('REVIEW_SCRAPER_SORT_REVIEWS_XPATH',
      '//div[contains(@class, "TrU0dc")]//button[contains(@aria-label, "Sort")]')
    @newest_path ||= ENV.fetch('REVIEW_SCRAPER_NEWEST_PATH', "div.fxNQSd[data-index='1']")
    @refine_reviews_path ||= ENV.fetch('REVIEW_SCRAPER_REFINE_REVIEWS_PATH',
                                       "div[aria-label='Refine reviews'] button[role='radio']")
    @category_span_path ||= ENV.fetch('REVIEW_SCRAPER_CATEGORY_SPAN_PATH', 'span.uEubGf')
    @reviews_path ||= ENV.fetch('REVIEW_SCRAPER_REVIEWS_PATH', 'div.jftiEf')
    @more_button_path ||= ENV.fetch('REVIEW_SCRAPER_MORE_BUTTON_PATH', 'button.w8nwRe')
    @review_description_path ||= ENV.fetch('REVIEW_SCRAPER_REVIEW_DESCRIPTION_PATH', 'span.wiI7pd')
    @review_date_path ||= ENV.fetch('REVIEW_SCRAPER_REVIEW_DATE_PATH', 'span.rsqaWe')
    @rating_path ||= ENV.fetch('REVIEW_SCRAPER_RATING_PATH', 'span.kvMYJc')
    @n_review_user_path ||= ENV.fetch('REVIEW_SCRAPER_N_REVIEW_USER_PATH', 'div.RfnDt')
    @url_user_path ||= ENV.fetch('REVIEW_SCRAPER_URL_USER_PATH', 'button.WEBjve')
    @owner_reply_path ||= ENV.fetch('REVIEW_SCRAPER_OWNER_REPLY_PATH', 'div.wiI7pd')
    @owner_reply_date_path ||= ENV.fetch('REVIEW_SCRAPER_OWNER_REPLY_DATE_PATH', 'span.DZSIDd')
    @skip_review_size ||= ENV.fetch('REVIEW_SCRAPER_SKIP_REVIEW_SIZE', 0).to_i
    @first_time_check ||= ENV.fetch('REVIEW_SCRAPER_FIRST_TIME_CHECK', 'true')
    @initialize_env ||= 'initialize_env'
  end

  def initialize_driver
    chromedriver_path = File.join(Dir.pwd, 'chromedriver')
    Selenium::WebDriver::Chrome::Service.driver_path = chromedriver_path
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-notifications')
    options.add_argument('--lang=en-GB')
    if headless_mode == 'true'
      options.add_argument('--headless')
      options.add_argument('--disable-gpu')
    end
    @driver ||= Selenium::WebDriver.for(:chrome, options: options)
    @driver.manage.window.resize_to(2000, 1300)
  end

  def sleep_short_time
    sleep(rand(3..5))
  end

  def scroll_into_element(element)
    # driver.execute_script('arguments[0].scrollIntoView(true);', element)
    driver.execute_script('arguments[0].scrollIntoView({behavior: "smooth", block: "start"});', element)
  end

  def invalid_review?(review)
    if review.find_elements(:css, more_button_path).any?
      more_button = review.find_element(:css, more_button_path)
      more_button.click
      sleep_short_time
    end

    review_date_text = review.find_element(:css, review_date_path).text
    review_date = review_time(review_date_text)

    parsed_review_date = safe_parse_date(review_date)
    parsed_latest_retrieval_from_date = safe_parse_date(latest_retrieval_from_date)
    parsed_latest_retrieval_to_date = safe_parse_date(latest_retrieval_to_date)

    return true if parsed_review_date.nil? || parsed_latest_retrieval_from_date.nil?

    if parsed_latest_retrieval_to_date.nil?
      parsed_review_date < parsed_latest_retrieval_from_date
    else
      parsed_review_date < parsed_latest_retrieval_from_date || parsed_review_date > parsed_latest_retrieval_to_date
    end
  end

  def scrape_data(review)
    if review.find_elements(:css, more_button_path).any?
      more_button = review.find_element(:css, more_button_path)
      more_button.click
      sleep_short_time
    end
    review_description = review.find_element(:css, review_description_path).text if review.find_elements(:css, review_description_path).any?
    id_review = review.attribute('data-review-id')
    review_date_text = review.find_element(:css, review_date_path).text
    review_date = review_time(review_date_text)
    retrieval_date = (Date.today - 1).strftime('%Y-%m-%d')
    rating = review.find_element(:css, rating_path).attribute('aria-label').split[0].to_f
    username = review.attribute('aria-label')
    if review.find_elements(:css, n_review_user_path).any? && review.find_element(:css, n_review_user_path)
                                                                   .text.match?(/(\d+) reviews/)
      n_review_user = review.find_element(:css, n_review_user_path).text.match(/(\d+) reviews/)[1].to_i
    end
    url_user = review.find_element(:css, url_user_path).attribute('data-href')
    owner_reply = review.find_element(:css, owner_reply_path).text if review.find_elements(:css,
                                                                                           owner_reply_path).any?
    if review.find_elements(:css, owner_reply_date_path).any?
      owner_reply_date_text = review.find_element(:css, owner_reply_date_path).text
      owner_reply_date = review_time(owner_reply_date_text)
    end
    data << {
      id_review: id_review,
      review_description: review_description,
      review_date: review_date,
      retrieval_date: retrieval_date,
      rating: rating,
      username: username,
      n_review_user: n_review_user,
      url_user: url_user,
      owner_reply: owner_reply,
      owner_reply_date: owner_reply_date,
    }
  end

  def review_time(date_text)
    review_time_to_time(date_text).strftime('%Y-%m-%d')
  rescue
    write_to_review_time_log(date_text)
    date_text
  end

  def write_to_review_time_log(date_text)
    time_stamp = Time.current.strftime('%Y%m%d%H%M%S')
    text_log = "#{time_stamp} => ArgumentError: Format Unsupported => #{date_text}"
    File.open('log/date_text.log', 'a') { |file| file.puts(text_log) }
  end

  def save_to_json(file_name, data)
    File.open(file_name, 'w') do |file|
      file.puts(JSON.pretty_generate(data))
    end
    AppLogger.call("@@@@@ Done >>>>> write into #{file_name} file")
  end

  def safe_parse_date(date_string)
    Date.parse(date_string)
  rescue
    nil
  end

  def valid_element_reviews?
    driver.find_elements(:xpath, reviews_tab_xpath).any?
  end
end
