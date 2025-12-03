#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

GREEN='\033[0;32m'
NC='\033[0m' # No Color
# Logging functions
log_info() {
    echo -e "$GREEN[INFO]$NC $1"
}

WORKSPACE=/var/workspace
CORE_DIRECTORY=demo_review
CHROME_DRIVE_DIRECTORY=chromedriver_linux64
PYENV_PYTHON_PATH=/root/.pyenv/shims/python
VENV_PATH=venv/bin/activate
BACKUP_OUTPUT_PATH=/var/backups

PROJECT_PATH="$WORKSPACE/$CORE_DIRECTORY"

log_info "Step 1/8: Running bundle install..."
cd $PROJECT_PATH && \
  bash -lc 'bundle install'

log_info "Step 2/8: Removing old chromedriver..."
rm -f $PROJECT_PATH/chromedriver

log_info "Step 3/8: Adding server chromedriver..."
cp $WORKSPACE/$CHROME_DRIVE_DIRECTORY/chromedriver $PROJECT_PATH/chromedriver && \
   chmod +x $PROJECT_PATH/chromedriver

log_info "Step 4/8: Removing old virtual environment..."
rm -rf $PROJECT_PATH/venv

log_info "Step 5/8: Creating virtual environment and installing dependencies..."
cd $PROJECT_PATH && \
  $PYENV_PYTHON_PATH -m venv venv && \
  . $VENV_PATH && pip install --upgrade pip && \
  . $VENV_PATH && pip install -r requirements.txt && \
  . $VENV_PATH && poetry lock --no-update && \
  . $VENV_PATH && poetry install --no-root

log_info "Step 6/8: Creating backup directory..."
mkdir -p $BACKUP_OUTPUT_PATH/$CORE_DIRECTORY

log_info "Step 7/8: Creating output, input, and log directories..."
mkdir -p $PROJECT_PATH/output && \
  mkdir -p $PROJECT_PATH/input && \
  mkdir -p $PROJECT_PATH/log

log_info "Step 8/8: Updating crontab..."
cd $PROJECT_PATH && bash -lc 'whenever --update-crontab'

log_info "Deployment completed successfully!"
