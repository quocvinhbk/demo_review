import os


class AppLogger:
    def __init__(self, message, file_name="app.log", empty_line=False):
        if not message:
            raise ValueError("Invalid message")

        self.message = message
        self.file_path = os.path.join("log", file_name)
        self.empty_line = empty_line

    @classmethod
    def call(cls, message, file_name="app.log", empty_line=False):
        logger = cls(message, file_name, empty_line)
        logger.log()

    def log(self):
        os.makedirs(os.path.dirname(self.file_path), exist_ok=True)
        with open(self.file_path, "a") as file:
            self._print_and_write_to_log(file)

    def _print_and_write_to_log(self, file):
        if self.empty_line:
            print(self.message)
            print()

            file.write(self.message + "\n")
            file.write("\n")
        else:
            print(self.message)

            file.write(self.message + "\n")
