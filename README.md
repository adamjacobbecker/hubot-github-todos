hubot-github-todos
==================

Manage todos using GitHub issues.

## Dependencies:
```
"underscore": "1.5.2"
"underscore.string": "2.3.3"
"githubot": "0.4.0"
```

## Configuration:
```
HUBOT_GITHUB_TODOS_REPO
HUBOT_GITHUB_TOKEN
HUBOT_GITHUB_USER_<NAME>
HUBOT_GITHUB_USER_<NAME>_TOKEN
```

## Commands:
```
hubot add task <text> #todos
hubot ask <user> to <text> #todos
hubot assign <id> to <user> #todos
hubot assign <user> to <id> #todos
hubot finish <id> #todos
hubot i'll work on <id> #todos
hubot move <id> to <done|current|upcoming|shelf> #todos
hubot what am i working on #todos
hubot what's <user> working on #todos
hubot what's next #todos
hubot what's next for <user> #todos
hubot what's on <user>'s shelf #todos
hubot what's on my shelf #todos
hubot work on <id> #todos
hubot work on <text> #todos
```

## Notes:
```
HUBOT_GITHUB_TODOS_REPO = 'username/reponame'
HUBOT_GITHUB_TOKEN = oauth token (we use a "dobthubot" github account)
HUBOT_GITHUB_USER_ADAM = 'adamjacobbecker'
HUBOT_GITHUB_USER_ADAM_TOKEN = adamjacobbecker's oauth token

Individual users' oauth tokens are opt-in, but if you choose
not to add them, you'll end up notifying yourself when you
add a task.

You'll need to create 'done', 'trash', 'upcoming', 'shelf', and 'current' labels.
```

## Todo:
- alternate syntaxes?
- what did [i|user] finish [in [period of time]]
- Automatic time tracking w/ comments
