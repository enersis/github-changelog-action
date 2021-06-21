#!/bin/bash

set -o pipefail


# config
MAXENTRYS=${INPUT_MAX_JIRA_ENTRYS:-10000}
JIRA_PROJECTS=${INPUT_JIRA_PROJECTS:-ABC,XYZ}
REQ_HOST=${INPUT_JIRA_HOST:-company.atlassian.net}
GIT_RANGE_FROM=${INPUT_GIT_RANGE_FROM:-origin/develop}
GIT_RANGE_TO=${INPUT_GIT_RANGE_TO:-origin/master}
DRY_RUN=${INPUT_DRY_RUN:-false}
USER_TOKEN=${INPUT_USER_TOKEN:-user.name#org.tld:1234567890123}
WEBHOOK_URL=${INPUT_WEBHOOK_URL:-https://outlook.office.com/webhook/some-id}

# Changelog persistance to MS Teams
TITLE=$(git config --local remote.origin.url)
COLOR='ff0000'

cd ${GITHUB_WORKSPACE}/${source}

echo -e "\t*** CONFIGURATION ***"
echo -e "\tmax_jira_entrys: ${MAXENTRYS}"
echo -e "\tjira_projects: ${JIRA_PROJECTS}"
echo -e "\tjira_host: ${REQ_HOST}"
echo -e "\tgit_range_from: ${GIT_RANGE_FROM}"
echo -e "\tgit_range_to: ${GIT_RANGE_TO}"
echo -e "\tdry_run: ${DRY_RUN}"
echo -e "\tuser_token: ${USER_TOKEN}"


JIRA_PROJECTS=${JIRA_PROJECTS/ON/'"ON"'}

REQ_URL="http://${REQ_HOST}/rest/api/2/search?jql=project+in($JIRA_PROJECTS)%20and%20issueType%20in%20(bug,%20story)&maxResults=49&fields=id,key,summary&startAt="
echo "Sending Jira Request to: $REQ_URL"

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
GIT_LOG=$(git log --abbrev-commit --pretty=format:"<a href=${TITLE}/commit/%H>%an: (%h) %s</a>" --no-merges "${GIT_RANGE_TO}".."${GIT_RANGE_FROM}" | awk '$0=$0"\r\n"')
GIT_JIRA_COMMITS=$(echo "$GIT_COMMITS"|tr " " "\n"|sort|uniq|tr "\n" " ")
GIT_LAST_AUTHOR=$(git log -1 --pretty=format:'%an')
GIT_LAST_TAG=$(git describe --tags --abbrev=0)

echo -e "git commit and Jira informations:"
echo -e "*********************************"
echo -e "GIT_COMMITS: $GIT_COMMITS"
echo -e "GIT_LOG: $GIT_LOG"
echo -e "GIT_JIRA_COMMITS: $GIT_JIRA_COMMITS"
echo -e "GIT_LAST_AUTHOR: $GIT_LAST_AUTHOR"
echo -e "GIT_LAST_TAG: $GIT_LAST_TAG"

# Search the found tickets of commits in the summary list
for i in $(echo $GIT_JIRA_COMMITS | sed "s/ / /g"); do SUMMARYLOG="$SUMMARYLOG \n $(grep $i summary.txt)\r\n"; done
SUMMARYLOG="${SUMMARYLOG//\"}"

# Filter Jira-Storys of git commits by existing jira storys
CHANGELOGENTRYS=$(comm -12 <(echo $GIT_JIRA_COMMITS | tr ' ' '\n' | sort) <(echo $TICKETS | tr ' ' '\n' | sort))
CHANGELOGENTRYS=$(sed 's/^/https:\/\/enersis.atlassian.net\/browse\//; s/$//' <(echo "$CHANGELOGENTRYS") | awk '$0="<a href="$0">"$0"</a>\r\n"')

FOUND_ENTRYS=${#GIT_COMMITS} 
echo "Jira entrys found: ${FOUND_ENTRYS}"


# genrate changelog
CHANGELOG=$(cat << EOF
****************CHANGELOG*******************

There are at the moment <b> $MAXENTRYS </b> Storys in the given Project(s).\r\n
The Projects are: <b> $JIRA_PROJECTS </b> \r\n
The last commit has been done by: <b> $GIT_LAST_AUTHOR </b>\r\n
This version is tagged by: <a href=${TITLE}/releases/tag/$GIT_LAST_TAG>$GIT_LAST_TAG</a> \r\n

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

# Use dryrun to determine the changelog
if $DRY_RUN
then
    echo -e "$CHANGELOG"
    exit 0
else
    echo -e "$CHANGELOG"
    echo "Sending information ..."
fi 

if [[ $FOUND_ENTRYS -eq 0 ]]
then
    echo -e "Nothing found ... aborting"
    exit 0
fi 

# Send changelog to NS Teams
curl -H "Content-Type: application/json" -d "${TEAMS_JSON}" "${WEBHOOK_URL}"

# Handle exit status
echo "Finished ..."

echo -e "::set-output name=changelog::${CHANGELOG}"
exit 0
