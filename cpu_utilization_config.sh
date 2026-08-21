#!/bin/bash

set -e

REGION="ap-south-1"
ALARM_NAME="EC2-CPU-Utilization"

echo "======================================"
echo "       EC2 CPU ALARM SETUP"
echo "======================================"

# Get Instance ID
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds:21600")

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token:$TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

echo "Instance ID: $INSTANCE_ID"
echo

# CPU limit
read -p "Enter CPU utilization limit (%) [e.g. 80]: " LIMIT

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
    echo "Invalid CPU limit. Enter 1-100."
    exit 1
fi

echo
echo "When CPU reaches $LIMIT%, what should happen?"
echo
echo "1) REBOOT EC2"
echo "2) STOP EC2"
echo "3) DO NOTHING"
echo

read -p "Select option [1-3]: " ACTION

case $ACTION in
    1)
        ACTION_NAME="REBOOT"
        ALARM_ACTION="arn:aws:automate:${REGION}:ec2:reboot"
        ;;
    2)
        ACTION_NAME="STOP"
        ALARM_ACTION="arn:aws:automate:${REGION}:ec2:stop"
        ;;
    3)
        ACTION_NAME="NOTHING"
        ALARM_ACTION=""
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

echo
echo "--------------------------------------"
echo "Instance : $INSTANCE_ID"
echo "CPU Limit: $LIMIT%"
echo "Action   : $ACTION_NAME"
echo "--------------------------------------"

read -p "Continue? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "Creating / updating CloudWatch alarm..."

if [ -n "$ALARM_ACTION" ]; then

    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "EC2 CPU utilization alarm" \
        --namespace "AWS/EC2" \
        --metric-name "CPUUtilization" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --statistic Average \
        --period 60 \
        --evaluation-periods 5 \
        --threshold "$LIMIT" \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --alarm-actions "$ALARM_ACTION" \
        --region "$REGION"

else

    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "EC2 CPU utilization alarm" \
        --namespace "AWS/EC2" \
        --metric-name "CPUUtilization" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --statistic Average \
        --period 60 \
        --evaluation-periods 5 \
        --threshold "$LIMIT" \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --region "$REGION"

fi

echo
echo "======================================"
echo "          SETUP COMPLETED"
echo "======================================"
echo
echo "Instance : $INSTANCE_ID"
echo "CPU Limit: $LIMIT%"
echo "Action   : $ACTION_NAME"
echo "Alarm    : $ALARM_NAME"
echo
echo "✓ CloudWatch CPU alarm configured"