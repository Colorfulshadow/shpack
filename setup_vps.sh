#!/bin/bash

# Step 1: Setup SSH Key for Root User
echo "Starting SSH key setup..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0j4PTgKgnLmK/IV/oXkpWJomlkE9X7x9M6O4JExkTWJsZNG0SBma2bpW39ronv6jx+TIVkeWpIEjNkwwPRcnDrmekmtu1Hsi9jFgK7R8WmpeX2U6l6ieBnomyH8HBSNNWRCHF62EzaJ1LLN6FpuJ4x6h3S2bAqePLYvtwvV2/v+XeR8Samh3lLMvW0b3oq8PpvNMUHZkwlPcGUxt9enJaNLFEP/8+g7pAbN2bn4T5ax0+au75svpoavzeZtS3QS0oNYJ1DZQ6eNzrQszB9uhNJfb+oupuQoGhMR61dEV0fF+gpjTuukmB8XLM9IsmhkVflyg4w5L/ArCHR+5hXjrXL+qjN8wXL22zb+IwYQQT684JXzpOBx+GFV9iCR02MAVIrb6oEHT4eZWuXM9fID+KyJd9aOlBxpEvHQAL/HIX3+z2Pa9TsjR3BKEGwrgmv6wIe44npi36M7BmyOjBTAgiH9TDEQeT68A3rjcgtJiPv1CjLnVu5mgxAgUZ0EUvjIc= zhang tianyi@Color" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "SSH key setup complete."

# Step 2: Configure SSH to disable password authentication and enable key-based authentication
echo "Configuring SSH..."
sed -i 's/#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#\?PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "Restarting SSHD..."
systemctl restart sshd
echo "SSH configuration complete."

# install ufw and add ssh port
if ! command -v ufw &> /dev/null; then
    echo "ufw could not be found, attempting to install..."
    apt update && apt install ufw -y
fi
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# Step 3: Create /root/ssl folder and setup a cron job for SSL certificate update
echo "Setting up SSL certificate update..."
mkdir -p /root/ssl
(crontab -l 2>/dev/null; echo "0 0 * * 0 cd /root/ssl && rm -rf cert* && wget ssl.colorduck.me/cert.tar.gz && tar -zxf cert.tar.gz") | crontab -
cd /root/ssl && rm -rf cert* && wget ssl.colorduck.me/cert.tar.gz && tar -zxf cert.tar.gz
echo "SSL certificate setup complete."

echo "All tasks completed successfully."