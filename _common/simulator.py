from locust import HttpLocust, TaskSet, task
import os
import gevent
import random
import requests
import datetime, time
import uuid
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

class DeviceSimulator(TaskSet):
    headers = {
        'Content-Type': 'application/atom+xml;type=noretry;charset=utf-8 ',
        'Authorization': os.environ['EVENTHUB_SAS_TOKEN'],
        'Host': os.environ['EVENTHUB_NAMESPACE'] + '.servicebus.windows.net'
    }
    endpoint = "/" + os.environ['EVENTHUB_NAME'] + "/messages?timeout=60&api-version=2014-01"

    def on_start(self):
        pass   

    @task(20)
    def send(self):
        eventId = str(uuid.uuid4())
        createdAt = str(datetime.datetime.utcnow().replace(microsecond=3).isoformat()) + "Z"

        json={
            'eventId': eventId,
            'type': 'VALUE_READ',
            'deviceId': '78902df4-7b5d-43a3-b017-f8fbfb86a2f0',
            'createdAt': createdAt
        }

        with self.client.post(self.endpoint,
                        json=json,
                        verify=False,
                        headers=self.headers,
                        catch_response=True) as response:

            if response.status_code == 201:                
                response.success()
            else:
                print(response.status_code)
                response.failure("Error sending message to EventHub")

    @task(5)
    def stop(self):
        self.interrupt()

class MyLocust(HttpLocust):
    task_set = DeviceSimulator
    min_wait = 500
    max_wait = 2500
