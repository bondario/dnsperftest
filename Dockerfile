FROM alpine:latest
RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk update \
    && apk --no-cache add bash bc drill datamash@testing
COPY ./dnstest.sh /dnstest.sh

ENTRYPOINT ["/bin/bash", "/dnstest.sh"]
