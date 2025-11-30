# frozen_string_literal: true

require 'dotenv/load'

google_reviews_scraping_time = ENV.fetch('GOOGLE_REVIEWS_SCRAPING_TIME', '01:15 am')
add_google_reviews_to_databricks_time = ENV.fetch('ADD_GOOGLE_REVIEWS_TO_DATABRICKS_TIME', '02:45 am')
rotate_backup_directory_time = ENV.fetch('ROTATE_BACKUP_DIRECTORY_TIME', '03:00 am')
workspace = ENV.fetch('WORKSPACE', File.dirname(Dir.pwd))
core_directory = ENV.fetch('CORE_DIRECTORY', File.basename(Dir.pwd))

google_review_scraping_daily_script = File.join(
  workspace, core_directory, 'cronjob_script', 'google_review_scraping_daily.sh'
)
every :day, at: google_reviews_scraping_time do
  command(google_review_scraping_daily_script)
end

add_google_review_to_databricks_daily_script = File.join(
  workspace, core_directory, 'cronjob_script', 'add_google_review_to_databricks_daily.sh'
)
every :day, at: add_google_reviews_to_databricks_time do
  command(add_google_review_to_databricks_daily_script)
end

rotate_backup_directory_daily_script = File.join(
  workspace, core_directory, 'cronjob_script', 'rotate_backup_directory_daily.sh'
)
every :day, at: rotate_backup_directory_time do
  command(rotate_backup_directory_daily_script)
end
