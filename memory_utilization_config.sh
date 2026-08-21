#!/bin/bash

set -e

REGION="ap-south-1"
ALARM_NAME="EC2-Memory-Utilization"

echo "======================================"
echo "      EC2 MEMORY ALARM SETUP"
echo "======================================"

# Get instance ID
INSTANCE_ID=$(TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds:21600") && \
  curl -sH "X-aws-ec2-metadata-token:$TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

echo "Instance ID: $INSTANCE_ID"
echo

# Ask memory limit
read -p "Enter memory utilization limit (%) [e.g. 80]: " LIMIT

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
    echo "Invalid limit. Enter value between 1 and 100."
    exit 1
fi

echo
echo "When memory reaches $LIMIT%, what should happen?"
echo
echo "1) REBOOT EC2"
echo "2) STOP EC2"
echo "3) DO NOTHING"
echo

read -p "Select option [1-3]: " ACTION

case $ACTION in

    1)
        ACTION_NAME="REBOOT"
        ;;
    2)
        ACTION_NAME="STOP"
        ;;
    3)
        ACTION_NAME="NOTHING"
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

echo
echo "--------------------------------------"
echo "Configuration"
echo "--------------------------------------"
echo "Instance : $INSTANCE_ID"
echo "Limit    : $LIMIT%"
echo "Action   : $ACTION_NAME"
echo "--------------------------------------"
echo

read -p "Continue? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "Checking CloudWatch Agent..."

# Install CloudWatch Agent if not installed
if ! command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then

    echo "Installing CloudWatch Agent..."

    if command -v apt-get >/dev/null 2>&1; then

        wget -q https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

        sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

        rm -f amazon-cloudwatch-agent.deb

    elif command -v yum >/dev/null 2>&1; then

        sudo yum install -y amazon-cloudwatch-agent

    else
        echo "Unsupported operating system."
        exit 1
    fi
fi

echo "✓ CloudWatch Agent installed"

# Create CloudWatch Agent configuration
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

sudo tee /opt/aws/amazon-cloudwatch-agent/etc/memory-config.json > /dev/null <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

echo "✓ Memory monitoring configuration created"

# Start / update CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/memory-config.json \
    -s

echo "✓ CloudWatch Agent started"

# Determine alarm action
case $ACTION in

    1)
        ALARM_ACTION="arn:aws:automate:${REGION}:ec2:reboot"
        ;;
        
    2)
        ALARM_ACTION="arn:aws:automate:${REGION}:ec2:stop"
        ;;

    3)
        ALARM_ACTION=""
        ;;

esac

echo
echo "Creating / updating CloudWatch alarm..."

if [ -n "$ALARM_ACTION" ]; then

    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "EC2 memory utilization alarm" \
        --namespace "CWAgent" \
        --metric-name "mem_used_percent" \
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
        --alarm-description "EC2 memory utilization alarm" \
        --namespace "CWAgent" \
        --metric-name "mem_used_percent" \
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

echo "Instance ID : $INSTANCE_ID"
echo "Memory Limit: $LIMIT%"
echo "Action      : $ACTION_NAME"
echo "Alarm       : $ALARM_NAME"
echo "Region      : $REGION"

echo
echo "CloudWatch Alarm:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"

echo
echo "✓ Everything configured successfully."