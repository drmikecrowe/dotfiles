class OnePass:
    def __init__(self, url):
        self.url = url
    def __repr__(self):
        if __xonsh__.env.get("ONEPASS_ENABLED", False):
            return $(op read @(self.url)).strip()
        else:
            return self.url

$OPENAI_API_KEY = OnePass("op://Private/OpenAI-API-Key/api-key")
