#! /usr/bin/env bash

set -e

echo "proxy_connect_timeout       600;" > /etc/nginx/conf.d/timeouts.conf
echo "proxy_send_timeout          600;" >> /etc/nginx/conf.d/timeouts.conf
echo "proxy_read_timeout          600;" >> /etc/nginx/conf.d/timeouts.conf
echo "send_timeout                600;" >> /etc/nginx/conf.d/timeouts.conf
