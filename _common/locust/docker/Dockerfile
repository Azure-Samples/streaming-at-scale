FROM python:3.6.8-alpine3.9

RUN apk add --no-cache --virtual=build-dep build-base && \
    apk add --no-cache zeromq-dev && \
    pip install --no-cache-dir locustio && \
    apk del build-dep

WORKDIR /locust

EXPOSE 8089 5557 5558

ENTRYPOINT ["/usr/bin/locust"]