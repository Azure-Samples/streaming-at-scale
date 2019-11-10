FROM alpine:3.7

RUN set -x \
	&& apk add --no-cache \
		curl jq

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
