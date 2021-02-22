#!/bin/bash

set -o pipefail


# config
MAXENTRYS=${INPUT_MAX_JIRA_ENTRYS:-10000}
JIRA_PROJECTS=${env.JIRA_PROJECTS:-ABC,XYZ}
REQ_HOST=${env.JIRA_HOST:-enersis.atlassian.net}
GIT_RANGE_FROM=${env.GIT_RANGE_FROM:-origin/develop}
GIT_RANGE_TO=${env.GIT_RANGE_TO:-origin/master}
DRY_RUN=${env.DRY_RUN:-false}
USER_TOKEN=${env.USER_TOKEN:-user.name#org.tld:1234567890123}
WEBHOOK_URL=${env.WEBHOOK_URL:-https://outlook.office.com/webhook/some-id}

#cd ${GITHUB_WORKSPACE}/${source}

echo -e "\t*** CONFIGURATION ***"
echo -e "\tmax_jira_entrys: ${MAXENTRYS}"
echo -e "\tjira_projects: ${JIRA_PROJECTS}"
echo -e "\tjira_host: ${REQ_HOST}"
echo -e "\tgit_range_from: ${GIT_RANGE_FROM}"
echo -e "\tgit_range_to: ${GIT_RANGE_TO}"
echo -e "\tdry_run: ${DRY_RUN}"
echo -e "\tuser_token: ${USER_TOKEN}"

REQ_URL="http://${REQ_HOST}/rest/api/2/search?jql=project+in($JIRA_PROJECTS)%20and%20status%20!=%20Done&maxResults=49&fields=id,key,summary&startAt="
# Changelog persistance to MS Teams
TITLE=$(basename `git rev-parse --show-toplevel`)
COLOR='ff0000'

# Determine how many Storys are found under the given projects
if curl --silent -L -u "$USER_TOKEN" -X GET -H "Content-Type: application/json" -o maxentrys.json "${REQ_URL}10000"; then
    MAXENTRYS=$(jq -r '.total' maxentrys.json)
    echo -e "\tStorys found in jira board(s): $MAXENTRYS \n"
else
    printf 'Curl for total failed with error code "%d" (check the manual)\n' "$?" >&2
    exit 1
fi

# Paging throu the Jira API (REQ_URL) to find all Storys fitting the given filter
x=0
while [ $x -le $(( $MAXENTRYS - 50 )) ]; do
    if curl --silent -L -u "$USER_TOKEN" -X GET -H "Content-Type: application/json" -o output.json "${REQ_URL}${x}"; then
        TICKETS="$TICKETS $(jq -r '.issues[] | .key' output.json)"
        SUMMARY="$SUMMARY $(jq -r '.issues[] | "\(.key)\t\(.fields.summary)"' output.json)"
        SUMMARY="\n$SUMMARY"
    else
        printf 'Curl failed with error code "%d" (check the manual)\n' "$?" >&2
        exit 1
    fi

x=$(( $x + 50 ))
done
echo "$SUMMARY" > summary.txt

# Read the git commits from log and find Jira issues in the title-line
GIT_COMMITS=$(git log --pretty=oneline "${GIT_RANGE_TO}".."${GIT_RANGE_FROM}" | grep -e '[A-Z|0-9]\+-[0-9]\+' -o | sort -u)
GIT_LOG=$(git log --pretty=oneline --no-merges "${GIT_RANGE_TO}".."${GIT_RANGE_FROM}" | awk '$0=$0"\r\n"')
GIT_JIRA_COMMITS=$(echo "$GIT_COMMITS"|tr " " "\n"|sort|uniq|tr "\n" " ")

# Search the found tickets of commits in the summary list
for i in $(echo $GIT_JIRA_COMMITS | sed "s/ / /g"); do SUMMARYLOG="$SUMMARYLOG \n $(grep $i summary.txt)\r\n"; done

# Filter Jira-Storys of git commits by existing jira storys
CHANGELOGENTRYS=$(comm -12 <(echo $GIT_JIRA_COMMITS | tr ' ' '\n' | sort) <(echo $TICKETS | tr ' ' '\n' | sort))
CHANGELOGENTRYS=$(sed 's/^/https:\/\/enersis.atlassian.net\/browse\//; s/$//' <(echo "$CHANGELOGENTRYS") | awk '$0="<a href="$0">"$0"</a>\r\n"')

# genrate changelog
CHANGELOG=$(cat << EOF
****************CHANGELOG*******************

There are at the moment $MAXENTRYS Storys in the given Project(s).
The Projects are: $JIRA_PROJECTS

********************
**Edited JIRA Storys in this Repository:**\r\n
$CHANGELOGENTRYS

********************
**Summary of the edited Story(s):**
$SUMMARYLOG

*******
**Commits:**\r\n
$GIT_LOG

*********************
**Settings for this log:**\r\n
analysed jira entrys: ${MAXENTRYS} \r\n
jira_ rojects: ${JIRA_PROJECTS} \r\n
jira host: ${REQ_HOST} \r\n
git range from: ${GIT_RANGE_FROM} \r\n
git range to: ${GIT_RANGE_TO} \r\n
dry_run: ${DRY_RUN} \r\n
EOF
)

# Use dryrun to determine the changelog
if $DRY_RUN
then
    echo -e "$CHANGELOG"
    exit 0
else
    echo -e "$CHANGELOG"
    echo "Sending information ..."
fi 

TEAMS_JSON=$(cat << EOF
{
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Changelog notification",
        "themeColor": "0072C6",
        "title": "Changelog notification for ${TITLE}",
         "sections": [
            {
            
                "facts": [
                    {
                        "name": "Servicename:",
                        "value": "${TITLE}"
                    },
                    {
                        "name": "Description:",
                        "value": "${CHANGELOG}"
                    }
                ],
                "text": "Following you'll find the changelog of the mentioned service",
                "markdown": true
            }
        ]
    }
EOF
)

curl -H "Content-Type: application/json" -d "${TEAMS_JSON}" "${WEBHOOK_URL}"

# Handle exit status
echo "Finished ..."

echo "::set-output name=changelog::${CHANGELOG}"
exit 0