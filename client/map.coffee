###
 * Federated Wiki : Map Plugin
 *
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-plugin-map/blob/master/LICENSE.txt
###

# page markers?
usePageMarkers = false

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
  lineupMarkers = []
  candidates = $(".item:lt(#{$('.item').index($item)})")
  if (who = candidates.filter ".marker-source").length
    lineupMarkers = lineupMarkers.concat div.markerData() for div in who
  lineupMarkers
  
page = ($item) ->
  return [{lat: 51.5, lon: 0.0, label: 'North Greenwich'}] unless wiki?
  pageMarkers = []
  candidates = $item.siblings()
  if (who = candidates.filter ".marker-source").length
    pageMarkers = pageMarkers.concat div.markerData() for div in who
  pageMarkers

parse = (item, $item) ->
  text = item.text
  # parsing the plugin text in context of any frozen items
  captions = []
  markers = []
  lineupMarkers = null
  pageMarkers = null
  overlays = null
  boundary = null
  weblink = null
  tools = {}

  usePageMarkers = false

  if item.frozen
    markers = markers.concat item.frozen
  for line in text.split /\n/
    if m = marker line
      m.weblink = weblink if weblink?
      markers.push m
    else if m = /^BOUNDARY *(.*)?$/.exec line
      hints = if hint = marker m[1] then [hint] else []
      boundary = markers.concat [] unless boundary?
      boundary = boundary.concat hints
    else if /^LINEUP/.test line
      tools['freeze'] = true
      lineupMarkers = lineup($item)
      if !item.frozen
        markers = markers.concat lineupMarkers
    else if /^PAGE/.test line
      tools['freeze'] = true
      pageMarkers = page($item)
      usePageMarkers = true
      if !item.frozen
        markers = markers.concat pageMarkers
    else if m = /^WEBLINK *(.*)$/.exec line
      weblink = m[1]
    else if m = /^OVERLAY *(.+?) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+)$/.exec line
      overlays = (overlays||[]).concat {url:m[1], bounds:[[m[2],m[3]],[m[4],m[5]]]}
    else if /^LOCATE/.test line
      tools['locate'] = true
    else if /^SEARCH/.test line
      tools['search'] = true
    else
      captions.push resolve(line)

  # remove any duplicate markers
  markers = Array.from(new Set(markers.map(JSON.stringify))).map(JSON.parse)
  lineupMarkers = Array.from(new Set(lineupMarkers.map(JSON.stringify))).map(JSON.parse) if lineupMarkers
  pageMarkers = Array.from(new Set(pageMarkers.map(JSON.stringify))).map(JSON.parse) if pageMarkers

  boundary = markers unless boundary?
  result = {markers, caption: captions.join('<br>'), boundary}
  result.lineupMarkers = lineupMarkers if lineupMarkers
  result.pageMarkers = pageMarkers if pageMarkers
  result.tools = tools if Object.keys(tools).length > 0
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
  {caption, markers, lineupMarkers, pageMarkers, boundary, weblink, overlays, tools} = parse item, $item

  # announce our capability to produce markers in native and geojson format

  $item.addClass 'marker-source'

  showing = []
  $item.get(0).markerData = ->
    opened = showing.filter (s) -> s.leaflet._popup._isOpen
    if opened.length
      marlers = opened.map (s) -> s.marker
    else
      markers = parse(item, $item).markers
    return markers

  $item.get(0).markerGeo = ->
    type: 'FeatureCollection'
    features: parse(item, $item).markers.map(feature)

  if (!$("link[href='https://unpkg.com/leaflet@1.7.1/dist/leaflet.css']").length)
    $('<link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css">').appendTo("head")
  if (!$("link[href='/plugins/map/map.css']").length)
    $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo("head")

  wiki.getScript "https://unpkg.com/leaflet@1.7.1/dist/leaflet.js", ->

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
      wiki.doPlugin $item.empty(), item

    # add locate control
    if tools?.locate
      if (!$("link[href='https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css']").length)
        $('<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">').appendTo("head")
      if (!$("link[href='https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.72.0/dist/L.Control.Locate.min.css'"))
        $('<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.72.0/dist/L.Control.Locate.min.css">').appendTo("head")
      wiki.getScript "https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.72.0/dist/L.Control.Locate.min.js", ->
        L.control.locate({
          position: 'topleft'
          flyTo: true
          drawCircle: true
          drawMarker: false}).addTo(map)

    # add search control
    if tools?.search
      if (!$("link[href='https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css']").length)
        $('<link rel="stylesheet" href="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css" />').appendTo("head")  
      wiki.getScript "https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.js", ->
        geocoder = L.Control.geocoder({
          defaultMarkGeocode: false
        }).on('markgeocode', (e) ->
          new L.marker([e.geocode.center.lat,e.geocode.center.lng],{
            title: e.geocode.name
          }).addTo(map)
          boundary.push {
            lat: e.geocode.center.lat
            lon: e.geocode.center.lng}
          if boundary.length > 1
            bounds = new L.LatLngBounds [ [p.lat, p.lon] for p in boundary ]
            bounds = bounds.pad(0.3)
            map.flyToBounds bounds
          else if boundary.length == 1
            p = boundary[0]
            map.flyTo([p.lat, p.lon], item.zoom || 13)
          item.text +="\n#{e.geocode.center.lat.toFixed 7}, #{e.geocode.center.lng.toFixed 7} #{e.geocode.name}"
          update()
          ).addTo(map)

    #
    if tools?.freeze
      freezeControl = L.Control.extend({
        options: {
          position: 'topright'
        }

        onAdd: (map) ->
          container = L.DomUtil.create('div', 'leaflet-bar leaflet-control')
          container.innerHTML = """
          <a class="leaflet-bar-part leaflet-bar-part-single" href="#" style="outline: currentcolor none medium;">
            <span style=#{item.frozen? 'color: black;' : 'color: blue;'}>❄︎</span>
          </a>
          """

          newMarkers = []
          newMarkerGroup = null
          
          container.onclick = (e) ->
            if e.shiftKey
              e.preventDefault()
              e.stopPropagation()
              if item.frozen
                delete item.frozen
                update()
            else
              if usePageMarkers
                pageMarkers = page($item)
              toFreeze = []
              if item.frozen
                toFreeze = Array.from(new Set(item.frozen.concat(lineupMarkers||pageMarkers).map(JSON.stringify))).map(JSON.parse)
              else
                toFreeze = lineupMarkers||pageMarkers
              # only update if there realy is something new to freeze or it has changed...
              if (item.frozen and (toFreeze.length != item.frozen.length)) or (!item.frozen and toFreeze.length > 0)
              #(!item.frozen and toFreeze.length > 0) or toFreeze.length != item.frozen.length
                item.frozen = toFreeze
                update()
          
          # mouse over will show any extra markers that will be added on a re-freeze.
          container.addEventListener 'mouseenter', (e) ->
            if usePageMarkers
              pageMarkers = page($item)
            m = new Set(markers.map(JSON.stringify))
            l = new Set((lineupMarkers||pageMarkers).map(JSON.stringify))
            newMarkers = Array.from(new Set(Array.from(l).filter((x) -> !m.has(x)))).map(JSON.parse)
            if newMarkers.length > 0
              newMarkerGroup = L.layerGroup().addTo(map)
              newMarkers.forEach (mark) ->
                L.marker([mark.lat, mark.lon]).addTo(newMarkerGroup)
              tmpBoundary = boundary.concat newMarkers
              bounds = new L.LatLngBounds [ [p.lat, p.lon] for p in tmpBoundary ]
              bounds = bounds.pad(0.3)
              map.flyToBounds bounds

          container.addEventListener 'mouseleave', (e) ->
            if newMarkers.length > 0
              newMarkerGroup.remove()
              if boundary.length > 1
                bounds = new L.LatLngBounds [ [p.lat, p.lon] for p in boundary ]
                bounds = bounds.pad(0.3)
                map.flyToBounds bounds
              else if boundary.length == 1
                p = boundary[0]
                map.flyTo([p.lat, p.lon], item.zoom || 13)
              else
                map.flyTo(item.latlng || item.latLng || [40.735383, -73.984655], item.zoom || 13)
          
          return container

        onRemove: (map) ->
          # Nothing to do here...

      })
      map.addControl(new freezeControl())


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
      bounds = bounds.pad(0.3)
      map.fitBounds bounds
    else if boundary.length == 1
      p = boundary[0]
      map.setView([p.lat, p.lon], item.zoom || 13)
    else
      map.setView(item.latlng || item.latLng || [40.735383, -73.984655], item.zoom || 13)

    # announce our capability to produce a region

    $item.addClass 'region-source'

    $item.get(0).regionData = ->
      region = map.getBounds()
      return {
        north: region.getNorth()
        south: region.getSouth()
        east: region.getEast()
        west: region.getWest()
      }


bind = ($item, item) ->
  $item.on 'dblclick', () ->
    wiki.textEditor $item, item


window.plugins.map = {emit, bind} if window?
module.exports = {marker, parse} if module?
