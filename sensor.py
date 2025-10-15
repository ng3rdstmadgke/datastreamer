import boto3, json, random, time
kinesis = boto3.client("kinesis", region_name="ap-northeast-1")
while True:
    rec = {"device_id": f"sensor-{random.randint(1,5)}",
           "temperature": round(random.uniform(15,30),2),
           "timestamp": time.time()}  # UNIX秒(小数)
    print(rec)
    kinesis.put_record(StreamName="temperature-stream",
                       Data=json.dumps(rec),
                       PartitionKey=rec["device_id"])
    time.sleep(1)

