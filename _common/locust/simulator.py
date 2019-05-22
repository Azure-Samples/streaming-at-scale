from locust import HttpLocust, TaskSet, task
import os
import random
import requests
import datetime, time
import uuid
import random

EVENT_HUB = {
    'namespace': os.environ['EVENTHUB_NAMESPACE'],
    'name': os.environ['EVENTHUB_NAME'],
    'key': os.environ['EVENTHUB_KEY'],
    'token': os.environ['EVENTHUB_SAS_TOKEN']
}

from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

class DeviceSimulator(TaskSet):
    headers = {
        'Content-Type': 'application/atom+xml;type=noretry;charset=utf-8 ',
        'Authorization': EVENT_HUB['token'],
        'Host': EVENT_HUB['namespace'] + '.servicebus.windows.net'
    }

    endpoint = "/" + EVENT_HUB['name'] + "/messages?timeout=60&api-version=2014-01"

    @task
    def sendTemperature(self):
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        deviceIndex = random.randint(0, 999)

        json={
            'eventId': eventId,
            'type': 'TEMP',
            'deviceId': 'contoso://device-id-{0}'.format(deviceIndex),
            'createdAt': createdAt,
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
                'moreData9': random.uniform(10,100)                        
            }
        }

        self.client.post(self.endpoint, json=json, verify=False, headers=self.headers)

    @task
    def sendCO2(self):
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        deviceIndex = random.randint(0, 999) + 1000

        json={
            'eventId': eventId,
            'type': 'CO2',
            'deviceId': 'contoso://device-id-{0}'.format(deviceIndex),
            'createdAt': createdAt,
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
                'moreData9': random.uniform(10,100)                        
            }
        }

        self.client.post(self.endpoint, json=json, verify=False, headers=self.headers)

class MyLocust(HttpLocust):
    task_set = DeviceSimulator
    min_wait = 500
    max_wait = 1000 