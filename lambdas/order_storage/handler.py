import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ['ORDERS_TABLE']

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    order = event['order'] if 'order' in event else event

    table.put_item(
        Item={
            'order_id': order['order_id'],
            'customer_name': order['customer_name'],
            'items': order['items'],
            'status': 'PENDING',
            'created_at': datetime.utcnow().isoformat()
        }
    )

    return {
        'message': 'Order stored successfully',
        'order': order
    }
