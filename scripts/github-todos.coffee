# Configuration:
#   HUBOT_GITHUB_TODOS_REPO
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER_<NAME>
#   HUBOT_GITHUB_USER_<NAME>_TOKEN
#
# Notes:
#   HUBOT_GITHUB_TODOS_REPO = 'username/reponame' (separate multiple with commas, first one is primary)
#   HUBOT_GITHUB_TOKEN = oauth token (we use a "dobthubot" github account)
#   HUBOT_GITHUB_USER_ADAM = 'adamjacobbecker'
#   HUBOT_GITHUB_USER_ADAM_TOKEN = adamjacobbecker's oauth token
#
#   Individual users' oauth tokens are opt-in, but if you choose
#   not to add them, you'll end up notifying yourself when you
#   add a task.
#
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
#   hubot move <id> to <done|current|upcoming|shelf> #todos
#   hubot what am i working on #todos
#   hubot what's <user|everyone> working on #todos
#   hubot what's next #todos
#   hubot what's next for <user|everyone> #todos
#   hubot what's on <user|everyone>'s shelf #todos
#   hubot what's on my shelf #todos
#   hubot work on <id> #todos
#   hubot work on <repo>#<id> #todos
#   hubot show milestones #todos
#   hubot show milestones with a due date #todos
#   hubot show milestones with due dates #todos
#   hubot show milestones for <repo> #todos
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

log = (msgs...) ->
  console.log(msgs)

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
    @allRepos = (process.env['HUBOT_GITHUB_TODOS_REPO'] || '').split(',') # default to empty string for tests
    @primaryRepo = @allRepos[0]
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
        id: str.replace('#', '')
      }

  getGithubUser: (userName) ->
    log "Getting GitHub username for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}"]

  getGithubToken: (userName) ->
    log "Getting GitHub token for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}_TOKEN"]

  optionsFor: (msg) ->
    options = {}

    if (x = @getGithubToken(msg.message.user.name))
      options.token = x

    options

  getIssueText: (issueObject, opts = {}) ->
    str = "#{opts.prefix || ''}"

    if opts.includeAssignee
      str += "#{issueObject.assignee?.login} - "

    if !issueObject.url.match(@primaryRepo)
      str += "#{issueObject.url.split('repos/')[1].split('/issues')[0]} "

    str += "##{issueObject.number} #{issueObject.title} - #{issueObject.html_url}"

    str

  getMilestoneText: (milestoneObject, opts = {}) ->
    repoName = milestoneObject.url.split('repos/')[1].split('/milestones')[0]
    milestoneIssuesUrl = "https://github.com/#{repoName}/issues?milestone=#{milestoneObject.number}&state=open"
    dueDateText = if milestoneObject.due_on then moment(milestoneObject.due_on).fromNow(true) else "No due date"

    """
      #{repoName} #{milestoneObject.title} - #{dueDateText} - #{milestoneIssuesUrl}
    """

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

    @github.get "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}", (data) =>
      labelNames = _.pluck(data.labels, 'name')
      labelNames = _.without(labelNames, UPCOMING_LABEL, SHELF_LABEL, CURRENT_LABEL)
      labelNames.push(newLabel.toLowerCase()) unless newLabel in TRASH_COMMANDS

      sendData =
        state: if newLabel in TRASH_COMMANDS then 'closed' else 'open'
        labels: labelNames

      log "Moving issue", sendData

      @github.withOptions(@optionsFor(msg)).patch "repos/#{@parseIssueString(issueId).repo}/issues/#{@parseIssueString(issueId).id}", sendData, (data) =>
        if _.find(data.labels, ((l) -> l.name.toLowerCase() == newLabel.toLowerCase()))
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
      assignee: if userName.toLowerCase() == 'everyone' then '*' else @getGithubUser(userName)
      labels: label

    log "Showing issues", queryParams

    showIssueFunctions = []

    for repo in @allRepos
      do (repo) =>
        showIssueFunctions.push( (cb) =>
          @github.get "repos/#{repo}/issues", queryParams, (data) ->
            cb(null, data)
        )

    async.parallel showIssueFunctions, (err, results) =>
      log("ERROR: #{err}") if err
      allResults = [].concat.apply([], results)

      if _.isEmpty allResults
          msg.send "No issues found."
      else
        msg.send _.map(allResults, ((issue) => @getIssueText(issue, { includeAssignee: queryParams.assignee == '*' }))).join("\n")

  showMilestones: (msg, repoName, opts = {}) ->
    queryParams =
      state: 'open'

    log "Showing milestones", queryParams

    showMilestoneFunctions = []

    selectedRepos = if repoName == 'all'
      @allRepos
    else
      _.filter @allRepos, (repo) ->
        repo.split('/')[1].match(repoName)

    for repo in selectedRepos
      do (repo) =>
        showMilestoneFunctions.push( (cb) =>
          @github.get "repos/#{repo}/milestones", queryParams, (data) ->
            cb(null, data)
        )

    async.parallel showMilestoneFunctions, (err, results) =>
      log("ERROR: #{err}") if err
      allResults = [].concat.apply([], results)

      if opts.dueDate
        allResults = _.filter allResults, (r) -> r.due_on

      allResults = _.sortBy allResults, (r) ->
        r.due_on || "9"

      if _.isEmpty allResults
          msg.send "No milestones found."
      else
        msg.send _.map(allResults, ((milestone) => @getMilestoneText(milestone))).join("\n")

module.exports = (robot) ->
  robot.githubTodosSender = new GithubTodosSender(robot)

  robot.respond /add task (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[1], msg.message.user.name

  robot.respond /work on (\S*\#?\d+)/i, (msg) ->
    robot.githubTodosSender.moveIssue msg, msg.match[1], CURRENT_LABEL

  robot.respond /ask (\S+) to (.*)/i, (msg) ->
    robot.githubTodosSender.addIssue msg, msg.match[2], msg.match[1], footer: true

  robot.respond /move (\S*\#?\d+) to (\S+)/i, (msg) ->
    robot.githubTodosSender.moveIssue msg, msg.match[1], msg.match[2]

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

  robot.respond /show milestones for (\S+)/i, (msg) ->
    robot.githubTodosSender.showMilestones msg, msg.match[1], dueDate: (if msg.message.match('due date') then true else false)

  robot.respond /show milestones(\s*)$/i, (msg) ->
    robot.githubTodosSender.showMilestones msg, 'all'

  robot.respond /show milestones with (a\s)?due date/i, (msg) ->
    robot.githubTodosSender.showMilestones msg, 'all', dueDate: true
