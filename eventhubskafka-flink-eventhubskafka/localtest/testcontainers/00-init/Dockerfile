FROM confluentinc/cp-kafka-connect

RUN apt-get update && apt-get install -y telnet

WORKDIR /workdir

ADD *.sh /workdir/

ENTRYPOINT ["init"]
