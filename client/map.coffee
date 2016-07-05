###
 * Federated Wiki : Map Plugin
 *
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-plugin-map/blob/master/LICENSE.txt
###

escape = (line) ->
  line
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

resolve = (text) ->
  if wiki?
    wiki.resolveLinks(text, escape)
  else
    escape(text)
      .replace(/\[\[.*?\]\]/g,'<internal>')
      .replace(/\[.*?\]/g,'<external>')

htmlDecode = (escapedText) ->
  doc = new DOMParser().parseFromString(escapedText, "text/html")
  doc.documentElement.textContent

marker = (text) ->
  deg = (m) ->
    num = +m[0] + m[1]/60 + (m[2]||0)/60/60
    if m[3].match /[SW]/i then -num else num
  decimal = /^(-?\d{1,3}\.\d*),? *(-?\d{1,3}\.\d*)\s*(.*)$/
  nautical = /^(\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([NS]) (\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([EW]) (.*)$/i
  return {lat: +m[1], lon: +m[2], label: resolve(m[3])} if m = decimal.exec text
  return {lat: deg(m[1..4]), lon: deg(m[5..8]), label: resolve(m[9])} if m = nautical.exec text
  null

parse = (text) ->
  captions = []
  markers = []
  for line in text.split /\n/
    if m = marker line
      markers.push m
    else
      captions.push resolve(line)
  {markers, caption: captions.join('<br>')}

feature = (marker) ->
  type: 'Feature'
  geometry:
    type: 'Point'
    coordinates: [marker.lon, marker.lat]
    properties:
      label: marker.label

emit = ($item, item) ->

  {caption, markers} = parse item.text

  # announce our capability to produce markers in native and geojson format
  $item.addClass 'marker-source'
  $item.get(0).markerData = ->
    parse(item.text).markers
  $item.get(0).markerGeo = ->
    type: 'FeatureCollection'
    features: parse(item.text).markers.map(feature)

  if (!$("link[href='http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css']").length)
    $('<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css">').appendTo("head")
  if (!$("link[href='/plugins/map/map.css']").length)
    $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo("head")

  wiki.getScript "http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.js", ->

    mapId = "map-#{Math.floor(Math.random()*1000000)}"

    $item.append """
      <figure style="padding: 8px;">
        <div id="#{mapId}" style='height: 300px;'></div>
        <p class="caption">#{caption}</p>
      </figure>
    """

    map = L.map(mapId)

    # disable double click zoom - so we can use double click to start edit
    map.doubleClickZoom.disable()

    # select tiles, default to OSM
    tile = item.tile || "http://{s}.tile.osm.org/{z}/{x}/{y}.png"
    tileCredits  = item.tileCredits || '<a href="http://osm.org/copyright">OSM</a>'

    L.tileLayer(tile, {
      attribution: tileCredits
      }).addTo(map)

    showMarkers = (markers) ->
      return unless markers
      for p in markers
        markerLabel  = htmlDecode(wiki.resolveLinks(p.label))
        L.marker([p.lat, p.lon])
          .bindPopup( markerLabel )
          .openPopup()
          .addTo(map);

    # add markers on the map
    showMarkers markers

    # center map on markers or item properties
    if markers.length
      bounds = new L.LatLngBounds [ [p.lat, p.lon] for p in markers ]
      map.fitBounds bounds
    else
      map.setView(item.latlng || [40.735383, -73.984655], item.zoom || 13)

    # find and add markers from candidate items
    candidates = $(".item:lt(#{$('.item').index($item)})")
    if (who = candidates.filter ".marker-source").size()
      showMarkers div.markerData() for div in who


bind = ($item, item) ->
  $item.dblclick ->
    wiki.textEditor $item, item


window.plugins.map = {emit, bind} if window?
module.exports = {marker} if module?
