import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ['FAILED_ORDERS_TABLE']

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    for record in event['Records']:
        body = json.loads(record['body'])

        table.put_item(
            Item={
                'order_id': body.get('order', {}).get('order_id', 'UNKNOWN'),
                'original_payload': body,
                'timestamp': datetime.utcnow().isoformat()
            }
        )

    return {'message': 'DLQ records stored'}
