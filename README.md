# github-changelog-action action


This action generates a changelog with combined information of commit-tags and Jira Storys.

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

## Example usage

uses: enersis/github-changelog-action@master
with:
  max_jira_entrys: '10000'