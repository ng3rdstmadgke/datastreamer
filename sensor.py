import argparse
import boto3
import json
import random
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send random telemetry events to Kinesis.")
    parser.add_argument(
        "--stream-name",
        required=True,
        help="Kinesis Data Stream name to which the events are sent.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    kinesis = boto3.client("kinesis", region_name="ap-northeast-1")

    while True:
        rec = {
            "device_id": f"sensor-{random.randint(1,5)}",
            "temperature": round(random.uniform(15, 30), 2),
            "timestamp": time.time(),  # UNIX秒(小数)
        }
        print(rec)
        kinesis.put_record(
            StreamName=args.stream_name,
            Data=json.dumps(rec),
            PartitionKey=rec["device_id"],
        )
        time.sleep(1)


if __name__ == "__main__":
    main()
