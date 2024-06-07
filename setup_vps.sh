#!/bin/bash

# Step 1: Setup SSH Key for Root User
echo "Starting SSH key setup..."

read -p "Choose an option (1: Input SSH public key, 2: Use default public key): " option
option=${option:-2}
case $option in
    1)
        read -p "Enter your SSH public key: " user_key
        ssh_key=$user_key
        ;;
    2|*)
        ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0j4PTgKgnLmK/IV/oXkpWJomlkE9X7x9M6O4JExkTWJsZNG0SBma2bpW39ronv6jx+TIVkeWpIEjNkwwPRcnDrmekmtu1Hsi9jFgK7R8WmpeX2U6l6ieBnomyH8HBSNNWRCHF62EzaJ1LLN6FpuJ4x6h3S2bAqePLYvtwvV2/v+XeR8Samh3lLMvW0b3oq8PpvNMUHZkwlPcGUxt9enJaNLFEP/8+g7pAbN2bn4T5ax0+au75svpoavzeZtS3QS0oNYJ1DZQ6eNzrQszB9uhNJfb+oupuQoGhMR61dEV0fF+gpjTuukmB8XLM9IsmhkVflyg4w5L/ArCHR+5hXjrXL+qjN8wXL22zb+IwYQQT684JXzpOBx+GFV9iCR02MAVIrb6oEHT4eZWuXM9fID+KyJd9aOlBxpEvHQAL/HIX3+z2Pa9TsjR3BKEGwrgmv6wIe44npi36M7BmyOjBTAgiH9TDEQeT68A3rjcgtJiPv1CjLnVu5mgxAgUZ0EUvjIc= zhang tianyi@Color"
        ;;
esac

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$ssh_key" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "SSH key setup complete."

# Step 2: Configure SSH to disable password authentication and enable key-based authentication
echo "Configuring SSH..."
sed -i 's/#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#\?PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "Restarting SSHD..."
systemctl restart sshd
echo "SSH configuration complete."

# Install ufw and add SSH port
if ! command -v ufw &> /dev/null; then
    echo "ufw could not be found, attempting to install..."
    apt update && apt install ufw -y
fi
if ! command -v curl &> /dev/null; then
    echo "curl could not be found, attempting to install..."
    apt update && apt install curl -y
fi
ufw allow http
ufw allow https

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_PORT=$(grep -E "^#?Port " $SSH_CONFIG | awk '{print $2}')
if [ -n "$SSH_PORT" ]; then
    echo "Allowing SSH access on port $SSH_PORT..."
    sudo ufw allow $SSH_PORT/tcp
else
    echo "No SSH port found in $SSH_CONFIG, using default port 22."
    sudo ufw allow 22/tcp
fi
ufw enable

# Step 3: Create /root/ssl folder and setup a cron job for SSL certificate update
echo "Setting up SSL certificate update..."
mkdir -p /root/ssl
(crontab -l 2>/dev/null; echo "0 0 * * 0 cd /root/ssl && rm -rf cert* && wget ssl.colorduck.me/cert.tar.gz && tar -zxf cert.tar.gz") | crontab -
cd /root/ssl && rm -rf cert* && wget ssl.colorduck.me/cert.tar.gz && tar -zxf cert.tar.gz
echo "SSL certificate setup complete."

echo "All tasks completed successfully."
