import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

route53 = boto3.client('route53')
ec2 = boto3.client('ec2')

HOSTED_ZONE_ID = "${hosted_zone_id}"
DOMAIN_NAME = "${domain_name}"

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Get all running instances in the ASG
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'instance-state-name', 'Values': ['running']},
                {'Name': 'tag:aws:autoscaling:groupName', 'Values': ['web-asg']}
            ]
        )

        # Find the first running instance
        instance_ip = None
        instance_private_ip = None

        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                if instance['State']['Name'] == 'running':
                    instance_ip = instance.get('PublicIpAddress')
                    instance_private_ip = instance.get('PrivateIpAddress')
                    break
            if instance_ip:
                break

        if not instance_ip:
            logger.info("No running instances found, removing DNS record")
            # Remove the DNS record if no instances are running
            change_batch = {
                'Changes': [{
                    'Action': 'DELETE',
                    'ResourceRecordSet': {
                        'Name': f'ssh.{DOMAIN_NAME}',
                        'Type': 'A',
                        'TTL': 60,
                        'ResourceRecords': [{'Value': '1.1.1.1'}]  # Dummy value for deletion
                    }
                }]
            }
        else:
            logger.info(f"Updating DNS record for ssh.{DOMAIN_NAME} to {instance_ip}")
            # Update DNS record with current instance IP
            change_batch = {
                'Changes': [{
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': f'ssh.{DOMAIN_NAME}',
                        'Type': 'A',
                        'TTL': 60,
                        'ResourceRecords': [{'Value': instance_ip}]
                    }
                }, {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': f'ssh-private.{DOMAIN_NAME}',
                        'Type': 'A',
                        'TTL': 60,
                        'ResourceRecords': [{'Value': instance_private_ip}]
                    }
                }]
            }

        # Apply the changes
        try:
            response = route53.change_resource_record_sets(
                HostedZoneId=HOSTED_ZONE_ID,
                ChangeBatch=change_batch
            )
            logger.info(f"DNS update successful: {response['ChangeInfo']['Id']}")

        except route53.exceptions.InvalidChangeBatch:
            # Record might not exist for deletion, ignore this error
            logger.info("DNS record didn't exist, skipping deletion")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'DNS updated successfully',
                'public_ip': instance_ip,
                'private_ip': instance_private_ip
            })
        }

    except Exception as e:
        logger.error(f"Error updating DNS: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
