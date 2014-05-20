uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

window.plugins.map =

  bind: (div, item) ->
  emit: (div, item) ->
    if (!$("link[href='http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css']").length)
      $('<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css">').appendTo("head")
    if (!$("link[href='/plugins/map/map.css']").length)
      $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo("head")
    wiki.getScript "http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.js", ->
      mapId = 'map-' + uniqueId()
      div.append "<figure id='" + mapId + "' style='height: 300px;'></figure>"
      
      map = L.map(mapId).setView(item.latlng || [40.735383, -73.984655], item.zoom || 13)

      # disable double click zoom
      map.doubleClickZoom.disable()

      L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map)

      # this will go, to allow the map to be explored without changing content - unless in edit.
      #map.on 'blur', (e) ->
      #  item.latlng = map.getCenter()
      #  item.zoom = map.getZoom()
      #  plugins.map.save(div, item)

      # any old maps will not define item.text, so set a default value
      if !item.text
        item.text = "Map Caption"

      div.append "<figcaption>#{wiki.resolveLinks(item.text)}</figcaption>"

      div.dblclick -> plugins.map.mapEditor map, div, item

  mapEditor: (map, div, item) ->
    return if div.hasClass 'mapEditing'
    div.addClass 'mapEditing'
    textarea = $("<textarea>#{original = item.text ? ''}</textarea>")

    $("figcaption").replaceWith( textarea )

    div.on 'focusout', (e) ->
      # make sure the map is being edited
      return if !div.hasClass 'mapEditing'

      item.latlng = map.getCenter()
      item.zoom = map.getZoom()
      item.text = $("textarea").val()

      plugins.map.save(div, item)

      $("textarea").replaceWith( "<figcaption>#{wiki.resolveLinks(item.text)}</figcaption>" )

      div.removeClass 'mapEditing'











        
  save: (div, item) ->
    wiki.pageHandler.put div.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item