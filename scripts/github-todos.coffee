# Configuration:
#   HUBOT_GITHUB_TODOS_PRIMARY_REPO
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER_<NAME>
#   HUBOT_GITHUB_USER_<NAME>_TOKEN
#
# Notes:
#   HUBOT_GITHUB_TODOS_PRIMARY_REPO = 'username/reponame'
#   HUBOT_GITHUB_TOKEN = oauth token (we use a "dobthubot" github account)
#   HUBOT_GITHUB_USER_ADAM = 'adamjacobbecker'
#   HUBOT_GITHUB_USER_ADAM_TOKEN = adamjacobbecker's oauth token
##
#   You'll need to create UPCOMING_LABEL, SHELF_LABEL, and CURRENT_LABEL labels.
#
# Commands:
#   hubot add task <text> #todos
#   hubot ask <user|everyone> to <text> #todos
#   hubot assign <id> to <user> #todos
#   hubot assign <user> to <id> #todos
#   hubot finish <id> #todos
#   hubot finish <id> <text> #todos
#   hubot i'll work on <id> #todos
#   hubot move <id> to <current|upcoming|shelf> #todos
#   hubot what am i working on #todos
#   hubot what's <user|everyone> working on #todos
#   hubot what's next #todos
#   hubot what's next for <user|everyone> #todos
#   hubot what's on <user|everyone>'s shelf #todos
#   hubot what's on my shelf #todos
#   hubot work on <id> #todos
#   hubot work on <repo>#<id> #todos
#   hubot work on <text> #todos
#
# License:
#   MIT

_  = require 'underscore'
_s = require 'underscore.string'
async = require 'async'
moment = require 'moment'

SHELF_LABEL = 'hold'
UPCOMING_LABEL = 'todo_upcoming'
CURRENT_LABEL = 'todo_current'
TRASH_COMMANDS = ['done', 'trash']

emojiMap = [
  ['est_1', 'one']
  ['est_2', 'two']
  ['est_3', 'three']
  ['est_4', 'four']
  ['est_5', 'five']
  ['est_6', 'six']
  ['est_7', 'seven']
  ['est_8', 'eight']
  ['bug', 'spider']
]

labelNameMaps =
  shelf: SHELF_LABEL
  upcoming: UPCOMING_LABEL
  current: CURRENT_LABEL

log = (msgs...) ->
  console.log(msgs)

handleError = (err, msg) ->
  log(err)
  msg.send "An error occurred: #{err}"

wrapErrorHandler = (msg) ->
  (response) ->
    handleError(response.error, msg)

doubleUnquote = (x) ->
  _s.unquote(_s.unquote(x), "'")
    .replace(/^“/, '')
    .replace(/”$/, '')
    .replace(/^“/, '')
    .replace(/^‘/, '')
    .replace(/’$/, '')

class GithubTodosSender

  @ISSUE_BODY_SEPARATOR = ' body:'

  constructor: (robot) ->
    @robot = robot
    @github = require("githubot")(@robot)
    @primaryRepo = process.env['HUBOT_GITHUB_TODOS_PRIMARY_REPO'] || '' # for tests
    @org = @primaryRepo.split('/')[0]

  parseIssueString: (str) ->
    if str.match(/\S+\#\d+/)
      {
        repo: "#{@org}/#{str.split('#')[0]}"
        id: str.split('#')[1]
      }
    else
      {
        repo: @primaryRepo
        id: str.trim().replace('#', '')
      }

  getGithubUser: (userName) ->
    log "Getting GitHub username for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}"]

  getGithubToken: (userName) ->
    log "Getting GitHub token for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}_TOKEN"]

  optionsFor: (msg, userName) ->
    options = {}

    if userName != false && (x = @getGithubToken(userName || msg.message.user.name))
      options.token = x

    options.errorHandler = wrapErrorHandler(msg)

    options

  getIssueText: (issueObject, opts = {}) ->
    str = "#{opts.prefix || ''}"

    if opts.includeAssignee
      str += "@#{issueObject.assignee?.login}: "

    str += "<#{issueObject.html_url}|#{issueObject.url.split('repos/')[1].split('/issues')[0]}##{issueObject.number}> - #{issueObject.title}"

    labelNames = _.pluck issueObject.labels, 'name'

    # Add emoji
    _.each emojiMap, (x) ->
      if x[0] in labelNames
        str += " :#{x[1]}:"

    str

  addIssueEveryone: (msg, issueBody, opts) ->
    userNames = {}

    for k, v of process.env
      if (x = k.match(/^HUBOT_GITHUB_USER_(\S+)$/)?[1]) && (k != "HUBOT_GITHUB_USER_#{msg.message.user.name.split(' ')[0].toUpperCase()}")
        userNames[x] = v unless x.match(/hubot/i) or x.match(/token/i) or (v in _.values(userNames))

    for userName in _.keys(userNames)
      @addIssue(msg, issueBody, userName, opts)

  addIssue: (msg, issueBody, userName, opts = {}) ->
    if userName.toLowerCase() in ['all', 'everyone']
      return @addIssueEveryone(msg, issueBody, opts)

    [title, body] = doubleUnquote(issueBody)
                    .replace(/\"/g, '')
                    .split(GithubTodosSender.ISSUE_BODY_SEPARATOR)

    sendData =
      title: title
      body: body || ''
      assignee: @getGithubUser(userName)
      labels: [opts.label || UPCOMING_LABEL]

    if opts.footer && _.isEmpty(@optionsFor(msg))
      sendData.body += "\n\n(added by #{@getGithubUser(msg.message.user.name) || 'unknown user'}. " +
                   "remember, you'll need to bring them in with an @mention.)"

    log "Adding issue", sendData

    @github.withOptions(@optionsFor(msg)).post "repos/#{@primaryRepo}/issues", sendData, (data) =>
      msg.send @getIssueText(data, prefix: "Added: ")

  moveIssue: (msg, issueId, newLabel, opts = {}) ->
    console.log 'moveIssue', @parseIssueString(issueId), "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}"

    @github.withOptions(errorHandler: wrapErrorHandler(msg)).get "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}", (data) =>
      labelNames = _.pluck(data.labels, 'name')
      labelNames = _.without(labelNames, UPCOMING_LABEL, SHELF_LABEL, CURRENT_LABEL)
      labelNames.push(newLabel.toLowerCase()) unless newLabel in TRASH_COMMANDS

      sendData =
        state: if newLabel in TRASH_COMMANDS then 'closed' else 'open'
        labels: labelNames

      log "Moving issue", sendData

      @github.withOptions(@optionsFor(msg)).patch "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}", sendData, (data) =>
        if newLabel in TRASH_COMMANDS
          msg.send @getIssueText(data, prefix: "Closed: ")
        else if _.find(data.labels, ((l) -> l.name.toLowerCase() == newLabel.toLowerCase()))
          msg.send @getIssueText(data, prefix: "Moved to #{newLabel.toLowerCase()}: ")

  commentOnIssue: (msg, issueId, body, opts = {}) ->
    sendData =
      body: body

    log "Commenting on issue", sendData

    @github.withOptions(@optionsFor(msg)).post "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}/comments", sendData, (data) ->
      # Nada

  assignIssue: (msg, issueId, userName, opts = {}) ->
    sendData =
      assignee: @getGithubUser(userName)

    log "Assigning issue", sendData

    @github.withOptions(@optionsFor(msg)).patch "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}", sendData, (data) =>
      msg.send @getIssueText(data, prefix: "Assigned to #{data.assignee.login}: ")

  showIssues: (msg, userName, label) ->
    queryParams =
      labels: label

    log "Showing issues", queryParams

    if userName.toLowerCase() == 'everyone'
      options = @optionsFor(msg, false)
      queryParams.filter = 'all'
    else
      options = @optionsFor(msg, userName)
      queryParams.filter = 'assigned'

    console.log options, queryParams

    @github.
      withOptions(options).
      get "/orgs/#{@org}/issues", queryParams, (data) =>
        if _.isEmpty data
            msg.send "No issues found."
        else
          msg.send _.map(data, ((issue) => @getIssueText(issue, { includeAssignee: queryParams.filter == 'all' }))).join("\n")

module.exports = (robot) ->
  robot.githubTodosSender = new GithubTodosSender(robot)

  robot.respond /add task (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[1], msg.message.user.name

  robot.respond /work on (.*)/i, (msg) ->
    # If we're working on an existing issue...
    if msg.match[1].match(/\#\d+/) || msg.match[1].trim().match(/^\d+$/)
      robot.githubTodosSender.moveIssue msg, msg.match[1], CURRENT_LABEL
    # Otherwise, create one
    else
      robot.githubTodosSender.addIssue msg, msg.match[1], msg.message.user.name, label: CURRENT_LABEL

  robot.respond /ask (\S+) to (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[2], msg.match[1], footer: true

  robot.respond /move (\S*\#?\d+) to (\S+)/i, (msg) ->
    robot.githubTodosSender.moveIssue(
      msg,
      msg.match[1],
      labelNameMaps[msg.match[2].toLowerCase()] || msg.match[2]
    )

  robot.respond /finish (\S*\#?\d+)/i, (msg) ->
    if (comment = msg.message.text.split(GithubTodosSender.ISSUE_BODY_SEPARATOR)[1])
      robot.githubTodosSender.commentOnIssue msg, msg.match[1], doubleUnquote(_s.trim(comment))

    robot.githubTodosSender.moveIssue msg, msg.match[1], 'done'

  robot.respond /what am i working on\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, CURRENT_LABEL

  robot.respond /what(['|’]s|s|\sis) (\S+) working on\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2], CURRENT_LABEL

  robot.respond /what(['|’]s|s|\sis) next for (\S+)\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2].replace('?', ''), UPCOMING_LABEL

  robot.respond /what(['|’]s|s|\sis) next\??(\s*)$/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, UPCOMING_LABEL

  robot.respond /what(['|’]s|s|\sis) on my shelf\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, SHELF_LABEL

  robot.respond /what(['|’]s|s|\sis) on (\S+) shelf\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2].split('\'')[0], SHELF_LABEL

  robot.respond /assign (\S*\#?\d+) to (\S+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[1], msg.match[2]

  robot.respond /assign (\S+) to (\S*\#?\d+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[2], msg.match[1]

  robot.respond /i(['|’]ll|ll) work on (\S*\#?\d+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[2], msg.message.user.name
