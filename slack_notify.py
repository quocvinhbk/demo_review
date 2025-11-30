import os
import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


class SlackNotify:
    def __init__(self, message):
        """
        Initialize the SlackNotify class.
        :param message: The message to send to Slack.
        """
        self.message = message
        self.webhook_url = os.getenv("SLACK_WEBHOOK_URL")
        self.channel = os.getenv("SLACK_CHANNEL")

    @classmethod
    def call(cls, message):
        """
        Class method to send a notification to Slack.
        :param message: The message to send to Slack.
        """
        instance = cls(message)
        instance.send_notification()

    def send_notification(self):
        payload = {"text": self.message, "channel": self.channel}
        headers = {"Content-Type": "application/json"}
        requests.post(self.webhook_url, json=payload, headers=headers)
