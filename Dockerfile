FROM alpine
LABEL "repository"="https://github.com/enersis/github-changelog-action"
LABEL "homepage"="https://github.com/enersis/github-changelog-action"
LABEL "maintainer"="MansurEsm"

COPY entrypoint.sh /entrypoint.sh
# The Dockerfile needs to be run in bash so permission needs to be fixed
# This is because we use in the shell scrupt process substitution
RUN ["chmod", "+x", "entrypoint.sh"]

RUN apk update && apk add bash git curl jq

ENTRYPOINT ["/bin/bash", "-c", "/entrypoint.sh"]
