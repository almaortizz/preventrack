import { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// Icono por defecto de Leaflet cargado desde su CDN (evita rutas rotas con Vite).
const iconoUbicacion = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

const CENTRO_POR_DEFECTO = [19.0414, -98.2063] // Puebla

// Selector de ubicación: búsqueda por dirección + mapa con clic/arrastre +
// botón de "mi ubicación". Es controlado por el formulario que lo usa.
//
// value:    { direccion, municipio, latitud, longitud }
// onChange: recibe un objeto parcial, por ejemplo { latitud, longitud }
export default function UbicacionPicker({ value, onChange }) {
  const mapaRef = useRef(null)
  const mapaInstanciaRef = useRef(null)
  const marcadorRef = useRef(null)
  const onChangeRef = useRef(onChange)
  const [mensaje, setMensaje] = useState('')
  const [buscandoDireccion, setBuscandoDireccion] = useState(false)
  const [buscandoUbicacion, setBuscandoUbicacion] = useState(false)

  useEffect(() => {
    onChangeRef.current = onChange
  }, [onChange])

  // Crea el mapa al montar y lo destruye al desmontar.
  useEffect(() => {
    const lat = parseFloat(value.latitud)
    const lng = parseFloat(value.longitud)
    const tienePunto = !isNaN(lat) && !isNaN(lng)

    const mapa = L.map(mapaRef.current).setView(
      tienePunto ? [lat, lng] : CENTRO_POR_DEFECTO,
      tienePunto ? 16 : 12,
    )
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(mapa)

    mapa.on('click', (e) => {
      onChangeRef.current({
        latitud: e.latlng.lat.toFixed(7),
        longitud: e.latlng.lng.toFixed(7),
      })
    })

    mapaInstanciaRef.current = mapa
    setTimeout(() => mapa.invalidateSize(), 100)

    return () => {
      mapa.remove()
      mapaInstanciaRef.current = null
      marcadorRef.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Mueve (o crea) el marcador cuando cambian las coordenadas.
  useEffect(() => {
    const mapa = mapaInstanciaRef.current
    if (!mapa) return

    const lat = parseFloat(value.latitud)
    const lng = parseFloat(value.longitud)
    if (isNaN(lat) || isNaN(lng)) {
      if (marcadorRef.current) {
        marcadorRef.current.remove()
        marcadorRef.current = null
      }
      return
    }

    if (marcadorRef.current) {
      marcadorRef.current.setLatLng([lat, lng])
    } else {
      const marcador = L.marker([lat, lng], {
        icon: iconoUbicacion,
        draggable: true,
      }).addTo(mapa)
      marcador.on('dragend', (e) => {
        const p = e.target.getLatLng()
        onChangeRef.current({
          latitud: p.lat.toFixed(7),
          longitud: p.lng.toFixed(7),
        })
      })
      marcadorRef.current = marcador
    }
    mapa.setView([lat, lng], Math.max(mapa.getZoom(), 16))
  }, [value.latitud, value.longitud])

  async function buscarPorDireccion() {
    if (!value.direccion || !value.direccion.trim()) {
      setMensaje('Escribe primero la dirección para buscarla.')
      return
    }
    const texto = [value.direccion, value.municipio, 'Puebla', 'México']
      .filter(Boolean)
      .join(', ')
    setMensaje('')
    setBuscandoDireccion(true)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=mx&q=${encodeURIComponent(texto)}`,
      )
      const datos = await res.json()
      if (datos.length) {
        onChangeRef.current({
          latitud: Number(datos[0].lat).toFixed(7),
          longitud: Number(datos[0].lon).toFixed(7),
        })
      } else {
        setMensaje('No se encontró esa dirección. Haz clic en el mapa para marcar el punto exacto.')
      }
    } catch {
      setMensaje('No se pudo buscar la dirección. Haz clic en el mapa para marcar el punto.')
    } finally {
      setBuscandoDireccion(false)
    }
  }

  function usarUbicacionActual() {
    if (!navigator.geolocation) {
      setMensaje('Tu navegador no soporta geolocalización.')
      return
    }
    setMensaje('')
    setBuscandoUbicacion(true)
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        onChangeRef.current({
          latitud: pos.coords.latitude.toFixed(7),
          longitud: pos.coords.longitude.toFixed(7),
        })
        setBuscandoUbicacion(false)
      },
      () => {
        setMensaje('No se pudo obtener tu ubicación. Revisa los permisos del navegador.')
        setBuscandoUbicacion(false)
      },
    )
  }

  return (
    <div>
      <label className="block text-sm font-medium text-neutral-700 mb-1">
        Ubicación en el mapa (para rutas y para la app)
      </label>
      <div className="flex gap-2 mb-2">
        <button
          type="button"
          onClick={buscarPorDireccion}
          disabled={buscandoDireccion}
          className="flex-1 bg-primary text-white text-sm font-semibold px-3 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
        >
          {buscandoDireccion ? 'Buscando...' : '🔎 Buscar por dirección'}
        </button>
        <button
          type="button"
          onClick={usarUbicacionActual}
          disabled={buscandoUbicacion}
          className="flex-1 bg-secondary text-white text-sm font-semibold px-3 py-2 rounded-lg hover:bg-secondary/90 disabled:opacity-50"
        >
          {buscandoUbicacion ? 'Obteniendo...' : '📍 Mi ubicación'}
        </button>
      </div>
      <div
        ref={mapaRef}
        className="w-full h-56 rounded-lg border border-neutral-200 mb-2 z-0"
      />
      <p className="text-xs text-neutral-400 mb-2">
        Haz clic en el mapa para marcar el punto exacto del cliente (el pin también se puede arrastrar).
      </p>
      <div className="flex gap-2">
        <input
          type="number"
          step="any"
          placeholder="Latitud"
          value={value.latitud}
          onChange={(e) => onChange({ latitud: e.target.value })}
          className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
        />
        <input
          type="number"
          step="any"
          placeholder="Longitud"
          value={value.longitud}
          onChange={(e) => onChange({ longitud: e.target.value })}
          className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
        />
      </div>
      {mensaje && <p className="text-red-600 text-xs mt-1">{mensaje}</p>}
    </div>
  )
}
