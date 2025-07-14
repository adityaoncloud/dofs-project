import json

def lambda_handler(event, context):
    required_fields = ['order_id', 'customer_name', 'items']

    for field in required_fields:
        if field not in event:
            raise ValueError(f"Missing required field: {field}")

    if not isinstance(event['items'], list) or len(event['items']) == 0:
        raise ValueError("Items must be a non-empty list")

    return {
        'message': 'Validation passed',
        'order': event
    }
