# Commands:
#   hubot add task <text> #todos
#   hubot ask <user> to <text> #todos
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

_  = require("underscore")
_s = require("underscore.string")

module.exports = (robot) ->

  log = (msgs...) ->
    console.log(msgs)

  github = require("githubot")(robot)

  getGithubUser = (userName) ->
    log "Getting GitHub username for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}"]

  getGithubToken = (userName) ->
    log "Getting GitHub token for #{userName}"
    process.env["HUBOT_GITHUB_USER_#{userName.split(' ')[0].toUpperCase()}_TOKEN"]

  doubleUnquote = (x) ->
    _s.unquote(_s.unquote(x), "'")

  addIssue = (msg, issueBody, userName, opts = {}) ->
    sendData =
      title: doubleUnquote(issueBody).replace(/\"/g, '').split('-')[0]
      body: doubleUnquote(issueBody).split('-')[1] || ''
      assignee: getGithubUser(userName)
      labels: [opts.label || 'upcoming']

    options = {}

    if (x = getGithubToken(msg.message.user.name))
      options.token = x

    else if opts.footer
      sendData.body += "\n\n(added by #{getGithubUser(msg.message.user.name) || 'unknown user'}. " +
                   "remember, you'll need to bring them in with an @mention.)"

    log "Adding issue", sendData

    github.withOptions(options).post "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues", sendData, (data) ->
      msg.send "Added issue ##{data.number}: #{data.html_url}"

  moveIssue = (msg, issueId, newLabel, opts = {}) ->
    sendData =
      state: if newLabel in ['done', 'trash'] then 'closed' else 'open'
      labels: [newLabel.toLowerCase()]

    options = {}

    if (x = getGithubToken(msg.message.user.name))
      options.token = x

    log "Moving issue", sendData

    github.withOptions(options).patch "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues/#{issueId}", sendData, (data) ->
      if _.find(data.labels, ((l) -> l.name.toLowerCase() == newLabel.toLowerCase()))
        msg.send "Moved issue ##{data.number} to #{newLabel.toLowerCase()}: #{data.html_url}"

  assignIssue = (msg, issueId, userName, opts = {}) ->
    sendData =
      assignee: getGithubUser(userName)

    options = {}

    if (x = getGithubToken(msg.message.user.name))
      options.token = x

    log "Assigning issue", sendData

    github.withOptions(options).patch "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues/#{issueId}", sendData, (data) ->
      msg.send "Assigned issue ##{data.number} to #{data.assignee.login}: #{data.html_url}"

  showIssues = (msg, userName, label) ->
    queryParams =
      assignee: if userName.toLowerCase() == 'everyone' then '*' else getGithubUser(userName)
      labels: label

    log "Showing issues", queryParams

    github.get "repos/#{process.env['HUBOT_GITHUB_TODOS_REPO']}/issues", queryParams, (data) ->
      if _.isEmpty data
          msg.send "No issues found."
      else
        for issue in data
          if queryParams.assignee == '*'
            msg.send "#{issue.assignee.login} - ##{issue.number} #{issue.title}: #{issue.html_url}"
          else
            msg.send "##{issue.number} #{issue.title}: #{issue.html_url}"

  robot.respond /add task (.*)/i, (msg) ->
    addIssue msg, msg.match[1], msg.message.user.name

  robot.respond /work on ([A-Z\'\"][\s\S\d]+)/i, (msg) ->
    addIssue msg, msg.match[1], msg.message.user.name, label: 'current', footer: true

  robot.respond /ask (\S+) to (.*)/i, (msg) ->
    addIssue msg, msg.match[2], msg.match[1], footer: true

  robot.respond /move\s(task\s)?\#?(\d+) to (\S+)/i, (msg) ->
    moveIssue msg, msg.match[2], msg.match[3]

  robot.respond /finish\s(task\s)?\#?(\d+)/i, (msg) ->
    moveIssue msg, msg.match[2], 'done'

  robot.respond /work on\s(task\s)?\#?(\d+)/i, (msg) ->
    moveIssue msg, msg.match[2], 'current'

  robot.respond /what am i working on\??/i, (msg) ->
    showIssues msg, msg.message.user.name, 'current'

  robot.respond /what(\'s)?(\sis)? (\S+) working on\??/i, (msg) ->
    showIssues msg, msg.match[3], 'current'

  robot.respond /what(\'s)?(\sis)? next for (\S+)\??/i, (msg) ->
    showIssues msg, msg.match[3].replace('?', ''), 'upcoming'

  robot.respond /what(\'s)?(\sis)? next\??(\s*)$/i, (msg) ->
    showIssues msg, msg.message.user.name, 'upcoming'

  robot.respond /what(\'s)?(\sis)? on my shelf\??/i, (msg) ->
    showIssues msg, msg.message.user.name, 'shelf'

  robot.respond /what(\'s)?(\sis)? on (\S+) shelf\??/i, (msg) ->
    showIssues msg, msg.match[3].split('\'')[0], 'shelf'

  robot.respond /assign \#?(\d+) to (\S+)/i, (msg) ->
    assignIssue msg, msg.match[1], msg.match[2]

  robot.respond /assign (\S+) to \#?(\d+)/i, (msg) ->
    assignIssue msg, msg.match[2], msg.match[1]

  robot.respond /i\'ll work on \#?(\d+)/i, (msg) ->
    assignIssue msg, msg.match[1], msg.message.user.name
