#! /usr/bin/env bash

set -e

echo "proxy_connect_timeout       600;" > /etc/nginx/conf.d/timeouts.conf
echo "proxy_send_timeout          600;" >> /etc/nginx/conf.d/timeouts.conf
echo "proxy_read_timeout          600;" >> /etc/nginx/conf.d/timeouts.conf
echo "send_timeout                600;" >> /etc/nginx/conf.d/timeouts.conf


# rebuild the /etc/nginx/conf.d/nginx.conf to allow CORS
# Get the URL for static files from the environment variable
USE_STATIC_URL=${STATIC_URL:-'/static'}
# Get the absolute path of the static files from the environment variable
USE_STATIC_PATH=${STATIC_PATH:-'/app/static'}
# Get the listen port for Nginx, default to 80
USE_LISTEN_PORT=${LISTEN_PORT:-80}

if [[ $ENVIRONMENT == "dev" ]] ; then
  SERVER_NAME=localhost:8000
fi

# Generate Nginx config first part using the environment variables
echo "server {
    listen ${USE_LISTEN_PORT};
    server_name ${SERVER_NAME};
    location / {
        try_files \$uri @app;
    }
    location @app {
        include uwsgi_params;
        uwsgi_pass unix:///tmp/uwsgi.sock;
    }
    location $USE_STATIC_URL {
        alias $USE_STATIC_PATH;
    }" > /etc/nginx/conf.d/nginx.conf

# If STATIC_INDEX is 1, serve / with /static/index.html directly (or the static URL configured)
if [[ $STATIC_INDEX == 1 ]] ; then
echo "    location = / {
        index $USE_STATIC_URL/index.html;
    }" >> /etc/nginx/conf.d/nginx.conf
fi

# allow cross origin on '/caterise'
cat /app/nginx_cors.conf >> /etc/nginx/conf.d/nginx.conf

# Finish the Nginx config file
echo "}" >> /etc/nginx/conf.d/nginx.conf
