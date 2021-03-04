"""
  [Microsoft Stream-at-Scale project]
  1. This code is to generate data into landing data lake storage for testing
  """
import gzip
import json
import random
import time
import uuid
import threading
import traceback
import os#, sys, traceback
#import logging
from argparse import ArgumentParser
from datetime import datetime
# from multiprocessing import Pool

from azure.storage.blob import BlobServiceClient
#from azure.core.exceptions import ResourceExistsError
#from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.schedulers.background import BackgroundScheduler
# from apscheduler.events import EVENT_JOB_REMOVED, EVENT_JOB_EXECUTED, EVENT_JOB_ERROR

TOTAL_GEN_COUNT = 0
SCHEDULER = None
ARGS = None

def create_log():
    """ create log
    """
    complex_data_count = int(os.environ.get("COMPLEX_DATA_COUNT") or 23)
    number_of_devices = int(os.environ.get('NUMBER_OF_DEVICES') or 1000)
    number_of_companies = int(os.environ.get('NUMBER_OF_COMPANIES') or 100)
    content = {}
    content["eventId"] = str(uuid.uuid4())
    content["complexData"] = {}
    for i in range(complex_data_count):
        content["complexData"]["moreData{}".format(i)] = random.random()*90+10
    content["value"] = random.random()*90+10
    content["deviceId"] = f"contoso://device-id-{random.randint(0, number_of_devices-1)}"
    content["companyId"] = f"company-id-{random.randint(0, number_of_companies-1)}"
    content["deviceSequenceNumber"] = random.randint(0, number_of_devices)
    content["type"] = random.choice(["CO2", "TEMP"])
    content["createdAt"] = str(datetime.now())
    return content

def uploadlog_files_to_adl(filename, container_name, folder_path):
    """ upload single file to ADL
    """
    try:
        storage_account_name = ARGS.target_storage_account_name
        storage_account_key = ARGS.target_storage_account_key
      
        #global service_client
        connection_string = "DefaultEndpointsProtocol=https;AccountName={};AccountKey={};EndpointSuffix=core.windows.net".format(storage_account_name,storage_account_key)        
        service = BlobServiceClient.from_connection_string(conn_str=connection_string)

        blob_client = service.get_blob_client(container=container_name,blob="{}/{}".format(folder_path,filename))
        with open(filename, 'rb') as local_file:
            file_contents = local_file.read()
            blob_client.upload_blob(file_contents,overwrite=True)
            print("File uploaded: %s/%s size: %s" % (folder_path, filename, len(file_contents)))
        os.remove(filename)

    except Exception(ValueError, Exception):# pylint: disable=broad-except
        print(traceback.format_exc())

def create_upload_file(output_filefolder, output_filename):
    """create log file and upload to data lake storage
    """
    start_time = time.time()
    logs = []
    for _ in range(int(ARGS.count)):
        content = create_log()
        logs.append(content)
        # print(content)
    with gzip.open('{}.json.gz'.format(output_filename), 'at') as outfile:
        outfile.write(json.dumps(logs).replace("}, {", "}\n{")[1:-1])
    uploadlog_files_to_adl(outfile.name, ARGS.target_container, output_filefolder)

    print("time consume: {}s".format(str(time.time() - start_time)))

def start_gen():
    """ Start to gen test files
    """
    global TOTAL_GEN_COUNT
    global SCHEDULER
    print("start gen")
    generated_count = 0
    max_files = int(ARGS.max_files)
    lock = threading.Lock()
    while True:
        print("TOTAL_GEN_COUNT:{}, max_files:{}".format(TOTAL_GEN_COUNT, max_files))
        if TOTAL_GEN_COUNT == max_files:
            print("reach max files")
            print("remove current job")
            SCHEDULER.remove_job("fake_data_gen")
            return
        now = datetime.now()
        output_filefolder = "{}/{}/{}/{}/{}/{}".format( \
                ARGS.target_folder, \
                now.strftime("%Y"), now.strftime("%m"), \
                now.strftime("%d"), now.strftime("%H"), \
                now.strftime("%M"))
        print(f"output_filefolder:{output_filefolder}")
        create_upload_file(output_filefolder, datetime.timestamp(now))
        with lock:
            TOTAL_GEN_COUNT = TOTAL_GEN_COUNT + 1
        # add gen count
        generated_count = generated_count+1
        # break if count fulfilled in this interval
        if generated_count == int(ARGS.file_count_per_interval):
            print("reach interval")
            break

if __name__ == "__main__": # pragma: no cover
    parser = ArgumentParser()
    parser.add_argument("-fc", help="file count", dest="file_count_per_interval")
    parser.add_argument("-i", help="copy interval in seconds", dest="cp_interval")
    parser.add_argument("-m", help="max files to copy", dest="max_files")
    parser.add_argument("-c", help="log count", dest="count")
    parser.add_argument("-ta", help="target storage account name", \
        dest="target_storage_account_name")
    parser.add_argument("-tk", help="target storage account key", dest="target_storage_account_key")
    parser.add_argument("-tc", help="target container", dest="target_container")
    parser.add_argument("-tf", help="target folder", dest="target_folder")
    #parser.add_argument("-w", help="True for generate warm data", dest="warm")
    # parser.add_argument("-s", help="True for split by customer", dest="split")
    ARGS = parser.parse_args()
    #global SCHEDULER
    SCHEDULER = BackgroundScheduler()
    #scheduler = BlockingScheduler()
    # need to increase max_instances if encounter job misfire
    current_job = SCHEDULER.add_job(start_gen, 'interval', \
        seconds=int(ARGS.cp_interval), max_instances=5, \
            id='fake_data_gen')

    try:
        SCHEDULER.start()

        while True:
            time.sleep(3)
            #print(f"TOTAL_GEN_COUNT:{TOTAL_GEN_COUNT}: max:{args.max_files}")
            if int(TOTAL_GEN_COUNT) >= int(ARGS.max_files):
                break
    except (KeyboardInterrupt, SystemExit):
        print("end copy from keyboard Interrupt")
    print("end copy")
