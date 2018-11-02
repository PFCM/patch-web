# FOR DEVELOPMENT ONLY
FROM node:latest

MAINTAINER pfcm <pfcmathews@gmail.com>

COPY ./ /app
WORKDIR /app
RUN npm install

ENTRYPOINT ["npm", "run", "start"]
