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
        
        deviceId = 'SimulatedFridge-{0}'.format(str(random.randint(1, 100)).rjust(4, "0"))
        endpoint = "/devices/"+ deviceId +"/messages/events?api-version=2018-04-01"

        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'TEMP',
            'deviceId': deviceId,
            'createdAt': createdAt,
            'deviceType': 'Fridge',
            'temperature': random.uniform(20, 32)       
        }

        self.client.post(endpoint, json=json, verify=False, headers=self.headers)

    @task
    def sendState(self):

        deviceId = 'SimulatedLightBulb-{0}'.format(str(random.randint(1, 100)).rjust(4, "0"))
        endpoint = "/devices/"+ deviceId +"/messages/events?api-version=2018-04-01"
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'STATE',
            'deviceId': deviceId,
            'createdAt': createdAt,
            'deviceType': 'LightBulb',
            'state': random.choice(['on', 'off'])       
        }

        self.client.post(endpoint, json=json, verify=False, headers=self.headers)

class MyLocust(HttpLocust):
    task_set = DeviceSimulator
    min_wait = 500
    max_wait = 1000    