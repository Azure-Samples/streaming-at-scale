from locust import HttpLocust, TaskSet, task
import os
import random
import requests
import datetime, time
import uuid
import sys    
import urllib
from urllib.parse import quote, quote_plus
import hmac
import hashlib
import base64
import json

from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

def get_auth_token(eh_namespace, eh_name, eh_key):
    uri = quote_plus("https://{0}.servicebus.windows.net/{1}".format(eh_namespace, eh_name))
    eh_key = eh_key.encode('utf-8')
    expiry = str(int(time.time() + 60 * 60 * 24 * 31))
    string_to_sign = (uri + '\n' + expiry).encode('utf-8')
    signed_hmac_sha256 = hmac.HMAC(eh_key, string_to_sign, hashlib.sha256)
    signature = quote(base64.b64encode(signed_hmac_sha256.digest()))
    return 'SharedAccessSignature sr={0}&sig={1}&se={2}&skn={3}'.format(uri, signature, expiry, "RootManageSharedAccessKey")

EVENT_HUB = {
    'namespace': os.environ['EVENTHUB_NAMESPACE'],
    'name': os.environ['EVENTHUB_NAME'],
    'key': os.environ['EVENTHUB_KEY'],
    'token': get_auth_token(os.environ['EVENTHUB_NAMESPACE'], os.environ['EVENTHUB_NAME'], os.environ['EVENTHUB_KEY'])
}

class DeviceSimulator(TaskSet):
    headers = {
        'Content-Type': 'application/atom+xml;type=noretry;charset=utf-8 ',
        'Authorization': EVENT_HUB['token'],
        'Host': EVENT_HUB['namespace'] + '.servicebus.windows.net'
    }

    endpoint = "/" + EVENT_HUB['name'] + "/messages?timeout=60&api-version=2014-01"

    counter = 1

    def on_start(self):
        self.deviceId = str(uuid.uuid4())

    @task
    def sendTemperature(self):
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'TEMP',
            'deviceId': self.deviceId,
            'createdAt': createdAt,
            'eventNumber': self.counter,
            'value': random.uniform(10,100),
            'complexData': {            
                'moreData0': random.uniform(10,100), 
                'moreData1': random.uniform(10,100),
                'moreData2': random.uniform(10,100),
                'moreData3': random.uniform(10,100),
                'moreData4': random.uniform(10,100),
                'moreData5': random.uniform(10,100),
                'moreData6': random.uniform(10,100),
                'moreData7': random.uniform(10,100),
                'moreData8': random.uniform(10,100),            
                'moreData9': random.uniform(10,100),
                'moreData10': random.uniform(10,100),
                'moreData11': random.uniform(10,100),
                'moreData12': random.uniform(10,100),
                'moreData13': random.uniform(10,100),
                'moreData14': random.uniform(10,100),
                'moreData15': random.uniform(10,100),
                'moreData16': random.uniform(10,100),
                'moreData17': random.uniform(10,100),
                'moreData18': random.uniform(10,100),
                'moreData19': random.uniform(10,100),
                'moreData20': random.uniform(10,100),
                'moreData21': random.uniform(10,100),
                'moreData22': random.uniform(10,100)
            }
        }
        self.send(json)

    @task
    def sendCO2(self):
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'CO2',
            'deviceId': self.deviceId,
            'createdAt': createdAt,
            'eventNumber': self.counter,
            'value': random.uniform(10,100),            
            'complexData': {            
                'moreData0': random.uniform(10,100), 
                'moreData1': random.uniform(10,100),
                'moreData2': random.uniform(10,100),
                'moreData3': random.uniform(10,100),
                'moreData4': random.uniform(10,100),
                'moreData5': random.uniform(10,100),
                'moreData6': random.uniform(10,100),
                'moreData7': random.uniform(10,100),
                'moreData8': random.uniform(10,100),            
                'moreData9': random.uniform(10,100),
                'moreData10': random.uniform(10,100),
                'moreData11': random.uniform(10,100),
                'moreData12': random.uniform(10,100),
                'moreData13': random.uniform(10,100),
                'moreData14': random.uniform(10,100),
                'moreData15': random.uniform(10,100),
                'moreData16': random.uniform(10,100),
                'moreData17': random.uniform(10,100),
                'moreData18': random.uniform(10,100),
                'moreData19': random.uniform(10,100),
                'moreData20': random.uniform(10,100),
                'moreData21': random.uniform(10,100),
                'moreData22': random.uniform(10,100)
            }
        }
        self.send(json)

    def send(self, jsonBody):
        self.counter += 1
        headers = self.headers
        headers['BrokerProperties'] = json.dumps({"PartitionKey": self.deviceId})

        self.client.post(self.endpoint, json=jsonBody, verify=False, headers=headers)

class MyLocust(HttpLocust):
    task_set = DeviceSimulator
    min_wait = 250
    max_wait = 500