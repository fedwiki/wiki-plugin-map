###
 * Federated Wiki : Map Plugin
 *
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-plugin-map/blob/master/LICENSE.txt
###

window.plugins.map =

  bind: (div, item) ->
  emit: (div, item) ->
    if (!$("link[href='http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css']").length)
      $('<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css">').appendTo("head")
    if (!$("link[href='/plugins/map/map.css']").length)
      $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo("head")
    wiki.getScript "http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.js", ->
      mapId = 'map-' + uniqueId()
      figure = $("<figure></figure>")
        .mouseout (e) ->
          # focusout does not seem fire, so using mouseout...

          # ignore if we are not editing
          return if !figure.hasClass 'mapEditing'

          # ignore if not for the outer container
          return unless $(e.relatedTarget).hasAnyClass("page", "story")

          ###
          Bilbao
          ---

          lat 43.2607
          long -2.9395
          title Somewhere in Bilbao

          lat 43.2607
          long -2.9395
          title Somewhere in Bilbao
          ###

          console.log item

          # see anything has changed - don't want to save if it has not
          if !map.getCenter().equals(item.latlng) || item.zoom isnt map.getZoom() || item.text isnt $("textarea").val()
            # something has been changed, so lets save
            item.latlng = map.getCenter()
            item.zoom = map.getZoom()
            item.text = $("textarea").val()

            # save the new position, and caption, but only if
            plugins.map.save(div, item)

          figure.find("textarea").replaceWith( "<figcaption>#{wiki.resolveLinks(item.text)}</figcaption>" )

          figure.removeClass 'mapEditing'

          null

        .dblclick ->
          # Double clicking on either map or caption will switch into edit mode.

          # ignore dblclick if we are already editing.
          return if figure.hasClass 'mapEditing'
          figure.addClass 'mapEditing'

          # replace the caption with a textarea
          textarea = $("<textarea>#{original = item.text ? ''}</textarea>")
          figure.find("figcaption").replaceWith( textarea )

          null

        .bind 'keydown', (e) ->
          if (e.altKey || e.ctlKey || e.metaKey) and e.which == 83 #alt-s
            figure.mouseout()
            return false
          if (e.altKey || e.ctlKey || e.metaKey) and e.which == 73 #alt-i
            # note: only works if clicked in the textarea
            e.preventDefault()
            page = $(e.target).parents('.page') unless e.shiftKey
            wiki.doInternalLink "about map plugin", page
            return false

       .bind 'focusout', (e) ->
         console.log 'event target: ', e.target
         e.stopPropagation if e.target.class == 'leaflet-tile' || 'leaflet-container'

      div.html figure

      figure.append "<div id='" + mapId + "' style='height: 300px;'></div>"

      map = L.map(mapId).setView(item.latlng || [40.735383, -73.984655], item.zoom || 13)

      # disable double click zoom - so we can use double click to start edit
      map.doubleClickZoom.disable()

      L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map)

      points = []
      mapTitle = "Map Caption"
      parser = (text) ->
        console.log text
        lines = text.split '\n'
        mapTitle = lines[0]
        for line, i in lines
          if i != 0
            split = line.split(">>")
            if split.length > 1 # and split[1] not undefined
              point={}
              point.title = split[0]
              point.lat = parseFloat split[1].split("/")[0].trim()
              point.lng = parseFloat split[1].split("/")[1].trim()
              console.log point
              points.push point

      console.log parser(item.text)


      # any old maps will not define item.text, so set a default value
      figure.append "<figcaption>#{wiki.resolveLinks(mapTitle)}</figcaption>"

      # add markers on the map
      for p in points
        L.marker([p.lat, p.lng]).addTo(map);

  save: (div, item) ->
    wiki.pageHandler.put div.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item


uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

$.fn.hasAnyClass = ->
  i = 0

  while i < arguments.length
    return true  if @hasClass(arguments[i])
    i++
  false
