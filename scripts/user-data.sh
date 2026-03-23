#!/bin/bash

yum update -y
amazon-linux-extras install nginx1 -y

systemctl start nginx
systemctl enable nginx

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

echo "<h1>Chisom from $INSTANCE_ID</h1>" > /usr/share/nginx/html/index.html