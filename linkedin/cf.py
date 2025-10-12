# pip install webdriver-manager
from webdriver_manager.chrome import ChromeDriverManager
from selenium import webdriver 
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.chrome.options import Options 
import time

# Add selenium option
options = Options()
options.headless = False

# Configure Selenium options and download the default web driver automatically
driver = webdriver.Chrome(options=options, service=ChromeService(ChromeDriverManager().install()))
# Maximize the browser widnows size
driver.maximize_window()

# Go the target website
driver.get("https://nowsecure.nl/")
# Wait for security check
time.sleep(4)
# Take screenshot
driver.save_screenshot('screenshot.png')
# Close the driver
driver.close()

