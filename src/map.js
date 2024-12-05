/*
 * Federated Wiki : Map Plugin
 *
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-plugin-map/blob/master/LICENSE.txt
 */

// which markers types
let usePageMarkers = false
let useLineupMarkers = false

const escape = line => {
  return line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

const resolve = text => {
  if (typeof wiki !== 'undefined') {
    return wiki.resolveLinks(text, escape)
  } else {
    return escape(text)
      .replace(/\[\[.*?\]\]/g, '<internal>')
      .replace(/\[.*?\]/g, '<external>')
  }
}

const htmlDecode = escapedText => {
  const doc = new DOMParser().parseFromString(escapedText, 'text/html')
  return doc.documentElement.textContent
}

const marker = text => {
  const deg = m => {
    const num = +m[0] + m[1] / 60 + (m[2] || 0) / 3600
    return m[3].match(/[SW]/i) ? -num : num
  }
  const decimal = /^(-?\d{1,3}\.?\d*)[, ] *(-?\d{1,3}\.?\d*)\s*(.*)$/
  const nautical = /^(\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([NS]) (\d{1,3})°(\d{1,2})'(\d*\.\d*)?"?([EW]) (.*)$/i
  let m
  if ((m = decimal.exec(text))) {
    return { lat: +m[1], lon: +m[2], label: resolve(m[3]) }
  }
  if ((m = nautical.exec(text))) {
    return { lat: deg(m.slice(1, 5)), lon: deg(m.slice(5, 9)), label: resolve(m[9]) }
  }
  return null
}

const lineup = $item => {
  if (typeof wiki == 'undefined') {
    return [{ lat: 51.5, lon: 0.0, label: 'North Greenwich' }]
  }
  let lineupMarkers = []
  const candidates = $('.item:lt(' + $('.item').index($item) + ')')
  const who = candidates.filter('.marker-source')
  if (who.length) {
    for (const div of who) {
      lineupMarkers = lineupMarkers.concat(div.markerData())
    }
  }
  return lineupMarkers
}

const page = $item => {
  if (!wiki) {
    return [{ lat: 51.5, lon: 0.0, label: 'North Greenwich' }]
  }
  let pageMarkers = []
  const candidates = $item.siblings()
  const who = candidates.filter('.marker-source')
  if (who.length) {
    for (const div of who) {
      pageMarkers = pageMarkers.concat(div.markerData())
    }
  }
  return pageMarkers
}

const parse = (item, $item) => {
  const text = item.text
  // parsing the plugin text in context of any frozen items
  const captions = []
  let markers = []
  let lineupMarkers = null
  let pageMarkers = null
  let overlays = null
  let boundary = null
  let weblink = null
  const tools = {}

  usePageMarkers = false
  useLineupMarkers = false

  if (item.frozen) {
    markers = markers.concat(item.frozen)
  }
  for (const line of text.split(/\n/)) {
    let m
    if ((m = marker(line))) {
      if (weblink) m.weblink = weblink
      markers.push(m)
    } else if ((m = /^BOUNDARY *(.*)?$/.exec(line))) {
      const hints = m[1] ? [marker(m[1])] : []
      if (!boundary) boundary = [...markers]
      boundary = boundary.concat(hints)
    } else if (/^LINEUP/.test(line)) {
      tools['freeze'] = true
      useLineupMarkers = true
      if (!item.frozen) {
        lineupMarkers = lineup($item)
        markers = markers.concat(lineupMarkers)
      }
    } else if (/^PAGE/.test(line)) {
      tools['freeze'] = true
      usePageMarkers = true
      if (!item.frozen) {
        pageMarkers = page($item)
        markers = markers.concat(pageMarkers)
      }
    } else if ((m = /^WEBLINK *(.*)$/.exec(line))) {
      weblink = m[1]
    } else if (
      (m = /^OVERLAY *(.+?) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+) ([+-]?\d+\.\d+), ?([+-]?\d+\.\d+)$/.exec(line))
    ) {
      overlays = (overlays || []).concat({
        url: m[1],
        bounds: [
          [m[2], m[3]],
          [m[4], m[5]],
        ],
      })
    } else if (/^LOCATE/.test(line)) {
      tools['locate'] = true
    } else if (/^SEARCH/.test(line)) {
      tools['search'] = true
    } else {
      captions.push(resolve(line))
    }
  }

  // remove any duplicate markers
  markers = Array.from(new Set(markers.map(JSON.stringify))).map(JSON.parse)
  if (lineupMarkers) lineupMarkers = Array.from(new Set(lineupMarkers.map(JSON.stringify))).map(JSON.parse)
  if (pageMarkers) pageMarkers = Array.from(new Set(pageMarkers.map(JSON.stringify))).map(JSON.parse)

  if (!boundary) boundary = markers
  const result = { markers, caption: captions.join('<br>'), boundary }
  if (lineupMarkers) result.lineupMarkers = lineupMarkers
  if (pageMarkers) result.pageMarkers = pageMarkers
  if (Object.keys(tools).length > 0) result.tools = tools
  if (weblink) result.weblink = weblink
  if (overlays) result.overlays = overlays
  return result
}

const feature = marker => ({
  type: 'Feature',
  geometry: {
    type: 'Point',
    coordinates: [marker.lon, marker.lat],
    properties: {
      label: marker.label,
    },
  },
})

const emit = ($item, item) => {
  let { caption, markers, lineupMarkers, pageMarkers, boundary, weblink, overlays, tools } = parse(item, $item)

  // announce our capability to produce markers in native and geojson format

  $item.addClass('marker-source')

  const showing = []
  $item.get(0).markerData = () => {
    const opened = showing.filter(s => s.leaflet._popup._isOpen)
    return opened.length ? opened.map(s => s.marker) : markers
  }

  $item.get(0).markerGeo = () => ({
    type: 'FeatureCollection',
    features: markers.map(feature),
  })

  if (!$("link[href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css']").length) {
    $(
      '<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" >',
    ).appendTo('head')
  }
  if (!$("link[href='/plugins/map/map.css']").length) {
    $('<link rel="stylesheet" href="/plugins/map/map.css" type="text/css">').appendTo('head')
  }

  wiki.getScript('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js', () => {
    const mapId = `map-${Math.floor(Math.random() * 1000000)}`

    $item.append(`
      <figure style="padding: 8px;">
        <div id="${mapId}" style='height: 300px;'></div>
        <p class="caption">${caption}</p>
      </figure>
    `)

    const map = L.map(mapId, {
      scrollWheelZoom: false,
    })

    const update = () => {
      wiki.pageHandler.put($item.parents('.page:first'), {
        type: 'edit',
        id: item.id,
        item: item,
      })
      wiki.doPlugin($item.empty(), item)
    }

    // add locate control
    if (tools?.locate) {
      if (
        !$("link[href='https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.79.0/dist/L.Control.Locate.min.css']")
          .length
      ) {
        $(
          '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.79.0/dist/L.Control.Locate.min.css">',
        ).appendTo('head')
      }
      wiki.getScript('https://cdn.jsdelivr.net/npm/leaflet.locatecontrol@0.79.0/dist/L.Control.Locate.min.js', () => {
        L.control
          .locate({
            position: 'topleft',
            flyTo: true,
            drawCircle: true,
            drawMarker: false,
          })
          .addTo(map)
      })
    }

    // add search control
    if (tools?.search) {
      if (!$("link[href='https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css']").length) {
        $(
          '<link rel="stylesheet" href="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css" />',
        ).appendTo('head')
      }
      wiki.getScript('https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.js', () => {
        const geocoder = L.Control.geocoder({
          defaultMarkGeocode: false,
        })
          .on('markgeocode', e => {
            new L.marker([e.geocode.center.lat, e.geocode.center.lng], {
              title: e.geocode.name,
            }).addTo(map)
            boundary.push({
              lat: e.geocode.center.lat,
              lon: e.geocode.center.lng,
            })
            if (boundary.length > 1) {
              const bounds = new L.LatLngBounds(boundary.map(p => [p.lat, p.lon]))
              map.flyToBounds(bounds.pad(0.3))
            } else if (boundary.length === 1) {
              const p = boundary[0]
              map.flyTo([p.lat, p.lon], item.zoom || 13)
            }
            item.text += `\n${e.geocode.center.lat.toFixed(7)}, ${e.geocode.center.lng.toFixed(7)} ${e.geocode.name}`
            update()
          })
          .addTo(map)
      })
    }

    if (tools?.freeze) {
      const FreezeControl = L.Control.extend({
        options: {
          position: 'topright',
        },

        onAdd: map => {
          const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control')
          container.innerHTML = `
            <a class="leaflet-bar-part leaflet-bar-part-single" href="#" style="outline: currentcolor none medium;">
              <span style="${item.frozen ? 'color: #5792FF;' : 'color: blue;'}">❄︎</span>
            </a>
          `

          let newMarkers = []
          let newMarkerGroup = null

          container.onclick = e => {
            if (e.shiftKey) {
              e.preventDefault()
              e.stopPropagation()
              if (item.frozen) {
                delete item.frozen
                update()
              }
            } else {
              if (usePageMarkers) {
                pageMarkers = page($item)
              }
              let toFreeze = []
              if (item.frozen) {
                toFreeze = Array.from(
                  new Set(item.frozen.concat(lineupMarkers || pageMarkers).map(JSON.stringify)),
                ).map(JSON.parse)
              } else {
                toFreeze = lineupMarkers || pageMarkers
              }
              if ((item.frozen && toFreeze.length !== item.frozen.length) || (!item.frozen && toFreeze.length > 0)) {
                item.frozen = toFreeze
                update()
              }
            }
          }

          container.addEventListener('mouseenter', e => {
            if (usePageMarkers) {
              pageMarkers = page($item)
            }
            if (useLineupMarkers) {
              lineupMarkers = lineup($item)
            }
            const m = new Set(markers.map(JSON.stringify))
            const l = new Set((lineupMarkers || pageMarkers).map(JSON.stringify))
            newMarkers = Array.from(new Set(Array.from(l).filter(x => !m.has(x)))).map(JSON.parse)
            if (newMarkers.length > 0) {
              newMarkerGroup = L.layerGroup().addTo(map)
              newMarkers.forEach(mark => {
                L.marker([mark.lat, mark.lon]).addTo(newMarkerGroup)
              })
              const tmpBoundary = boundary.concat(newMarkers)
              const bounds = new L.LatLngBounds(tmpBoundary.map(p => [p.lat, p.lon]))
              map.flyToBounds(bounds.pad(0.3))
            }
          })

          container.addEventListener('mouseleave', e => {
            if (newMarkers.length > 0) {
              newMarkerGroup.remove()
              if (boundary.length > 1) {
                const bounds = new L.LatLngBounds(boundary.map(p => [p.lat, p.lon]))
                map.flyToBounds(bounds.pad(0.3))
              } else if (boundary.length === 1) {
                const p = boundary[0]
                map.flyTo([p.lat, p.lon], item.zoom || 13)
              } else {
                map.flyTo(item.latlng || item.latLng || [40.735383, -73.984655], item.zoom || 13)
              }
            }
          })

          return container
        },

        onRemove: map => {
          // Nothing to do here...
        },
      })
      map.addControl(new FreezeControl())
    }

    // stop dragging the map from propagating and dragging the page item.
    const mapDiv = L.DomUtil.get(mapId)
    L.DomEvent.disableClickPropagation(mapDiv)

    map.doubleClickZoom.disable()
    map.on('dblclick', e => {
      if (e.originalEvent.shiftKey) {
        e.originalEvent.stopPropagation()
        new L.marker(e.latlng).addTo(map)
        item.text += `\n${e.latlng.lat.toFixed(7)}, ${e.latlng.lng.toFixed(7)}`
        update()
      }
    })

    // select tiles, default to OSM
    const tile = item.tile || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
    const tileCredits =
      item.tileCredits || '© <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

    L.tileLayer(tile, {
      attribution: tileCredits,
    }).addTo(map)

    // add specialized map overlays
    ;(overlays || []).forEach(o => {
      L.imageOverlay(o.url, o.bounds, { opacity: 0.6, interactive: true }).addTo(map)
    })

    const openWeblink = e => {
      const link = e.target.options.weblink
      if (!link) return
      window.open(link.replace(/\{LAT}/, e.latlng.lat).replace(/\{(LON|LNG)}/, e.latlng.lng))
    }

    const showMarkers = markers => {
      if (!markers) return
      markers.forEach(p => {
        const markerLabel = htmlDecode(wiki.resolveLinks(p.label))
        const mkr = L.marker([p.lat, p.lon], { weblink: p.weblink || weblink })
          .on('dblclick', openWeblink)
          .bindPopup(markerLabel)
          .openPopup()
          .addTo(map)
        showing.push({ leaflet: mkr, marker: p })
      })
    }

    // add markers on the map
    showMarkers(markers)

    // center map on markers or item properties
    if (boundary.length > 1) {
      const bounds = new L.LatLngBounds(boundary.map(p => [p.lat, p.lon]))
      map.fitBounds(bounds.pad(0.3))
    } else if (boundary.length === 1) {
      const p = boundary[0]
      map.setView([p.lat, p.lon], item.zoom || 13)
    } else {
      map.setView(item.latlng || item.latLng || [40.735383, -73.984655], item.zoom || 13)
    }

    // announce our capability to produce a region

    $item.addClass('region-source')

    $item.get(0).regionData = () => {
      const region = map.getBounds()
      return {
        north: region.getNorth(),
        south: region.getSouth(),
        east: region.getEast(),
        west: region.getWest(),
      }
    }
  })
}

const bind = ($item, item) => {
  $item.on('dblclick', () => {
    wiki.textEditor($item, item)
  })
}

if (typeof window !== 'undefined') {
  window.plugins.map = { emit, bind }
}

export const map = typeof window == 'undefined' ? { marker, parse } : undefined
