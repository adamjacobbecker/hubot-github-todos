# Configuration:
#   HUBOT_GITHUB_TODOS_REPO
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER_<NAME>
#   HUBOT_GITHUB_USER_<NAME>_TOKEN
#
# Notes:
#   HUBOT_GITHUB_TODOS_REPO = 'username/reponame'
#   HUBOT_GITHUB_TOKEN = oauth token (we use a "dobthubot" github account)
#   HUBOT_GITHUB_USER_ADAM = 'adamjacobbecker'
#   HUBOT_GITHUB_USER_ADAM_TOKEN = adamjacobbecker's oauth token
#
#   Individual users' oauth tokens are opt-in, but if you choose
#   not to add them, you'll end up notifying yourself when you
#   add a task.
#
#   You'll need to create 'done', 'trash', 'upcoming', 'shelf', and 'current' labels.
#
# Commands:
#   hubot add task <text> #todos
#   hubot ask <user|everyone> to <text> #todos
#   hubot assign <id> to <user> #todos
#   hubot assign <user> to <id> #todos
#   hubot finish <id> #todos
#   hubot i'll work on <id> #todos
#   hubot move <id> to <done|current|upcoming|shelf> #todos
#   hubot what am i working on #todos
#   hubot what's <user|everyone> working on #todos
#   hubot what's next #todos
#   hubot what's next for <user|everyone> #todos
#   hubot what's on <user|everyone>'s shelf #todos
#   hubot what's on my shelf #todos
#   hubot work on <id> #todos
#   hubot work on <text> #todos
#
# License:
#   MIT

_  = require("underscore")
_s = require("underscore.string")

log = (msgs...) ->
  console.log(msgs)

doubleUnquote = (x) ->
  _s.unquote(_s.unquote(x), "'")

class GithubTodosSender

  ISSUE_BODY_SEPARATOR = ' body:'

  constructor: (robot) ->
    @robot = robot
    @github = require("githubot")(@robot)

  getGithubUser: (userName) ->
    log "Getting GitHub username for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}"]

  getGithubToken: (userName) ->
    log "Getting GitHub token for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}_TOKEN"]

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
                    .split(ISSUE_BODY_SEPARATOR)

    sendData =
      title: title
      body: body || ''
      assignee: @getGithubUser(userName)
      labels: [opts.label || 'upcoming']

    options = {}

    if (x = @getGithubToken(msg.message.user.name))
      options.token = x

    else if opts.footer
      sendData.body += "\n\n(added by #{@getGithubUser(msg.message.user.name) || 'unknown user'}. " +
                   "remember, you'll need to bring them in with an @mention.)"

    log "Adding issue", sendData

    @github.withOptions(options).post "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues", sendData, (data) ->
      msg.send "Added issue ##{data.number}: #{data.html_url}"

  moveIssue: (msg, issueId, newLabel, opts = {}) ->
    @github.get "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues/#{issueId}", (data) =>
      labelNames = _.pluck(data.labels, 'name')
      labelNames = _.without(labelNames, 'done', 'trash', 'upcoming', 'shelf', 'current')
      labelNames.push(newLabel.toLowerCase())

      sendData =
        state: if newLabel in ['done', 'trash'] then 'closed' else 'open'
        labels: labelNames

      options = {}

      if (x = @getGithubToken(msg.message.user.name))
        options.token = x

      log "Moving issue", sendData

      @github.withOptions(options).patch "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues/#{issueId}", sendData, (data) ->
        if _.find(data.labels, ((l) -> l.name.toLowerCase() == newLabel.toLowerCase()))
          msg.send "Moved issue ##{data.number} to #{newLabel.toLowerCase()}: #{data.html_url}"

  assignIssue: (msg, issueId, userName, opts = {}) ->
    sendData =
      assignee: @getGithubUser(userName)

    options = {}

    if (x = @getGithubToken(msg.message.user.name))
      options.token = x

    log "Assigning issue", sendData

    @github.withOptions(options).patch "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues/#{issueId}", sendData, (data) ->
      msg.send "Assigned issue ##{data.number} to #{data.assignee.login}: #{data.html_url}"

  showIssues: (msg, userName, label) ->
    queryParams =
      assignee: if userName.toLowerCase() == 'everyone' then '*' else @getGithubUser(userName)
      labels: label

    log "Showing issues", queryParams

    @github.get "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues", queryParams, (data) ->
      if _.isEmpty data
          msg.send "No issues found."
      else
        for issue in data
          if queryParams.assignee == '*'
            msg.send "#{issue.assignee.login} - ##{issue.number} #{issue.title}: #{issue.html_url}"
          else
            msg.send "##{issue.number} #{issue.title}: #{issue.html_url}"



module.exports = (robot) ->
  robot.githubTodosSender = new GithubTodosSender(robot)

  robot.respond /add task (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[1], msg.message.user.name

  robot.respond /work on ([A-Z\'\"][\s\S\d]+)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[1], msg.message.user.name, label: 'current', footer: true

  robot.respond /ask (\S+) to (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[2], msg.match[1], footer: true

  robot.respond /move\s(task\s)?\#?(\d+) to (\S+)/i, (msg) ->
    robot.githubTodosSender.moveIssue msg, msg.match[2], msg.match[3]

  robot.respond /finish\s(task\s)?\#?(\d+)/i, (msg) ->
    robot.githubTodosSender.moveIssue msg, msg.match[2], 'done'

  robot.respond /work on\s(task\s)?\#?(\d+)/i, (msg) ->
    robot.githubTodosSender.moveIssue msg, msg.match[2], 'current'

  robot.respond /what am i working on\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, 'current'

  robot.respond /what(\'s|s|\sis) (\S+) working on\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2], 'current'

  robot.respond /what(\'s|s|\sis) next for (\S+)\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2].replace('?', ''), 'upcoming'

  robot.respond /what(\'s|s|\sis) next\??(\s*)$/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, 'upcoming'

  robot.respond /what(\'s|s|\sis) on my shelf\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.message.user.name, 'shelf'

  robot.respond /what(\'s|s|\sis) on (\S+) shelf\??/i, (msg) ->
    robot.githubTodosSender.showIssues msg, msg.match[2].split('\'')[0], 'shelf'

  robot.respond /assign \#?(\d+) to (\S+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[1], msg.match[2]

  robot.respond /assign (\S+) to \#?(\d+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[2], msg.match[1]

  robot.respond /i(\'ll|ll) work on \#?(\d+)/i, (msg) ->
    robot.githubTodosSender.assignIssue msg, msg.match[2], msg.message.user.name
