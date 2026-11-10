
import os
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    pk = f"invoke#{context.aws_request_id}"

    item = {
        "pk": pk,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": "iam-02-lab",
        "message": event.get("message", "Hello from Lambda")
    }

    table.put_item(Item=item)

    return {
        "statusCode": 200,
        "pk": pk
    }
