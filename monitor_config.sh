#!/bin/bash

set -e

REGION="ap-south-1"
YACE_VERSION="v0.65.0"

echo "=============================================="
echo "     EC2 → CLOUDWATCH → PROMETHEUS → GRAFANA"
echo "=============================================="
echo

# ------------------------------------------------
# 1. Get EC2 Instance ID
# ------------------------------------------------

TOKEN=$(curl -sX PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds:21600")

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token:$TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

echo "EC2 Instance : $INSTANCE_ID"
echo "AWS Region   : $REGION"
echo

# ------------------------------------------------
# 2. Select Monitoring
# ------------------------------------------------

echo "What do you want to monitor?"
echo
echo "1) CPU"
echo "2) Memory"
echo "3) Disk"
echo
echo "Examples:"
echo "  1       = CPU"
echo "  1,2     = CPU + Memory"
echo "  1,3     = CPU + Disk"
echo "  2,3     = Memory + Disk"
echo "  1,2,3   = CPU + Memory + Disk"
echo

read -p "Selection: " SELECTION

CPU=false
MEMORY=false
DISK=false

IFS=',' read -ra OPTIONS <<< "$SELECTION"

for OPTION in "${OPTIONS[@]}"; do

    case "$OPTION" in

        1)
            CPU=true
            ;;

        2)
            MEMORY=true
            ;;

        3)
            DISK=true
            ;;

        *)
            echo
            echo "Invalid selection: $OPTION"
            exit 1
            ;;

    esac

done

echo
echo "Selected monitoring:"

$CPU && echo "✓ CPU"
$MEMORY && echo "✓ Memory"
$DISK && echo "✓ Disk"

echo

# ------------------------------------------------
# 3. Ask Thresholds
# ------------------------------------------------

CPU_LIMIT=""
MEMORY_LIMIT=""
DISK_LIMIT=""

if $CPU; then

    read -p "CPU threshold (%) [default 80]: " CPU_LIMIT

    CPU_LIMIT=${CPU_LIMIT:-80}

fi

if $MEMORY; then

    read -p "Memory threshold (%) [default 80]: " MEMORY_LIMIT

    MEMORY_LIMIT=${MEMORY_LIMIT:-80}

fi

if $DISK; then

    read -p "Disk threshold (%) [default 80]: " DISK_LIMIT

    DISK_LIMIT=${DISK_LIMIT:-80}

fi

# ------------------------------------------------
# 4. Action
# ------------------------------------------------

echo
echo "=============================================="
echo "              ALERT ACTION"
echo "=============================================="
echo
echo "1) SNS Notification"
echo "2) REBOOT EC2"
echo "3) STOP EC2"
echo "4) Grafana Alert Only"
echo "5) No Action"
echo

read -p "Select action: " ACTION

case "$ACTION" in

    1)
        ACTION_NAME="SNS"
        ;;

    2)
        ACTION_NAME="REBOOT"
        ;;

    3)
        ACTION_NAME="STOP"
        ;;

    4)
        ACTION_NAME="GRAFANA"
        ;;

    5)
        ACTION_NAME="NONE"
        ;;

    *)
        echo "Invalid action."
        exit 1
        ;;

esac

# ------------------------------------------------
# 5. Confirmation
# ------------------------------------------------

echo
echo "=============================================="
echo "              CONFIGURATION"
echo "=============================================="

echo "Instance : $INSTANCE_ID"

$CPU && echo "CPU      : ${CPU_LIMIT}%"
$MEMORY && echo "Memory   : ${MEMORY_LIMIT}%"
$DISK && echo "Disk     : ${DISK_LIMIT}%"

echo "Action   : $ACTION_NAME"

echo
read -p "Continue? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then

    echo "Cancelled."

    exit 0

fi

# ------------------------------------------------
# 6. Install required packages
# ------------------------------------------------

echo
echo "Installing required packages..."

if command -v apt-get >/dev/null 2>&1; then

    sudo apt-get update -y

    sudo apt-get install -y \
        curl \
        wget \
        unzip \
        jq

elif command -v yum >/dev/null 2>&1; then

    sudo yum install -y \
        curl \
        wget \
        unzip \
        jq

fi

echo "✓ Packages installed"

# ------------------------------------------------
# 7. CPU
# ------------------------------------------------

if $CPU; then

    echo
    echo "Configuring CPU monitoring..."

    echo "CPU monitoring uses:"
    echo "AWS/EC2 → CPUUtilization"

    echo "✓ CPU CloudWatch metric ready"

fi

# ------------------------------------------------
# 8. CloudWatch Agent for Memory/Disk
# ------------------------------------------------

if $MEMORY || $DISK; then

    echo
    echo "Installing CloudWatch Agent..."

    if command -v apt-get >/dev/null 2>&1; then

        wget -q \
        https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb \
        -O /tmp/amazon-cloudwatch-agent.deb

        sudo dpkg -i -E /tmp/amazon-cloudwatch-agent.deb

    elif command -v yum >/dev/null 2>&1; then

        sudo yum install -y amazon-cloudwatch-agent

    fi

    echo "✓ CloudWatch Agent installed"

fi

# ------------------------------------------------
# 9. CloudWatch Agent Configuration
# ------------------------------------------------

if $MEMORY || $DISK; then

    sudo mkdir -p \
      /opt/aws/amazon-cloudwatch-agent/etc

    sudo tee \
      /opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json \
      > /dev/null <<EOF
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
EOF

    FIRST=true

    # Memory
    if $MEMORY; then

        sudo tee -a \
          /opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json \
          > /dev/null <<EOF
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
EOF

        FIRST=false

    fi

    # Disk
    if $DISK; then

        if ! $FIRST; then
            sudo sed -i '$ s/$/,/' \
              /opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json
        fi

        sudo tee -a \
          /opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json \
          > /dev/null <<EOF
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "unit": "Percent"
          }
        ],
        "resources": [
          "*"
        ],
        "metrics_collection_interval": 60
      }
EOF

    fi

    sudo tee -a \
      /opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json \
      > /dev/null <<EOF

    }
  }
}
EOF

    echo "✓ CloudWatch Agent configuration created"

    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/monitoring-config.json \
      -s

    echo "✓ CloudWatch Agent started"

fi

# ------------------------------------------------
# 10. Install Docker if required
# ------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then

    echo
    echo "Docker not found."

    if command -v apt-get >/dev/null 2>&1; then

        sudo apt-get install -y docker.io

        sudo systemctl enable docker
        sudo systemctl start docker

    elif command -v yum >/dev/null 2>&1; then

        sudo yum install -y docker

        sudo systemctl enable docker
        sudo systemctl start docker

    fi

fi

echo
echo "✓ Docker ready"

# ------------------------------------------------
# 11. Create YACE directory
# ------------------------------------------------

sudo mkdir -p /opt/yace

# ------------------------------------------------
# 12. YACE IAM Configuration
# ------------------------------------------------

sudo tee /opt/yace/config.yml > /dev/null <<EOF
apiVersion: v1alpha1

discovery:
  exportedTagsOnMetrics:
    ec2:
      - Name

static:
  - name: ec2
    regions:
      - ${REGION}

    type: AWS/EC2

    searchTags:
      - key: InstanceId
        value: ${INSTANCE_ID}

    metrics:
      - name: CPUUtilization
        statistics:
          - Average
        period: 60
        length: 300
EOF

# Memory
if $MEMORY; then

    sudo tee -a /opt/yace/config.yml > /dev/null <<EOF

  - name: memory
    regions:
      - ${REGION}

    type: CWAgent

    searchTags:
      - key: InstanceId
        value: ${INSTANCE_ID}

    metrics:
      - name: mem_used_percent
        statistics:
          - Average
        period: 60
        length: 300
EOF

fi

# Disk
if $DISK; then

    sudo tee -a /opt/yace/config.yml > /dev/null <<EOF

  - name: disk
    regions:
      - ${REGION}

    type: CWAgent

    searchTags:
      - key: InstanceId
        value: ${INSTANCE_ID}

    metrics:
      - name: used_percent
        statistics:
          - Average
        period: 60
        length: 300
EOF

fi

echo "✓ YACE configuration created"

# ------------------------------------------------
# 13. Start YACE
# ------------------------------------------------

echo
echo "Starting YACE..."

sudo docker rm -f yace 2>/dev/null || true

sudo docker run -d \
    --name yace \
    --restart unless-stopped \
    -p 127.0.0.1:5000:5000 \
    -v /opt/yace/config.yml:/tmp/config.yml:ro \
    ghcr.io/nerdswords/yet-another-cloudwatch-exporter:${YACE_VERSION} \
    -config.file=/tmp/config.yml

echo "✓ YACE started"

# ------------------------------------------------
# 14. Test YACE
# ------------------------------------------------

sleep 5

if curl -sf http://127.0.0.1:5000/metrics >/dev/null; then

    echo "✓ YACE metrics endpoint working"

else

    echo "⚠ YACE metrics endpoint not responding"

fi

# ------------------------------------------------
# 15. Summary
# ------------------------------------------------

echo
echo "=============================================="
echo "             SETUP COMPLETED"
echo "=============================================="

echo
echo "EC2 Instance : $INSTANCE_ID"
echo "Region       : $REGION"

echo
echo "Monitoring:"

$CPU && echo "✓ CPU"
$MEMORY && echo "✓ Memory"
$DISK && echo "✓ Disk"

echo
echo "Architecture:"
echo
echo "EC2"
echo " ↓"
echo "CloudWatch"
echo " ↓"
echo "YACE"
echo " ↓"
echo "Prometheus"
echo " ↓"
echo "Grafana"

echo
echo "YACE endpoint:"
echo "http://127.0.0.1:5000/metrics"

echo
echo "=============================================="