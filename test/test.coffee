chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Hubot = require('hubot')

expect = chai.expect

CURRENT_LABEL = 'todo_current'
UPCOMING_LABEL = 'todo_upcoming'
SHELF_LABEL = 'hold'

describe 'github-todos', ->
  beforeEach ->
    @robot = new Hubot.Robot(null, "mock-adapter", false, "Hubot")
    @user = @robot.brain.userForId('1', name: "adam", room: "#room")

    require('../scripts/github-todos')(@robot)

    @robot.githubTodosSender =
      addIssue: sinon.spy()
      moveIssue: sinon.spy()
      assignIssue: sinon.spy()
      showIssues: sinon.spy()
      showMilestones: sinon.spy()
      commentOnIssue: sinon.spy()

    @sendCommand = (x) ->
      @robot.adapter.receive(new Hubot.TextMessage(@user, "Hubot #{x}"))

    @expectCommand = (commandName, args...) ->
      args.unshift(sinon.match.any)
      expect(@robot.githubTodosSender[commandName]).to.have.been.calledWith(args...)

    @expectNoCommand = (commandName) ->
      expect(@robot.githubTodosSender[commandName]).to.not.have.been.called

  describe "hubot add task <text>", ->
    it 'works', ->
      @sendCommand 'add task foo'
      @expectCommand('addIssue', 'foo', 'adam')

  describe "hubot add task with hyphen in text", ->
    it 'works', ->
      @sendCommand 'add task do a flim-flam to the blip-blop'
      @expectCommand('addIssue', 'do a flim-flam to the blip-blop', 'adam')

  describe "hubot ask <user> to <text>", ->
    it 'works', ->
      @sendCommand 'ask adam to foo'
      @expectCommand('addIssue', 'foo', 'adam')

  describe "hubot assign <id> to <user>", ->
    it 'works', ->
      @sendCommand 'assign 11 to adam'
      @expectCommand('assignIssue', '11', 'adam')

  describe "hubot assign <user> to <id>", ->
    it 'works', ->
      @sendCommand 'assign adam to 11'
      @expectCommand('assignIssue', '11', 'adam')

  describe "hubot finish <id>", ->
    it 'works', ->
      @sendCommand 'finish 11'
      @expectCommand('moveIssue', '11', 'done')
      @expectNoCommand('commentOnIssue')

  describe "hubot finish <id> with body", ->
    it 'works', ->
      @sendCommand 'finish 11 body: i finished dat ting. it was tough!'
      @expectCommand('moveIssue', '11', 'done')
      @expectCommand('commentOnIssue', '11', "i finished dat ting. it was tough!")

    it 'strips quotes', ->
      @sendCommand 'finish 11 body: "i finished dat ting. it was tough!"'
      @expectCommand('moveIssue', '11', 'done')
      @expectCommand('commentOnIssue', '11', "i finished dat ting. it was tough!")

    it 'strips smart double quotes', ->
      @sendCommand 'finish 11 body: “i finished dat ting. it was tough!”'
      @expectCommand('moveIssue', '11', 'done')
      @expectCommand('commentOnIssue', '11', "i finished dat ting. it was tough!")

    it 'strips smart single quotes', ->
      @sendCommand 'finish 11 body: ‘i finished dat ting. it was tough!’'
      @expectCommand('moveIssue', '11', 'done')
      @expectCommand('commentOnIssue', '11', "i finished dat ting. it was tough!")

  describe "hubot i'll work on <id>", ->
    it 'works', ->
      @sendCommand "i'll work on 11"
      @expectCommand('assignIssue', '11', 'adam')

    it 'works without apostrophe', ->
      @sendCommand "ill work on 11"
      @expectCommand('assignIssue', '11', 'adam')

  describe "hubot move <id> to <done|current|upcoming|shelf>", ->
    it 'works', ->
      @sendCommand "move 11 to todo_upcoming"
      @expectCommand('moveIssue', '11', UPCOMING_LABEL)

  describe "specifying a repo", ->
    it 'works with a simple repo name', ->
      @sendCommand "move foobar#11 to todo_upcoming"
      @expectCommand('moveIssue', 'foobar#11', UPCOMING_LABEL)

    it 'works with a more complex repo name', ->
      @sendCommand "move screendoor-v2#11 to todo_upcoming"
      @expectCommand('moveIssue', 'screendoor-v2#11', UPCOMING_LABEL)

  describe "hubot what am i working on", ->
    it 'works', ->
      @sendCommand "what am i working on"
      @expectCommand('showIssues', 'adam', CURRENT_LABEL)

  describe "hubot what's <user|everyone> working on", ->
    it 'works', ->
      @sendCommand "what's clay working on?"
      @expectCommand('showIssues', 'clay', CURRENT_LABEL)

    it 'works without apostrophe', ->
      @sendCommand "whats clay working on?"
      @expectCommand('showIssues', 'clay', CURRENT_LABEL)

  describe "hubot what's next", ->
    it 'works', ->
      @sendCommand "what's next?"
      @expectCommand('showIssues', 'adam', UPCOMING_LABEL)

    it 'works without apostrophe', ->
      @sendCommand "whats next?"
      @expectCommand('showIssues', 'adam', UPCOMING_LABEL)

  describe "hubot what's next for <user|everyone>", ->
    it 'works', ->
      @sendCommand "what's next for clay?"
      @expectCommand('showIssues', 'clay', UPCOMING_LABEL)

    it 'works without apostrophe', ->
      @sendCommand "whats next for clay?"
      @expectCommand('showIssues', 'clay', UPCOMING_LABEL)

  describe "hubot what's on <user|everyone>'s shelf", ->
    it 'works', ->
      @sendCommand "what's on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', SHELF_LABEL)

    it 'works without apostrophe', ->
      @sendCommand "whats on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', SHELF_LABEL)

    it 'handles smart quotes', ->
      @sendCommand "what’s on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', SHELF_LABEL)

  describe "hubot what's on my shelf", ->
    it 'works', ->
      @sendCommand "what's on my shelf?"
      @expectCommand('showIssues', 'adam', SHELF_LABEL)

    it 'works without apostrophe', ->
      @sendCommand "whats on my shelf?"
      @expectCommand('showIssues', 'adam', SHELF_LABEL)

  describe "hubot work on <id>", ->
    it 'works', ->
      @sendCommand "work on 12"
      @expectCommand('moveIssue', '12', CURRENT_LABEL)

    it 'parses complex repo name', ->
      @sendCommand "work on screendoor-v2#12"
      @expectCommand('moveIssue', 'screendoor-v2#12', CURRENT_LABEL)
      @expectNoCommand('addIssue')

  describe "hubot show milestones", ->
    it 'works', ->
      @sendCommand "show milestones"
      @expectCommand('showMilestones', 'all')

    it 'specifies due date only', ->
      @sendCommand "show milestones with a due date"
      @expectCommand('showMilestones', 'all', dueDate: true)

    it 'specifies due date only v2', ->
      @sendCommand "show milestones with due dates"
      @expectCommand('showMilestones', 'all', dueDate: true)

  describe "hubot show milestones for <repo>", ->
    it 'works', ->
      @sendCommand "show milestones for screendoor-v2"
      @expectCommand('showMilestones', 'screendoor-v2', dueDate: false)

    it 'specifies due date only', ->
      @sendCommand "show milestones for screendoor-v2 with a due date"
      @expectCommand('showMilestones', 'screendoor-v2', dueDate: true)

    it 'specifies due date only v2', ->
      @sendCommand "show milestones for screendoor-v2 with due dates"
      @expectCommand('showMilestones', 'screendoor-v2', dueDate: true)
