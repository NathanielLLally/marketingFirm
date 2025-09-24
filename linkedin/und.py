import undetected_chromedriver as uc
import time
import os
from selenium.webdriver.chrome.options import Options

# Create ChromeOptions object
options = Options()

# Specify the absolute path to your Chrome binary
options.binary_location = "/home/nathaniel/src/git/marketingFirm/linkedin/chrome-linux64/chrome"  # Replace with your actual path

class ChromeProxy:

    def __init__(
        self,
        host: str,
        port: int,
        username: str = "",
        password: str = ""
    ):
        self.host = host
        self.port = port
        self.username = username
        self.password = password

    def get_path(self) -> str:
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), "proxy_extension")

    def create_extension(
        self,
        name: str = "Chrome Proxy",
        version = "1.0.0"
    ) -> str:
        proxy_folder = self.get_path()
        os.makedirs(proxy_folder, exist_ok = True)

        # generate manifest (establish extension name and version)
        manifest = ChromeProxy.manifest_json
        manifest = manifest.replace("<ext_name>", name)
        manifest = manifest.replace("<ext_ver>", version)

        # write manifest to extension directory
        with open(f"{proxy_folder}/manifest.json","w") as f:
            f.write(manifest)

        # generate javascript code (replace some placeholders)
        js = ChromeProxy.background_js 
        js = js.replace("<proxy_host>", self.host)
        js = js.replace("<proxy_port>", str(self.port))
        js = js.replace("<proxy_username>", self.username)
        js = js.replace("<proxy_password>", self.password)

        # write javascript code to extension directory
        with open(f"{proxy_folder}/background.js","w") as f:
            f.write(js)

        return proxy_folder

    manifest_json = """
    {
        "version": "<ext_ver>",
        "manifest_version": 3,
        "name": "<ext_name>",
        "permissions": [
            "proxy",
            "tabs",
            "storage",
            "webRequest",
            "webRequestAuthProvider"
        ],
        "host_permissions": [
            "<all_urls>"
        ],
        "background": {
            "service_worker": "background.js"
        },
        "minimum_chrome_version": "22.0.0"
    }
    """

    background_js = """
    var config = {
        mode: "fixed_servers",
        rules: {
            singleProxy: {
                scheme: "http",
                host: "<proxy_host>",
                port: parseInt("<proxy_port>")
            },
            bypassList: ["localhost"]
        }
    };

    chrome.proxy.settings.set({
        value: config,
        scope: "regular"
    }, function() {});

    function callbackFn(details) {
        return {
            authCredentials: {
                username: "<proxy_username>",
                password: "<proxy_password>"
            }
        };
    }

    chrome.webRequest.onAuthRequired.addListener(
        callbackFn, {
            urls: ["<all_urls>"]
        },
        ['blocking']
    );
    """

proxy = ChromeProxy(
    host = "198.23.239.134",
    port = "6540",
    username = "huosowav",
    password = "9tym2wl2a6ix"
)
extension_path = proxy.create_extension()


# Add the driver options
#options = uc.ChromeOptions() 
options.headless = False
options.add_argument(f"--load-extension={extension_path}")

# Configure the undetected_chromedriver options
driver = uc.Chrome(options=options) 

with driver:
    # Go to the target website
    #driver.get("https://httpbin.io/ip")
    #driver.get("https://linkedin.com/")
    # Wait for security check
    time.sleep(1)

    driver.get("https://www.linkedin.com/in/a-jason-jones-104aa312b?trk=people-guest_people_search-card")
    #driver.get("https://www.linkedin.com/directory/people-search?trk=homepage-basic_directory_peopleSearchDirectoryUrl")
    time.sleep(1)
    # Take a screenshot
    driver.save_screenshot('screenshot.png')
    # Close the browsers
    driver.quit()
