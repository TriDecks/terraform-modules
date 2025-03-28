#!/bin/bash
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-linux

# Set up container storage monitoring
cat <<'EOF' > /etc/cloudwatch-agent-config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "ECS/ContainerInsights",
    "metrics_collected": {
      "disk": {
        "resources": [
          "/",
          "/var/lib/docker"
        ],
        "measurement": [
          {"name": "free", "unit": "Gigabytes"},
          {"name": "used", "unit": "Gigabytes"},
          {"name": "total", "unit": "Gigabytes"},
          {"name": "used_percent", "unit": "Percent"}
        ]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used", "unit": "Megabytes"},
          {"name": "mem_total", "unit": "Megabytes"},
          {"name": "mem_used_percent", "unit": "Percent"}
        ]
      },
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "unit": "Percent"},
          {"name": "cpu_usage_user", "unit": "Percent"},
          {"name": "cpu_usage_system", "unit": "Percent"}
        ],
        "totalcpu": true
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/ecs/ecs-agent.log",
            "log_group_name": "/var/log/ecs/ecs-agent.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/ecs/ecs-init.log",
            "log_group_name": "/var/log/ecs/ecs-init.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/docker",
            "log_group_name": "/var/log/docker",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/var/log/messages",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent with configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/etc/cloudwatch-agent-config.json

# Enable SSM agent for remote management
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent