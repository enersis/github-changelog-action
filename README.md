# github-changelog-action action


This action generates a changelog with combined information of commit-tags and Jira Storys.
It reads the commit logs and searches them for possible Jira tickets aka `[ABC-123]`.
The given SJira-Storys from the commits are then taken to search in the list of Jira Storys at attlasian.
Out of this a changelog is generated with Jira, Storys as Link, the Story Titles and commits.
This Changelog is then sended to a MS Teams Webhook.

## Inputs

### `max_jira_entrys`

**Not Required** Maximum amount of Jira Storys to read. Default `10000`.

### `jira_projects`

**Not Required** The Jira Project tags. Default `ABC,XYZ`.

### `jira_host`

**Not Required** The Jira host. Default `enersis.atlassian.net`.

### `git_range_from`

**Not Required** The branch to start a range compare. Default `origin/develop`.

### `git_range_to`

**Not Required** The branch to end a range compare. Default `origin/master`.

### `dry_run`

**Not Required** If the changelog shall be sended. Default `false`.

### `user_token`

**Required** Your Jira Token ex user.name#org.tld:1234567890123 generated there. Default `user.name#org.tld:1234567890123`.

### `webhook_url`

**Not Required** MS Teams webhook url generated there. Default `https://outlook.office.com/webhook/some-id`.

## Outputs

### `changelog`

The changelog

## Usage

```yaml
name: Write changelog
on:
  push:
      branches:
        - master

jobs:
  generate_changelog_master:
    runs-on: ubuntu-latest
    name: Changelog
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          # Fetch all history for all tags and branches
          fetch-depth: 0
      - run: git fetch --all

      - name: Changelog
        id: changelog
        uses: enersis/github-changelog-action@master
        with:
          MAX_JIRA_ENTRYS: 9000
          JIRA_PROJECTS: 'XYZ'
          JIRA_HOST : 'yourcompany.atlassian.net'
          GIT_RANGE_FROM: 'origin/develop'
          GIT_RANGE_TO: 'origin/master'
          USER_TOKEN: ${{ secrets.YOUR_JIRA_TOKEN_STORED_AS_SECRET }}
          WEBHOOK_URL: ${{ secrets.YOUR_TEAMS_WEBHOOK_STORED_AS_SECRET }}

```