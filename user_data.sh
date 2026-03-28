#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== Bootstrap started $(date) ==="

# --- System packages ---
yum update -y
yum install -y docker git

systemctl enable docker
systemctl start docker

# Docker Buildx + Compose plugins (ARM64)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/buildx/releases/download/v0.24.0/buildx-v0.24.0.linux-arm64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx \
         /usr/local/lib/docker/cli-plugins/docker-compose

# --- Instance metadata (IMDSv2) ---
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

# --- EBS volume ---
echo "Attaching EBS volume ${volume_id}..."
sleep 10

if ! lsblk | grep -q nvme1n1; then
    aws ec2 attach-volume \
      --volume-id "${volume_id}" \
      --instance-id "$INSTANCE_ID" \
      --device /dev/sdf \
      --region "$REGION"

    for i in $(seq 1 30); do
        lsblk | grep -q nvme1n1 && break
        echo "Waiting for volume device... ($i/30)"
        sleep 5
    done
fi

if ! blkid /dev/nvme1n1 | grep -q ext4; then
    mkfs -t ext4 /dev/nvme1n1
fi

mkdir -p /var/www/html
mount /dev/nvme1n1 /var/www/html
grep -q '/var/www/html' /etc/fstab || \
  echo '/dev/nvme1n1 /var/www/html ext4 defaults,nofail 0 2' >> /etc/fstab

# --- App directories ---
mkdir -p /var/www/html/{pgdata,images,app}
chown 999:999 /var/www/html/pgdata

# --- Pull config from SSM Parameter Store ---
echo "Fetching configuration from SSM..."
SSM_PREFIX="${ssm_prefix}"

get_param() {
    aws ssm get-parameter \
      --name "$SSM_PREFIX/$1" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text \
      --region "$REGION"
}

DB_USER=$(get_param db_user)
DB_PASS=$(get_param db_password)
DB_NAME=$(get_param db_name)
ADMIN_EMAIL=$(get_param admin_email)
ADMIN_PW_HASH=$(get_param admin_password_hash)
SESSION_SECRET=$(get_param session_secret)
API_TOKEN=$(get_param api_token)

cat > /var/www/html/.env <<ENVEOF
DATABASE_URL=postgres://$DB_USER:$DB_PASS@postgres:5432/$DB_NAME?sslmode=disable
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD_HASH=$ADMIN_PW_HASH
PORT=8080
APP_ENV=production
ADMIN_HOST=${admin_host}
SESSION_SECRET=$SESSION_SECRET
API_TOKEN=$API_TOKEN
IMAGE_DIR=/var/www/html/images
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=$DB_NAME
ENVEOF

chmod 600 /var/www/html/.env

# --- Deploy application ---
echo "Deploying application..."
if [ -d /var/www/html/app/.git ]; then
    cd /var/www/html/app
    git pull
else
    git clone ${github_repo} /var/www/html/app
fi

cd /var/www/html/app
docker compose up -d --build

echo "=== Bootstrap complete $(date) ==="
