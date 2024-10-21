// build time tests for map plugin
// see http://mochajs.org/

import { map } from '../src/map.js';
import expect from 'expect.js';

describe('map plugin', () => {
  describe('marker coordinates', () => {
    it('should accept decimal lat/lon', () => {
      const marker = map.marker('45.612094, -122.726922 Smith Lake');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'Smith Lake'});
    });
    it('should accept decimal lat/lon without comma', () => {
      const marker = map.marker('45.612094 -122.726922 Smith Lake');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'Smith Lake'});
    });
    it('should accept decimal lat/lon without space', () => {
      const marker = map.marker('45.612094,-122.726922 Smith Lake');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'Smith Lake'});
    });

    it('should accept decimal lat/lon without decimal point', () => {
      const marker = map.marker('45, -122 Smith Lake');
      expect(marker).to.eql({lat: 45, lon: -122, label: 'Smith Lake'});
    });
    it('should accept decimal lat/lon without decimal point or comma', () => {
      const marker = map.marker('45 -122 Smith Lake');
      expect(marker).to.eql({lat: 45, lon: -122, label: 'Smith Lake'});
    });

    it('should accept nautical lat/lon', () => {
      const marker = map.marker('45°36\'43.5"N 122°43\'36.9"W Smith Lake');
      expect(marker).to.eql({lat: 45.61208333333334, lon: -122.72691666666667, label: 'Smith Lake'});
    });
    it('should accept nautical lat/lon in lower case', () => {
      const marker = map.marker('45°36\'43.5"n 122°43\'36.9"w Smith Lake');
      expect(marker).to.eql({lat: 45.61208333333334, lon: -122.72691666666667, label: 'Smith Lake'});
    });
    it('should accept nautical lat/lon sans seconds', () => {
      const marker = map.marker('45°36\'N 122°43\'W Smith Lake');
      expect(marker).to.eql({lat: 45.6, lon: -122.71666666666667, label: 'Smith Lake'});
    });
  });

  describe('marker labels', () => {
    it('should accept decimal lat/lon without label', () => {
      const marker = map.marker('45.612094, -122.726922');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: ''});
    });
    it('should accept decimal lat/lon with internal links in labels', () => {
      const marker = map.marker('45.612094, -122.726922 See [[Portland\'s Smith Lake]]');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'See <internal>'});
    });
    it('should accept decimal lat/lon with internal links in labels', () => {
      const marker = map.marker('45.612094, -122.726922 See [http://www.oregonmetro.gov/parks/smith-and-bybee-wetlands-natural-area metro]');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'See <external>'});
    });
    it('should accept decimal lat/lon with escaped punctuation in labels', () => {
      const marker = map.marker('45.612094, -122.726922 Smith & Bybee Wetlands');
      expect(marker).to.eql({lat: 45.612094, lon: -122.726922, label: 'Smith &amp; Bybee Wetlands'});
    });
  });

  describe('markup', () => {
    const hi = "Hello";
    const ho = "World";
    const n46 = "46., -122. Wind River";
    const n47 = "47., -122. Bagby";
    const li = "LINEUP";
    const bo = "BOUNDARY";
    const p46 = {lat:46,lon:-122,label:'Wind River'};
    const p47 = {lat:47,lon:-122,label:'Bagby'};
    const pi = {lat: 51.5, lon: 0.0, label: 'North Greenwich'};

    it('should accept caption only', () => {
      const parse = map.parse({text: hi});
      expect(parse).to.eql({markers:[], caption:'Hello', boundary:[]});
    });

    it('should accept marker only', () => {
      const parse = map.parse({text: n46});
      expect(parse).to.eql({markers:[p46], caption:'', boundary:[p46]});
    });

    it('should accept mixed markers and caption', () => {
      const parse = map.parse({text: [hi,n46,ho,n47].join("\n")});
      expect(parse).to.eql({markers:[p46,p47], caption:'Hello<br>World', boundary:[p46,p47]});
    });

    it('should merge markers with lineup', () => {
      const parse = map.parse({text: [n46,li].join("\n")});
      expect(parse).to.eql({markers:[p46,pi], lineupMarkers:[pi], caption:'', boundary:[p46,pi], tools: {freeze: true}});
    });

    it('should separate markers from lineup for boundary', () => {
      const parse = map.parse({text: [n46,bo,li].join("\n")});
      expect(parse).to.eql({markers:[p46,pi], lineupMarkers:[pi], caption:'', boundary:[p46], tools: {freeze: true}});
    });

    it('should accept boundary without marker', () => {
      const parse = map.parse({text: [bo+n46].join("\n")});
      expect(parse).to.eql({markers:[], caption:'', boundary:[p46]});
    });

    it('should accept multiple boundary without marker', () => {
      const parse = map.parse({text: [bo+n46, bo+n47].join("\n")});
      expect(parse).to.eql({markers:[], caption:'', boundary:[p46,p47]});
    });

    it('should add markers to boundary until stopped', () => {
      const parse = map.parse({text: [n46,bo,li,bo+n47].join("\n")});
      expect(parse).to.eql({markers:[p46,pi], lineupMarkers:[pi], caption:'', boundary:[p46,p47], tools: {freeze: true}});
    });

    it('should accept overlay url and bounds', () => {
      const parse = map.parse({text: "OVERLAY http://example.com 45.5,-122.0 44.5,-123.0"});
      expect(parse).to.eql({markers:[], caption:'', boundary:[], overlays:[{url:'http://example.com',bounds:[[45.5,-122.0],[44.5,-123.0]]}]});
    });

    it('should accept overlay url and bounds with space after comma', () => {
      const parse = map.parse({text: "OVERLAY http://example.com 45.5, -122.0 44.5, -123.0"});
      expect(parse).to.eql({markers:[], caption:'', boundary:[], overlays:[{url:'http://example.com',bounds:[[45.5,-122.0],[44.5,-123.0]]}]});
    });

    it('frozen markers should be markers', () => {
      const parse = map.parse({text: '', frozen: p46});
      expect(parse).to.eql({markers:[p46], caption:'', boundary:[p46]});
    });

    it('lineup with frozen should be lineupMarkers', () => {
      const parse = map.parse({text: [n46,li].join("\n"), frozen: p47});
      expect(parse).to.eql({markers:[p47,p46], caption:'', boundary: [p47,p46], tools: {freeze: true}});
    });

    it('should add SEARCH tool', () => {
      const parse = map.parse({text: 'SEARCH'});
      expect(parse).to.eql({markers:[], caption:'',boundary:[],tools: {search: true}});
    });

    it('should add LOCATE tool', () => {
      const parse = map.parse({text: 'LOCATE'});
      expect(parse).to.eql({markers:[], caption:'',boundary:[],tools: {locate: true}});
    });
  });
});
