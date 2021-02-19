FROM alpine
LABEL "repository"="https://github.com/enersis/github-changelog-action"
LABEL "homepage"="https://github.com/enersis/github-changelog-action"
LABEL "maintainer"="MansurEsm"

COPY entrypoint.sh /entrypoint.sh

RUN apk update && apk add bash git curl jq

ENTRYPOINT ["sh", "/entrypoint.sh"]
