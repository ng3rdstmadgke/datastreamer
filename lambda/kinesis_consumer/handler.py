import base64
import json
import logging
import os
from decimal import Decimal
from typing import Any, Dict, Optional

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RETENTION_SECONDS = 3 * 24 * 60 * 60

_dynamodb = boto3.resource("dynamodb")
_table_name = os.environ["TABLE_NAME"]
_table = _dynamodb.Table(_table_name)


def _to_decimal(value: Any) -> Decimal:
    return Decimal(str(value))


def _clean_item(item: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in item.items() if v is not None}


def _expires_at(timestamp: Any) -> Optional[int]:
    try:
        # DynamoDB TTL は整数の UNIX エポック秒が必要
        base_ts = int(float(timestamp))
    except (TypeError, ValueError):
        return None
    return base_ts + RETENTION_SECONDS


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

                expires_at = _expires_at(timestamp)

                item = _clean_item({
                    "device_id": str(device_id),
                    "event_ts": _to_decimal(timestamp),
                    "temperature": _to_decimal(temperature) if temperature is not None else None,
                    "raw": json.dumps(data),
                    "expires_at": _to_decimal(expires_at) if expires_at is not None else None,
                })

                batch.put_item(Item=item)
            except Exception:
                logger.exception("Failed to process record")

    return {"status": "ok", "processed": len(records)}
