# Injestion simulation
## Flow
1.	generate input data beforehand using fake_data_generator.py
to output folder
## Folder structure
- output of fake_data_generator
  {container}/(folder)/{output_time}/{timestamp}.json.gz
		- output_time example: 2020/12/31/00/00

## Usage of fake_data_generator.py
### - Generate 1 gz file which contains 10 logs every 3 seconds (throughput is controllable by parameters) until meximal 10 files
```python fake_data_generator.py -fc 1 -c 10 -i 3 -m 10```
### - Copy 10 gz files which contains 10 logs every 3 seconds (throughput is controllable by parameters) until meximal 100 files
```python fake_data_generator.py -fc 10 -c 10 -i 3 -m 100```

### - Other args
- ta : target storage account
- tk : target storage key
- tc : tartger container
- tf : target folder inside container

## data schema
```json
{
    "eventId": "b81d241f-5187-40b0-ab2a-940faf9757c0",
    "complexData": {
        "moreData0": 12.12345678901234,
        "moreData1": 12.12345678901234,
        "moreData2": 12.12345678901234,
        "moreData3": 12.12345678901234,
        "moreData4": 12.12345678901234,
        "moreData5": 12.12345678901234,
        "moreData6": 12.12345678901234,
        "moreData7": 12.12345678901234,
        "moreData8": 12.12345678901234,
        "moreData9": 12.12345678901234,
        "moreData10": 12.12345678901234,
        "moreData11": 12.12345678901234,
        "moreData12": 12.12345678901234,
        "moreData13": 12.12345678901234,
        "moreData14": 12.12345678901234,
        "moreData15": 12.12345678901234,
        "moreData16": 12.12345678901234,
        "moreData17": 12.12345678901234,
        "moreData18": 12.12345678901234,
        "moreData19": 12.12345678901234,
        "moreData20": 12.12345678901234,
        "moreData21": 12.12345678901234,
        "moreData22": 12.12345678901234
    },
    "value": 49.02278128887753,
	"deviceId": "contoso://device-id-1554",
	"companyId": "company-id-6",
    "deviceSequenceNumber": 0,
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```