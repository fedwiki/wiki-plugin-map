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
  decimal = /^(-?\d{1,3}\.?\d*)[, ] *(-?\d{1,3}\.?\d*)\s*(.*)$/
  nautical = /^(\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([NS]) (\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([EW]) (.*)$/i
  return {lat: +m[1], lon: +m[2], label: resolve(m[3])} if m = decimal.exec text
  return {lat: deg(m[1..4]), lon: deg(m[5..8]), label: resolve(m[9])} if m = nautical.exec text
  null

lineup = ($item) ->
  return [{lat: 51.5, lon: 0.0, label: 'North Greenwich'}] unless wiki?
  markers = []
  candidates = $(".item:lt(#{$('.item').index($item)})")
  if (who = candidates.filter ".marker-source").size()
    markers = markers.concat div.markerData() for div in who
  markers

parse = (text, $item) ->
  captions = []
  markers = []
  overlays = null
  boundary = null
  weblink = null
  for line in text.split /\n/
    if m = marker line
      m.weblink = weblink if weblink?
      markers.push m
    else if m = /^BOUNDARY *(.*)?$/.exec line
      hints = if hint = marker m[1] then [hint] else []
      boundary = markers.concat [] unless boundary?
      boundary = boundary.concat hints
    else if /^LINEUP/.test line
      markers = markers.concat lineup($item)
    else if m = /^WEBLINK *(.*)$/.exec line
      weblink = m[1]
    else if m = /^OVERLAY *(.+?) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+)$/.exec line
      overlays = (overlays||[]).concat {url:m[1], bounds:[[m[2],m[3]],[m[4],m[5]]]}
    else
      captions.push resolve(line)
  boundary = markers unless boundary?
  result = {markers, caption: captions.join('<br>'), boundary}
  result.weblink = weblink if weblink?
  result.overlays = overlays if overlays?
  result

feature = (marker) ->
  type: 'Feature'
  geometry:
    type: 'Point'
    coordinates: [marker.lon, marker.lat]
    properties:
      label: marker.label

emit = ($item, item) ->

  {caption, markers, boundary, weblink, overlays} = parse item.text, $item

  # announce our capability to produce markers in native and geojson format

  $item.addClass 'marker-source'

  showing = []
  $item.get(0).markerData = ->
    opened = showing.filter (s) -> s.leaflet._popup._isOpen
    if opened.length
      opened.map (s) -> s.marker
    else
      parse(item.text).markers

  $item.get(0).markerGeo = ->
    type: 'FeatureCollection'
    features: parse(item.text).markers.map(feature)

  if (!$("link[href='https://unpkg.com/leaflet@1.3.1/dist/leaflet.css']").length)
    $('<link rel="stylesheet" href="https://unpkg.com/leaflet@1.3.1/dist/leaflet.css">').appendTo("head")
  if (!$("link[href='/plugins/map/map.css']").length)
    $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo("head")

  wiki.getScript "https://unpkg.com/leaflet@1.3.1/dist/leaflet.js", ->

    mapId = "map-#{Math.floor(Math.random()*1000000)}"

    $item.append """
      <figure style="padding: 8px;">
        <div id="#{mapId}" style='height: 300px;'></div>
        <p class="caption">#{caption}</p>
      </figure>
    """

    map = L.map(mapId, {
      scrollWheelZoom: false
      })

    update = ->
      wiki.pageHandler.put $item.parents('.page:first'),
        type: 'edit',
        id: item.id,
        item: item

    # stop dragging the map from propagating and dragging the page item.
    mapDiv = L.DomUtil.get("#{mapId}")
    L.DomEvent.disableClickPropagation(mapDiv)

    map.doubleClickZoom.disable()
    map.on 'dblclick', (e) ->
      if e.originalEvent.shiftKey
        e.originalEvent.stopPropagation()
        new L.marker(e.latlng).addTo(map)
        item.text += "\n#{e.latlng.lat.toFixed 7}, #{e.latlng.lng.toFixed 7}"
        update()


    # select tiles, default to OSM
    tile = item.tile || "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
    tileCredits  = item.tileCredits || '© <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

    L.tileLayer(tile, {
      attribution: tileCredits
      }).addTo(map)

    # add specialized map overlays
    for o in overlays||[]
      L.imageOverlay(o.url, o.bounds, {opacity:0.6, interactive:true}).addTo(map)

    openWeblink = (e) ->
      return unless link = e.target.options.weblink
      window.open (link
        .replace(/\{LAT}/, e.latlng.lat)
        .replace(/\{(LON|LNG)}/, e.latlng.lng))

    showMarkers = (markers) ->
      return unless markers
      for p in markers
        markerLabel  = htmlDecode(wiki.resolveLinks(p.label))
        mkr = L.marker([p.lat, p.lon], {weblink: p.weblink || weblink})
          .on( 'dblclick', openWeblink)
          .bindPopup( markerLabel )
          .openPopup()
          .addTo(map);
        showing.push {leaflet:mkr, marker:p}

    # add markers on the map
    showMarkers markers

    # center map on markers or item properties
    if boundary.length > 1
      bounds = new L.LatLngBounds [ [p.lat, p.lon] for p in boundary ]
      map.fitBounds bounds
    else if boundary.length == 1
      p = boundary[0]
      map.setView([p.lat, p.lon], item.zoom || 13)
    else
      map.setView(item.latlng || item.latLng || [40.735383, -73.984655], item.zoom || 13)

    # find and add markers from candidate items


bind = ($item, item) ->
  $item.dblclick ->
    wiki.textEditor $item, item


window.plugins.map = {emit, bind} if window?
module.exports = {marker, parse} if module?
