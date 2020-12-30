FROM node:current-slim

# Install required dependencies
RUN apt-get update
RUN apt-get -y install curl python make g++
RUN apt-get -y install git

WORKDIR /usr/src/app
RUN git clone --depth 1 https://github.com/Azure-Samples/digital-twins-explorer .

WORKDIR client/src
RUN npm install

# prevent stdin to be closed https://github.com/facebook/create-react-app/commit/7e6d6cd05f3054723c8b015c813e13761659759e
ENV CI="true" 

ENV PORT=80

CMD ["npm", "run", "start"]
