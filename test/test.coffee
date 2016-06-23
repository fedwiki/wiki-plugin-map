# build time tests for map plugin
# see http://mochajs.org/


map = require '../client/map'
expect = require 'expect.js'

describe 'map markup', ->

  describe 'parse', ->
    it 'accepts empty', ->
      [lat,lon] = map.parse '45.612094, -122.726922 Smith Lake'
      expect(lat).to.eql 45.612094
