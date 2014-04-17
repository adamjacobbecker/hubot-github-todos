chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Hubot = require('hubot')

expect = chai.expect

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

  describe "hubot finish <id> i finished dat ting. it was tough!", ->
    it 'works', ->
      @sendCommand 'finish 11 body: i finished dat ting. it was tough!'
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
      @sendCommand "move 11 to upcoming"
      @expectCommand('moveIssue', '11', 'upcoming')

  describe "hubot what am i working on", ->
    it 'works', ->
      @sendCommand "what am i working on"
      @expectCommand('showIssues', 'adam', 'current')

  describe "hubot what's <user|everyone> working on", ->
    it 'works', ->
      @sendCommand "what's clay working on?"
      @expectCommand('showIssues', 'clay', 'current')

    it 'works without apostrophe', ->
      @sendCommand "whats clay working on?"
      @expectCommand('showIssues', 'clay', 'current')

  describe "hubot what's next", ->
    it 'works', ->
      @sendCommand "what's next?"
      @expectCommand('showIssues', 'adam', 'upcoming')

    it 'works without apostrophe', ->
      @sendCommand "whats next?"
      @expectCommand('showIssues', 'adam', 'upcoming')

  describe "hubot what's next for <user|everyone>", ->
    it 'works', ->
      @sendCommand "what's next for clay?"
      @expectCommand('showIssues', 'clay', 'upcoming')

    it 'works without apostrophe', ->
      @sendCommand "whats next for clay?"
      @expectCommand('showIssues', 'clay', 'upcoming')

  describe "hubot what's on <user|everyone>'s shelf", ->
    it 'works', ->
      @sendCommand "what's on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', 'shelf')

    it 'works without apostrophe', ->
      @sendCommand "whats on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', 'shelf')

    it 'handles smart quotes', ->
      @sendCommand "what’s on everyone's shelf?"
      @expectCommand('showIssues', 'everyone', 'shelf')

  describe "hubot what's on my shelf", ->
    it 'works', ->
      @sendCommand "what's on my shelf?"
      @expectCommand('showIssues', 'adam', 'shelf')

    it 'works without apostrophe', ->
      @sendCommand "whats on my shelf?"
      @expectCommand('showIssues', 'adam', 'shelf')

  describe "hubot work on <id>", ->
    it 'works', ->
      @sendCommand "work on 12"
      @expectCommand('moveIssue', '12', 'current')

  describe "hubot work on <text>", ->
    it 'works', ->
      @sendCommand "work on foo"
      @expectCommand('addIssue', 'foo', 'adam', { footer: true, label: 'current' })
