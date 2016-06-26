# build time tests for map plugin
# see http://mochajs.org/


map = require '../client/map'
expect = require 'expect.js'

describe 'map plugin', ->

  describe 'marker coordinates', ->
    it 'should accept decimal lat/lon', ->
      marker = map.marker '45.612094, -122.726922 Smith Lake'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith Lake'}
    it 'should accept decimal lat/lon without comma', ->
      marker = map.marker '45.612094 -122.726922 Smith Lake'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith Lake'}
    it 'should accept decimal lat/lon without space', ->
      marker = map.marker '45.612094,-122.726922 Smith Lake'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith Lake'}
    it 'should accept nautical lat/lon', ->
      marker = map.marker '45°36\'43.5"N 122°43\'36.9"W Smith Lake'
      expect(marker).to.eql {lat: 45.61208333333334, lon: -122.72691666666667, label: 'Smith Lake'}
    it 'should accept nautical lat/lon in lower case', ->
      marker = map.marker '45°36\'43.5"n 122°43\'36.9"w Smith Lake'
      expect(marker).to.eql {lat: 45.61208333333334, lon: -122.72691666666667, label: 'Smith Lake'}
    it 'should accept nautical lat/lon sans seconds', ->
      marker = map.marker '45°36\'N 122°43\'W Smith Lake'
      expect(marker).to.eql {lat: 45.6, lon: -122.71666666666667, label: 'Smith Lake'}

  describe 'marker labels', ->
    it 'should accept decimal lat/lon without label', ->
      marker = map.marker '45.612094, -122.726922'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: ''}
    it 'should accept decimal lat/lon with internal links in labels', ->
      marker = map.marker '45.612094, -122.726922 See [[Portland\'s Smith Lake]]'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'See <internal>'}
    it 'should accept decimal lat/lon with internal links in labels', ->
      marker = map.marker '45.612094, -122.726922 See [http://www.oregonmetro.gov/parks/smith-and-bybee-wetlands-natural-area metro]'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'See <external>'}
    it 'should accept decimal lat/lon with escaped punctuation in labels', ->
      marker = map.marker '45.612094, -122.726922 Smith & Bybee Wetlands'
      expect(marker).to.eql {lat: 45.612094, lon: -122.726922, label: 'Smith &amp; Bybee Wetlands'}

