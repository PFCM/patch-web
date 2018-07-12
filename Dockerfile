FROM tiangolo/uwsgi-nginx-flask:python3.6

RUN apt-get -qq -y update > /dev/null
RUN apt-get -qq -y install git > /dev/null

COPY ./requirements.txt requirements.txt
RUN pip -q install -r requirements.txt
RUN rm requirements.txt
COPY ./patchserver /app
COPY ./static /app/static
ENV STATIC_INDEX 1
