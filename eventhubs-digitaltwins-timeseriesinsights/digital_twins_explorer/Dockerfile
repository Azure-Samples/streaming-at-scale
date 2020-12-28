FROM node:current-slim

# Install required dependencies
RUN apt-get update
RUN apt-get -y install curl python make g++
RUN apt-get -y install git

WORKDIR /usr/src/app
RUN git clone --depth 1 https://github.com/Azure-Samples/digital-twins-explorer .

WORKDIR client/src
RUN npm install
RUN printf "#!/bin/sh\nnpm run start" > startup.sh
RUN chmod 0755 startup.sh
RUN printf "#!/bin/sh\nsleep infinity" > sleep.sh
RUN chmod 0755 sleep.sh

ENV PORT=80

#ENTRYPOINT ["./startup.sh"]
ENTRYPOINT ["./sleep.sh"]
