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
# Commands:
hubot add task <text>
hubot ask <user> to <text>
hubot assign <id> to <user>
hubot assign <user> to <id>
hubot finish <id>
hubot i'll work on <id>
hubot move <id> to <done|current|upcoming|shelf>
hubot what am i working on
hubot what's <user|everyone> working on
hubot what's next
hubot what's next for <user|everyone>
hubot what's on <user|everyone>'s shelf
hubot what's on my shelf
hubot work on <id>
hubot work on <text>
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
- Tests!

## License
MIT
