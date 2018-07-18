FROM tiangolo/uwsgi-nginx-flask:python3.6

# install requirements
RUN apt-get -qq -y update > /dev/null
RUN apt-get -qq -y install git > /dev/null

COPY ./requirements.txt requirements.txt
RUN pip -q install pybind11 numpy
RUN pip install -r requirements.txt
RUN rm requirements.txt

# get the app in the right place for nginx and uwsgi
COPY ./patchserver /app
COPY ./static /app/static
COPY ./uwsgi.ini /app/uwsgi.ini

# environment variables for prod
ENV STATIC_INDEX 1
ENV NGINX_MAX_UPLOAD 12m
ENV NGINX_WORKER_PROCESES auto
ENV NGINX_WORKER_CONNECTIONS 512

ENV CATS_PATH /cats/raw
ENV INDEX_PATH /cats/indices
ENV LEVELS 2,4,8,16,32
