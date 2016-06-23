# build time tests for map plugin
# see http://mochajs.org/


map = require '../client/map'
expect = require 'expect.js'

describe 'map plugin', ->

  describe 'markers', ->
    it 'should accept decimal lat/lon', ->
      marker = map.marker '45.612094, -122.726922 Smith Lake'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith Lake'}
    it 'should accept decimal lat/lon without comma', ->
      marker = map.marker '45.612094 -122.726922 Smith Lake'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith Lake'}
    it 'should accept decimal lat/lon without label', ->
      marker = map.marker '45.612094, -122.726922'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: ''}
