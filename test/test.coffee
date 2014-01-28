chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Hubot = require('hubot')

expect = chai.expect

describe 'github-todos', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../scripts/github-todos')(@robot)

  # it 'registers a respond listener', ->
  #   expect(@robot.respond).to.have.been.calledWith(/hello/)

  # it 'registers a hear listener', ->
  #   expect(@robot.hear).to.have.been.calledWith(/orly/)

  it 'foo', ->
    robot = new Hubot.Robot(null, "mock-adapter", false, "Hubot")
    user = robot.brain.userForId('1', name: "adam", room: "#room")
    robot.adapter.receive(new Hubot.TextMessage(user, "Computer!"))

  it 'matches properly'