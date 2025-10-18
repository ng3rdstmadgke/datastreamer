import base64
import json
import logging
import os
from decimal import Decimal
from typing import Any, Dict

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_dynamodb = boto3.resource("dynamodb")
_table_name = os.environ["TABLE_NAME"]
_table = _dynamodb.Table(_table_name)


def _to_decimal(value: Any) -> Decimal:
    return Decimal(str(value))


def _clean_item(item: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in item.items() if v is not None}


def lambda_handler(event, context):
    records = event.get("Records", [])
    if not records:
        logger.info("No records to process.")
        return {"status": "empty"}

    with _table.batch_writer(overwrite_by_pkeys=["device_id", "event_ts"]) as batch:
        for record in records:
            try:
                payload = base64.b64decode(record["kinesis"]["data"])
                data = json.loads(payload)

                device_id = data.get("device_id")
                timestamp = data.get("timestamp")
                temperature = data.get("temperature")

                if device_id is None or timestamp is None:
                    logger.warning("Missing required fields in record: %s", data)
                    continue

                item = _clean_item({
                    "device_id": str(device_id),
                    "event_ts": _to_decimal(timestamp),
                    "temperature": _to_decimal(temperature) if temperature is not None else None,
                    "raw": json.dumps(data),
                })

                batch.put_item(Item=item)
            except Exception:
                logger.exception("Failed to process record")

    return {"status": "ok", "processed": len(records)}
