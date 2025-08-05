#!/bin/bash
yum update -y
yum install -y httpd

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Wait for volume to be available and attach it
sleep 30

# Check if volume is already attached
if ! lsblk | grep -q nvme1n1; then
    # Attach the EBS volume
    aws ec2 attach-volume --volume-id ${volume_id} --instance-id $INSTANCE_ID --device /dev/sdf --region $REGION
    
    # Wait for attachment
    sleep 30
fi

# Check if the volume needs formatting
if ! file -s /dev/nvme1n1 | grep -q ext4; then
    # Format the volume if it's not already formatted
    mkfs -t ext4 /dev/nvme1n1
fi

# Create mount point and mount the volume
mkdir -p /var/www/html
mount /dev/nvme1n1 /var/www/html

# Add to fstab for persistent mounting
echo '/dev/nvme1n1 /var/www/html ext4 defaults,nofail 0 2' >> /etc/fstab

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create a simple index.html if it doesn't exist
if [ ! -f /var/www/html/index.html ]; then
    cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Jared Wallace's Website</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .info { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Welcome to Jared Wallace's Website</h1>
    <div class="info">
        <p>This is a highly available web server running on AWS.</p>
        <p>Instance ID: $INSTANCE_ID</p>
        <p>Region: $REGION</p>
        <p>Persistent storage is mounted and ready!</p>
    </div>
</body>
</html>
EOF
fi

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure Apache to start after mounting
cat <<EOF > /etc/systemd/system/httpd-after-mount.service
[Unit]
Description=Apache HTTP Server (after mount)
After=var-www-html.mount
Requires=var-www-html.mount

[Service]
Type=notify
ExecStart=/usr/sbin/httpd -D FOREGROUND
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable httpd-after-mount.service
