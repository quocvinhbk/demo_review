# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Google Reviews scraper system that:
- Scrapes Google Maps reviews for locations and their competitors using Selenium WebDriver
- Formats and processes scraped data
- Uploads results to Databricks volumes
- Runs on a scheduled basis via cron jobs

**Tech Stack**: Ruby (primary scraping/processing) + Python (Databricks upload)

## Development Commands

### Ruby Environment

```bash
# Install dependencies
bundle install

# Run linter
bundle exec rubocop --parallel

# Auto-fix linting issues
bundle exec rubocop --auto-correct-all

# Run tests
bundle exec rspec
```

### Python Environment

```bash
# Install dependencies with Poetry
poetry install

# Run linter
ruff check .

# Auto-fix linting issues
ruff check --fix .

# Run Python upload script
poetry run python main.py
```

### Main Execution Scripts

```bash
# Run daily scraper (scrapes reviews for all locations/competitors)
ruby daily.rb

# Run formatter (processes scraped data into output format)
ruby review_formatter.rb

# Upload to Databricks (Python)
poetry run python main.py

# Backup rotation
ruby backup_directory_rotator.rb
```

## Architecture

### Data Flow

1. **Input**: `input/locations*.json` - Configuration file containing location and competitor details
2. **Scraping**: `daily.rb` orchestrates scraping via `ReviewDailyScraper`
   - Scrapes Google Maps reviews for each location
   - Scrapes competitor reviews for each location
   - Uses concurrent threading (configurable via `REVIEW_SCRAPER_MAX_CRAWL_THREADS`)
   - Outputs to `input/{location_id}/location_{id}_*.json` and `input/{location_id}/competitor_{id}_*.json`
3. **Formatting**: `review_formatter.rb` processes raw scraped data
   - Merges location/competitor metadata with review data
   - Outputs formatted JSON to `output/` directory
4. **Upload**: `main.py` uploads formatted files to Databricks
   - Uploads all `.json` and `.csv` files from `output/` to Databricks volumes
   - Backs up uploaded files to timestamped directories

### Key Components

**Scrapers**:
- `ReviewScraper` (review_scraper.rb) - Legacy scraper for one-off scraping from CSV input
- `ReviewDailyScraper` (review_daily_scraper.rb) - Daily scraper with date range filtering
  - Accepts `latest_retrieval_from_date` and `latest_retrieval_to_date` parameters
  - Stops scraping when reviews fall outside the date range
  - Handles both location and competitor reviews

**Processing**:
- `ReviewFormatter` (review_formatter.rb) - Merges scraped data with location metadata
- `DailyReviewsCounter` (daily_reviews_counter.rb) - Counts reviews per location

**Upload & Backup**:
- `Main` (main.py) - Databricks upload handler with retry logic
- `BackupDirectoryRotator` (backup_directory_rotator.rb) - Manages backup retention

**Utilities**:
- `Time` module (time.rb) - Parses various date formats from Google reviews
- `AppLogger` (app_logger.rb/py) - Unified logging
- `SlackNotify` (slack_notify.rb/py) - Slack notifications

### Selenium Configuration

The scrapers use Selenium WebDriver with Chrome:
- `chromedriver` binary must be in project root
- Configurable headless mode via `REVIEW_SCRAPER_HEADLESS_MODE`
- All XPath/CSS selectors are configurable via environment variables (see `.env.template`)

### Concurrent Scraping

`daily.rb` uses `concurrent-ruby` with a fixed thread pool:
- Thread pool size: `REVIEW_SCRAPER_MAX_CRAWL_THREADS` (default: 2)
- Each location group (location + competitors) runs in its own thread
- Retry logic: `REVIEW_SCRAPER_MAX_RETRIES` (default: 5)

### Duplicate Competitor Handling

`daily.rb` includes logic to handle competitors appearing in multiple locations:
- Identifies duplicates by matching addresses
- Scrapes only once and copies files to other locations
- See `build_duplicate_competitors` and `copy_duplicate_competitor_files` methods

## Configuration

Environment variables are managed via `.env` file (see `.env.template` for all options):

**Critical Settings**:
- `LATEST_RETRIEVAL_FROM_DATE` / `LATEST_RETRIEVAL_TO_DATE` - Date range for scraping
- `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, `DATABRICKS_VOLUME_PATH` - Databricks credentials
- `SLACK_WEBHOOK_URL` - Slack notifications
- `REVIEW_SCRAPER_MAX_CRAWL_THREADS` - Parallel scraping threads
- `ENVIRONMENT` - `production`, `development`, or `test`

**Scraper XPath/CSS Selectors**: All Google Maps element selectors are configurable to handle UI changes

## Cron Scheduling

Managed via `whenever` gem (config/schedule.rb):
- Scraping: `GOOGLE_REVIEWS_SCRAPING_TIME` (default: 01:15 AM)
- Upload: `ADD_GOOGLE_REVIEWS_TO_DATABRICKS_TIME` (default: 02:45 AM)
- Backup rotation: `ROTATE_BACKUP_DIRECTORY_TIME` (default: 03:00 AM)

## Directory Structure

```
input/           - Location config + scraped raw data (organized by location_id)
output/          - Formatted data ready for upload
log/             - Application logs
cronjob_script/  - Shell scripts executed by cron
```

## Testing

RSpec tests are in `spec/` directory:
- `spec/time_spec.rb` - Tests for date parsing logic
- Run with: `bundle exec rspec`

## Important Notes

- The project handles both initial full scrapes (`REVIEW_SCRAPER_FIRST_TIME_CHECK=true`) and incremental daily scrapes
- Date parsing is complex due to Google's various date formats across locales (see time.rb)
- Error handling includes retry logic with exponential backoff
- Slack notifications are sent for major events and failures
- RuboCop excludes several large scraper files from linting
