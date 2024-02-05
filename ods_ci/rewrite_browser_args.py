import sys

import yaml

vars = yaml.load(sys.stdin, yaml.Loader)

vars["BROWSER"]["OPTIONS"] = [
    "--ignore-certificate-errors",
    "--window-size=1920,1024",
    "--headless",
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
]

yaml.dump(vars, stream=sys.stdout)
