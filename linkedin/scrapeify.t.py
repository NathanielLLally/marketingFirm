import httpx
from parsel import Selector

response = httpx.get("https://www.linkedin.com/in/nathaniel-lally-0a45322/")
selector = Selector(response.text)

# in ScrapFly becomes this 👇
from scrapfly import ScrapeConfig, ScrapflyClient

# replaces your HTTP client (httpx in this case)
scrapfly = ScrapflyClient(key="scp-live-cd79086c889146738c7515ab8705c766")

response = scrapfly.scrape(ScrapeConfig(
    url="https://www.linkedin.com/in/nathaniel-lally-0a45322/",
    asp=True, # enable the anti scraping protection to bypass blocking
    country="US", # set the proxy location to a specfic country
    proxy_pool="public_residential_pool", # select the residential proxy pool for higher success rate
    render_js=True # enable rendering JavaScript (like headless browsers) to scrape dynamic content if needed
))

# use the built in Parsel selector
selector = response.selector
# access the HTML content
html = response.scrape_result['content']
