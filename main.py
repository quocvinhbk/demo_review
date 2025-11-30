from databricks.sdk import WorkspaceClient
import os
from dotenv import load_dotenv
from constant import OUTPUT_PATH
import time
import shutil
from datetime import datetime, timedelta
from app_logger import AppLogger
from slack_notify import SlackNotify

# Load environment variables from .env file
load_dotenv()


class Main:
    def __init__(self, host, token, local_output_folder=OUTPUT_PATH, databricks_volume_path="", max_retries=3):
        self.client = WorkspaceClient(host=host, token=token)
        self.local_output_folder = local_output_folder
        self.databricks_volume_path = databricks_volume_path
        self.max_retries = max_retries

    def is_valid_file(self, file):
        """
        Check if the file is valid for processing (not `.keep` and has `.json` or `.csv` extension).
        """
        return file != ".keep" and file.endswith((".json", ".csv"))

    def upload_file(self, local_file_path, databricks_file_path):
        retries = 0
        while retries < self.max_retries:
            try:
                with open(local_file_path, "rb") as f:
                    self.client.files.upload(databricks_file_path, f)
                AppLogger.call(f"Uploaded: {local_file_path} -> {databricks_file_path}")
                return True
            except Exception as e:
                retries += 1
                AppLogger.call(f"Failed to upload {local_file_path} (Attempt {retries}/{self.max_retries}): {e}")
                time.sleep(2**retries)
        # If all retries fail, log the failed upload
        AppLogger.call(f"Failed to upload {local_file_path} after {self.max_retries} attempts.")

    def upload_folder(self):
        """
        Upload all files from the local output folder to the Databricks volume.
        """
        message = 'Starting upload files to Databricks'
        AppLogger.call(f"@@@@@ {message}")
        SlackNotify.call(f":arrows_counterclockwise: {message}")
        for root, _, files in os.walk(self.local_output_folder):
            for file in files:
                if not self.is_valid_file(file):
                    continue

                local_file_path = os.path.join(root, file)
                review_path = os.path.relpath(local_file_path, self.local_output_folder)
                databricks_file_path = os.path.join(self.databricks_volume_path, review_path)
                self.upload_file(local_file_path, databricks_file_path)

        message = 'Done upload files to Databricks'
        AppLogger.call(f"@@@@@ {message}")
        SlackNotify.call(f":white_check_mark: {message}")

        # Backup the output folder
        self.backup_output_folder()

    def backup_output_folder(self):
        """
        Move all files from the output directory to a backup directory while keeping the output folder intact.
        """
        message = 'Starting move files to backup'
        AppLogger.call(f"@@@@@ {message}")
        SlackNotify.call(f":arrows_counterclockwise: {message}")
        timestamp = (datetime.now() - timedelta(days=1)).strftime("%Y%m%d%H%M%S")
        backup_output_path = os.getenv("BACKUP_OUTPUT_PATH", os.path.join(os.path.dirname(os.getcwd()), "backups"))
        core_directory = os.getenv("CORE_DIRECTORY", os.path.basename(os.getcwd()))
        backup_path = os.path.join(backup_output_path, core_directory, f"output_{timestamp}")

        # Create the backup folder if it doesn't exist
        os.makedirs(backup_path, exist_ok=True)

        # Move all files from the output folder to the backup folder
        for root, _, files in os.walk(self.local_output_folder):
            for file in files:
                if not self.is_valid_file(file):
                    continue

                file_path = os.path.join(root, file)
                review_path = os.path.relpath(file_path, self.local_output_folder)
                backup_file_path = os.path.join(backup_path, review_path)

                # Create subdirectories in the backup folder if necessary
                os.makedirs(os.path.dirname(backup_file_path), exist_ok=True)

                # Move the file
                shutil.move(file_path, backup_file_path)
                print(f"Moved: {file_path} -> {backup_file_path}")

        message = 'Done move files to backup'
        AppLogger.call(f"@@@@@ {message}")
        SlackNotify.call(f":white_check_mark: {message}")


if __name__ == "__main__":
    host = os.getenv("DATABRICKS_HOST")
    token = os.getenv("DATABRICKS_TOKEN")
    databricks_volume_path = os.getenv("DATABRICKS_VOLUME_PATH")
    max_retries = int(os.getenv("UPLOAD_FILES_MAX_RETRIES", 3))

    # Initialize the uploader
    uploader = Main(
        host=host,
        token=token,
        local_output_folder=OUTPUT_PATH,
        databricks_volume_path=databricks_volume_path,
        max_retries=max_retries,
    )

    # Upload all files in the output folder
    uploader.upload_folder()
