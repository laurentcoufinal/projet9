FROM python:3.12-alpine

RUN apk add --no-cache curl bash ca-certificates \
  && curl -fsSL "https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64" \
    -o /usr/local/bin/supercronic \
  && chmod +x /usr/local/bin/supercronic

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
