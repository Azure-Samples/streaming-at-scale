from locust import HttpLocust, TaskSet, task
import os
import random
import requests
import datetime, time
import uuid
import random

from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

class DeviceSimulator(TaskSet):
    headers = {
        'Content-Type': 'application/json;charset=utf-8 ',
        'Authorization': os.environ['IOTHUB_SAS_TOKEN'],
        'Host': os.environ['IOTHUB_NAME'] + '.azure-devices.net'
    }

    def on_start(self):
        pass   

    @task
    def sendTemperature(self):
        
        deviceId = 'device-{0}'.format(random.randint(1, 3))
        endpoint = "/devices/"+ deviceId +"/messages/events?api-version=2018-04-01"

        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'TEMP',
            'deviceId': deviceId,
            'createdAt': createdAt,
            'data': random.uniform(10,100)        
        }

        self.client.post(endpoint, json=json, verify=False, headers=self.headers)

    @task
    def sendCO2(self):

        deviceId = 'device-{0}'.format(random.randint(1, 3))
        endpoint = "/devices/"+ deviceId +"/messages/events?api-version=2018-04-01"
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'CO2',
            'deviceId': deviceId,
            'createdAt': createdAt,
            'value': random.uniform(300,400)            
        }

        self.client.post(endpoint, json=json, verify=False, headers=self.headers)

class MyLocust(HttpLocust):
    task_set = DeviceSimulator
    min_wait = 500
    max_wait = 1000    