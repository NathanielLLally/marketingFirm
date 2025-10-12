import requests
import json
print(json.dumps(requests.get("https://tools.scrapfly.io/api/fp/ja3?extended=1").json()))
