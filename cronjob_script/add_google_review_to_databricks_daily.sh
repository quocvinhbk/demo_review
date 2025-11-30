#!/bin/bash

cd /var/workspace/google_reviews_scraper
source venv/bin/activate
poetry run python main.py
