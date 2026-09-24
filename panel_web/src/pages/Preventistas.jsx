import { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import client from '../api/client'

const ROL_COLABORADOR = 2

const emptyForm = {
  nombre: '',
  apellidos: '',
  edad: '',
  telefono: '',
  direccion: '',
  color: '#2E4E9E',
  usuario: '',
  password: '',
  estado: 'activo',
}

// Icono por defecto de Leaflet, cargado desde su CDN (evita el problema
// típico de rutas rotas al usar Leaflet dentro de un proyecto con Vite).
const iconoPreventista = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

function validarTelefono(telefono) {
  if (!telefono) return true
  return /^\d{10}$/.test(telefono)
}

function validarPassword(password, esRequerida) {
  if (!password) return !esRequerida
  return /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$/.test(password)
}

function primerDiaDelMes() {
  const hoy = new Date()
  const primero = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  return primero.toISOString().slice(0, 10)
}

function hoyISO() {
  return new Date().toISOString().slice(0, 10)
}

function lunesDeEstaSemana() {
  const hoy = new Date()
  const dia = hoy.getDay()
  const diff = hoy.getDate() - dia + (dia === 0 ? -6 : 1)
  const lunes = new Date(hoy)
  lunes.setDate(diff)
  return lunes.toISOString().slice(0, 10)
}

export default function Preventistas() {
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [mostrarPassword, setMostrarPassword] = useState(false)
  const [mostrarDireccion, setMostrarDireccion] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')

  // Historial
  const [historialAbierto, setHistorialAbierto] = useState(null) // preventista seleccionado
  const [historialVentas, setHistorialVentas] = useState([])
  const [historialLoading, setHistorialLoading] = useState(false)
  const [cuotaActual, setCuotaActual] = useState(null)
  const [exportandoHistorial, setExportandoHistorial] = useState(false)

  // Exportar todos (general, coloreado por preventista)
  const [exportandoTodos, setExportandoTodos] = useState(false)

  // Monitoreo
  const [monitoreoAbierto, setMonitoreoAbierto] = useState(false)
  const [monitoreoData, setMonitoreoData] = useState([])
  const [monitoreoLoading, setMonitoreoLoading] = useState(false)

  // Mapa en tiempo real (dentro del modal de Monitoreo)
  const mapaContenedorRef = useRef(null)
  const mapaInstanciaRef = useRef(null)
  const marcadoresRef = useRef([])

  function cargar() {
    setLoading(true)
    client
      .get(`/usuarios?rol_id=${ROL_COLABORADOR}`)
      .then((res) => setPreventistas(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de preventistas.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    cargar()
  }, [])

  function abrirNuevo() {
    setForm(emptyForm)
    setEditingId(null)
    setFormError('')
    setShowForm(true)
  }

  function abrirEditar(p) {
    setForm({
      nombre: p.nombre ?? '',
      apellidos: p.apellidos ?? '',
      edad: p.edad ?? '',
      telefono: p.telefono ?? '',
      direccion: p.direccion ?? '',
      color: p.color || '#2E4E9E',
      usuario: p.usuario ?? '',
      password: '',
      estado: p.estado ?? 'activo',
    })
    setEditingId(p.id)
    setFormError('')
    setShowForm(true)
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')

    if (!validarTelefono(form.telefono)) {
      setFormError('El teléfono debe tener exactamente 10 dígitos.')
      return
    }

    if (!validarPassword(form.password, !editingId)) {
      setFormError(
        'La contraseña debe tener al menos 8 caracteres, con mayúscula, minúscula, número y símbolo.',
      )
      return
    }

    const payload = { ...form, rol_id: ROL_COLABORADOR }
    if (editingId && !payload.password) delete payload.password

    try {
      if (editingId) {
        await client.put(`/usuarios/${editingId}`, payload)
      } else {
        await client.post('/usuarios', payload)
      }
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al guardar el preventista.',
      )
    }
  }

  async function toggleEstado(p) {
    try {
      if (p.estado === 'activo') {
        await client.post(`/usuarios/${p.id}/bloquear`)
      } else {
        await client.post(`/usuarios/${p.id}/desbloquear`)
      }
      cargar()
    } catch {
      alert('No se pudo cambiar el estado del preventista.')
    }
  }

  async function eliminar(p) {
    if (!confirm(`¿Eliminar a "${p.nombre} ${p.apellidos}"?`)) return
    try {
      await client.delete(`/usuarios/${p.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar el preventista.')
    }
  }

  // --- Historial ---

  async function abrirHistorial(p) {
    setHistorialAbierto(p)
    setHistorialLoading(true)
    setCuotaActual(null)
    try {
      const [resVentas, resCuotas] = await Promise.all([
        client.get('/ventas', {
          params: {
            preventista_vendedor_id: p.id,
            fecha_inicio: primerDiaDelMes(),
            fecha_fin: hoyISO(),
            per_page: 500,
          },
        }),
        client.get('/cuotas', { params: { usuario_id: p.id } }),
      ])
      setHistorialVentas(resVentas.data.data ?? [])

      const hoy = hoyISO()
      const cuotaVigente = (resCuotas.data.data ?? []).find(
        (c) => c.fecha_inicio_semana <= hoy && c.fecha_fin_semana >= hoy,
      )
      setCuotaActual(cuotaVigente || null)
    } catch {
      setHistorialVentas([])
    } finally {
      setHistorialLoading(false)
    }
  }

  function cerrarHistorial() {
    setHistorialAbierto(null)
    setHistorialVentas([])
    setCuotaActual(null)
  }

  function resumenPeriodo(desdeISO) {
    const ventasFiltradas = historialVentas.filter((v) => {
      if (v.estado === 'cancelado') return false
      const fecha = v.fecha_hora.slice(0, 10)
      return fecha >= desdeISO
    })
    const total = ventasFiltradas.reduce((acc, v) => acc + Number(v.total), 0)
    return { cantidad: ventasFiltradas.length, total }
  }

  const resumenHoy = resumenPeriodo(hoyISO())
  const resumenSemana = resumenPeriodo(lunesDeEstaSemana())
  const resumenMes = resumenPeriodo(primerDiaDelMes())

  async function exportarHistorial() {
    if (!historialAbierto) return
    setExportandoHistorial(true)
    try {
      const res = await client.get('/reportes/ventas', {
        params: {
          preventista_vendedor_id: historialAbierto.id,
          fecha_inicio: primerDiaDelMes(),
          fecha_fin: hoyISO(),
          colorear_por_preventista: 1,
        },
        responseType: 'blob',
      })
      const nombreArchivo =
        res.headers['content-disposition']?.match(/filename="?([^"]+)"?/)?.[1] ||
        'reporte_ventas.xlsx'
      const blobUrl = window.URL.createObjectURL(new Blob([res.data]))
      const enlace = document.createElement('a')
      enlace.href = blobUrl
      enlace.download = nombreArchivo
      document.body.appendChild(enlace)
      enlace.click()
      enlace.remove()
      window.URL.revokeObjectURL(blobUrl)
    } catch {
      alert('No se pudo exportar el reporte.')
    } finally {
      setExportandoHistorial(false)
    }
  }

  // --- Exportar todos (general, coloreado por preventista) ---

  async function exportarTodosGeneral() {
    setExportandoTodos(true)
    try {
      const res = await client.get('/reportes/ventas', {
        params: { colorear_por_preventista: 1 },
        responseType: 'blob',
      })
      const nombreArchivo =
        res.headers['content-disposition']?.match(/filename="?([^"]+)"?/)?.[1] ||
        'reporte_ventas_general.xlsx'
      const blobUrl = window.URL.createObjectURL(new Blob([res.data]))
      const enlace = document.createElement('a')
      enlace.href = blobUrl
      enlace.download = nombreArchivo
      document.body.appendChild(enlace)
      enlace.click()
      enlace.remove()
      window.URL.revokeObjectURL(blobUrl)
    } catch {
      alert('No se pudo exportar el reporte general.')
    } finally {
      setExportandoTodos(false)
    }
  }

  // --- Monitoreo ---

  async function cargarMonitoreo() {
    try {
      const res = await client.get('/monitoreo')
      setMonitoreoData(res.data ?? [])
    } catch {
      setMonitoreoData([])
    }
  }

  async function abrirMonitoreo() {
    setMonitoreoAbierto(true)
    setMonitoreoLoading(true)
    await cargarMonitoreo()
    setMonitoreoLoading(false)
  }

  function cerrarMonitoreo() {
    setMonitoreoAbierto(false)
    setMonitoreoData([])
  }

  // Refresca los datos de monitoreo (incluye ubicaciones) cada 30 segundos
  // mientras el modal esté abierto.
  useEffect(() => {
    if (!monitoreoAbierto) return
    const intervalo = setInterval(() => {
      cargarMonitoreo()
    }, 30000)
    return () => clearInterval(intervalo)
  }, [monitoreoAbierto])

  // Inicializa el mapa de Leaflet cuando se abre el modal, y lo destruye
  // cuando se cierra.
  useEffect(() => {
    if (monitoreoAbierto && mapaContenedorRef.current && !mapaInstanciaRef.current) {
      mapaInstanciaRef.current = L.map(mapaContenedorRef.current).setView(
        [19.0414, -98.2063],
        12,
      )
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19,
      }).addTo(mapaInstanciaRef.current)
    }

    if (!monitoreoAbierto && mapaInstanciaRef.current) {
      mapaInstanciaRef.current.remove()
      mapaInstanciaRef.current = null
      marcadoresRef.current = []
    }
  }, [monitoreoAbierto])

  // Actualiza los marcadores cada vez que llegan datos nuevos de monitoreo.
  useEffect(() => {
    if (!mapaInstanciaRef.current) return

    marcadoresRef.current.forEach((m) => m.remove())
    marcadoresRef.current = []

    const puntos = []
    monitoreoData.forEach((m) => {
      if (m.ubicacion) {
        const marcador = L.marker([m.ubicacion.latitud, m.ubicacion.longitud], {
          icon: iconoPreventista,
        })
          .addTo(mapaInstanciaRef.current)
          .bindPopup(
            `<b>${m.nombre}</b><br/>${
              m.jornada_activa ? 'Jornada activa' : 'Sin jornada activa'
            }${m.ubicacion.origen === 'en_vivo' ? '<br/>Ubicación en vivo' : '<br/>Ubicación de inicio de jornada'}`,
          )
        marcadoresRef.current.push(marcador)
        puntos.push([m.ubicacion.latitud, m.ubicacion.longitud])
      }
    })

    if (puntos.length) {
      mapaInstanciaRef.current.fitBounds(puntos, { padding: [30, 30], maxZoom: 15 })
    }
  }, [monitoreoData])

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Preventistas</h1>
        <div className="flex gap-3">
          <button
            onClick={() => setMostrarDireccion(!mostrarDireccion)}
            className="border border-neutral-200 text-neutral-600 text-sm font-semibold px-4 py-2 rounded-lg hover:bg-neutral-50"
          >
            {mostrarDireccion ? 'Ocultar dirección' : 'Mostrar dirección'}
          </button>
          <button
            onClick={abrirMonitoreo}
            className="border border-secondary text-secondary text-sm font-semibold px-4 py-2 rounded-lg hover:bg-secondary/10"
          >
            📍 Monitorear preventistas
          </button>
          <button
            onClick={exportarTodosGeneral}
            disabled={exportandoTodos}
            className="border border-neutral-200 text-neutral-600 text-sm font-semibold px-4 py-2 rounded-lg hover:bg-neutral-50 disabled:opacity-50"
          >
            {exportandoTodos ? 'Exportando...' : '⬇ Exportar todos (Excel)'}
          </button>
          <button
            onClick={abrirNuevo}
            className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
          >
            + Nuevo preventista
          </button>
        </div>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Color</th>
              <th className="px-4 py-3">Nombre</th>
              <th className="px-4 py-3">Usuario</th>
              <th className="px-4 py-3">Teléfono</th>
              {mostrarDireccion && <th className="px-4 py-3">Dirección</th>}
              <th className="px-4 py-3">Edad</th>
              <th className="px-4 py-3">Estado</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={mostrarDireccion ? 8 : 7} className="px-4 py-6 text-center text-neutral-400">
                  Cargando...
                </td>
              </tr>
            ) : preventistas.length ? (
              preventistas.map((p) => (
                <tr key={p.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">
                    <span
                      className="inline-block w-4 h-4 rounded-full border border-neutral-200"
                      style={{ backgroundColor: p.color || '#2E4E9E' }}
                    />
                  </td>
                  <td className="px-4 py-3">{p.nombre} {p.apellidos}</td>
                  <td className="px-4 py-3">{p.usuario}</td>
                  <td className="px-4 py-3">{p.telefono || '—'}</td>
                  {mostrarDireccion && <td className="px-4 py-3">{p.direccion || '—'}</td>}
                  <td className="px-4 py-3">{p.edad ?? '—'}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold capitalize ${
                        p.estado === 'activo'
                          ? 'bg-green-100 text-green-700'
                          : 'bg-red-100 text-red-700'
                      }`}
                    >
                      {p.estado}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right space-x-3">
                    <button
                      onClick={() => abrirHistorial(p)}
                      className="text-primary font-medium hover:underline"
                    >
                      Ver historial
                    </button>
                    <button
                      onClick={() => abrirEditar(p)}
                      className="text-secondary font-medium hover:underline"
                    >
                      Editar
                    </button>
                    <button
                      onClick={() => toggleEstado(p)}
                      className="text-amber-600 font-medium hover:underline"
                    >
                      {p.estado === 'activo' ? 'Bloquear' : 'Desbloquear'}
                    </button>
                    <button
                      onClick={() => eliminar(p)}
                      className="text-red-600 font-medium hover:underline"
                    >
                      Eliminar
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={mostrarDireccion ? 8 : 7} className="px-4 py-6 text-center text-neutral-400">
                  No hay preventistas registrados.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Modal nuevo/editar preventista */}
      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-primary mb-4">
              {editingId ? 'Editar preventista' : 'Nuevo preventista'}
            </h2>
            <form onSubmit={guardar} className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Nombre</label>
                  <input
                    type="text"
                    value={form.nombre}
                    onChange={(e) => setForm({ ...form, nombre: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Apellidos</label>
                  <input
                    type="text"
                    value={form.apellidos}
                    onChange={(e) => setForm({ ...form, apellidos: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Edad</label>
                  <input
                    type="number"
                    value={form.edad}
                    onChange={(e) => setForm({ ...form, edad: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Teléfono</label>
                  <input
                    type="text"
                    inputMode="numeric"
                    maxLength={10}
                    value={form.telefono}
                    onChange={(e) =>
                      setForm({ ...form, telefono: e.target.value.replace(/\D/g, '').slice(0, 10) })
                    }
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                    placeholder="10 dígitos"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Dirección</label>
                <input
                  type="text"
                  value={form.direccion}
                  onChange={(e) => setForm({ ...form, direccion: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Color asignado
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="color"
                    value={form.color}
                    onChange={(e) => setForm({ ...form, color: e.target.value })}
                    className="w-12 h-10 rounded-lg border border-neutral-200 cursor-pointer"
                  />
                  <span className="text-sm text-neutral-500">
                    Se usa para identificarlo en el historial y en el reporte de Excel.
                  </span>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Usuario</label>
                <input
                  type="text"
                  value={form.usuario}
                  onChange={(e) => setForm({ ...form, usuario: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Contraseña {editingId && '(dejar vacío para no cambiarla)'}
                </label>
                <div className="relative">
                  <input
                    type={mostrarPassword ? 'text' : 'password'}
                    value={form.password}
                    onChange={(e) => setForm({ ...form, password: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 pr-10 focus:outline-none focus:ring-2 focus:ring-secondary"
                    required={!editingId}
                    minLength={8}
                  />
                  <button
                    type="button"
                    onClick={() => setMostrarPassword(!mostrarPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-600 text-xs font-semibold"
                  >
                    {mostrarPassword ? 'Ocultar' : 'Ver'}
                  </button>
                </div>
                <p className="text-xs text-neutral-400 mt-1">
                  Mínimo 8 caracteres, con mayúscula, minúscula, número y símbolo.
                </p>
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Estado</label>
                <select
                  value={form.estado}
                  onChange={(e) => setForm({ ...form, estado: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                >
                  <option value="activo">Activo</option>
                  <option value="inactivo">Inactivo</option>
                </select>
              </div>

              {formError && <p className="text-red-600 text-sm">{formError}</p>}

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowForm(false)}
                  className="px-4 py-2 rounded-lg text-neutral-600 hover:bg-neutral-100"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="bg-primary text-white font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
                >
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal historial */}
      {historialAbierto && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <span
                  className="inline-block w-4 h-4 rounded-full border border-neutral-200"
                  style={{ backgroundColor: historialAbierto.color || '#2E4E9E' }}
                />
                <h2 className="text-lg font-bold text-primary">
                  Historial — {historialAbierto.nombre} {historialAbierto.apellidos}
                </h2>
              </div>
              <button
                onClick={cerrarHistorial}
                className="text-neutral-400 hover:text-neutral-600 text-xl leading-none"
              >
                ×
              </button>
            </div>

            {historialLoading ? (
              <p className="text-neutral-400 text-center py-8">Cargando...</p>
            ) : (
              <>
                <div className="grid grid-cols-3 gap-3 mb-4">
                  <div className="bg-neutral-50 rounded-lg p-4">
                    <p className="text-xs text-neutral-500 mb-1">Hoy</p>
                    <p className="text-lg font-bold text-neutral-800">${resumenHoy.total.toFixed(2)}</p>
                    <p className="text-xs text-neutral-400">{resumenHoy.cantidad} pedidos</p>
                  </div>
                  <div className="bg-neutral-50 rounded-lg p-4">
                    <p className="text-xs text-neutral-500 mb-1">Esta semana</p>
                    <p className="text-lg font-bold text-neutral-800">${resumenSemana.total.toFixed(2)}</p>
                    <p className="text-xs text-neutral-400">{resumenSemana.cantidad} pedidos</p>
                  </div>
                  <div className="bg-neutral-50 rounded-lg p-4">
                    <p className="text-xs text-neutral-500 mb-1">Este mes</p>
                    <p className="text-lg font-bold text-neutral-800">${resumenMes.total.toFixed(2)}</p>
                    <p className="text-xs text-neutral-400">{resumenMes.cantidad} pedidos</p>
                  </div>
                </div>

                {cuotaActual && (
                  <div className="bg-white border border-neutral-100 rounded-lg p-4 mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <p className="text-sm font-semibold text-neutral-700">
                        Cuota de esta semana
                      </p>
                      <p className="text-sm text-neutral-500">
                        Meta: ${Number(cuotaActual.monto_objetivo).toFixed(2)}
                      </p>
                    </div>
                    <div className="w-full bg-neutral-100 rounded-full h-3 overflow-hidden">
                      <div
                        className={`h-3 rounded-full ${
                          resumenSemana.total >= cuotaActual.monto_objetivo
                            ? 'bg-green-500'
                            : 'bg-secondary'
                        }`}
                        style={{
                          width: `${Math.min(
                            100,
                            (resumenSemana.total / cuotaActual.monto_objetivo) * 100,
                          )}%`,
                        }}
                      />
                    </div>
                    <p className="text-xs text-neutral-400 mt-1">
                      {resumenSemana.total >= cuotaActual.monto_objetivo
                        ? '¡Cuota cumplida esta semana!'
                        : `Faltan $${(cuotaActual.monto_objetivo - resumenSemana.total).toFixed(2)} para cumplir la cuota.`}
                    </p>
                  </div>
                )}

                <div className="flex items-center justify-between mb-2">
                  <h3 className="text-sm font-semibold text-neutral-700">Pedidos del mes</h3>
                  <button
                    onClick={exportarHistorial}
                    disabled={exportandoHistorial}
                    className="bg-secondary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-secondary/90 disabled:opacity-50"
                  >
                    {exportandoHistorial ? 'Exportando...' : '⬇ Exportar a Excel'}
                  </button>
                </div>

                <div className="border border-neutral-100 rounded-lg overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-left text-neutral-400 border-b border-neutral-100">
                        <th className="px-3 py-2">Orden</th>
                        <th className="px-3 py-2">Cliente</th>
                        <th className="px-3 py-2">Total</th>
                        <th className="px-3 py-2">Estado</th>
                        <th className="px-3 py-2">Fecha</th>
                      </tr>
                    </thead>
                    <tbody>
                      {historialVentas.length ? (
                        historialVentas.map((v) => (
                          <tr key={v.id} className="border-b border-neutral-50 last:border-0">
                            <td className="px-3 py-2">{v.numero_orden}</td>
                            <td className="px-3 py-2">
                              {v.domicilio?.cliente?.nombre_negocio || '—'}
                            </td>
                            <td className="px-3 py-2">${Number(v.total).toFixed(2)}</td>
                            <td className="px-3 py-2 capitalize">{v.estado}</td>
                            <td className="px-3 py-2">
                              {new Date(v.fecha_hora).toLocaleDateString('es-MX')}
                            </td>
                          </tr>
                        ))
                      ) : (
                        <tr>
                          <td colSpan={5} className="px-3 py-4 text-center text-neutral-400">
                            No hay pedidos este mes.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* Modal monitoreo */}
      {monitoreoAbierto && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-primary">Monitoreo de preventistas</h2>
              <button
                onClick={cerrarMonitoreo}
                className="text-neutral-400 hover:text-neutral-600 text-xl leading-none"
              >
                ×
              </button>
            </div>

            <div className="mb-4">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm font-semibold text-neutral-700">Mapa en tiempo real</p>
                <p className="text-xs text-neutral-400">Se actualiza cada 30 segundos</p>
              </div>
              <div
                ref={mapaContenedorRef}
                className="w-full h-72 rounded-lg border border-neutral-200 z-0"
              />
            </div>

            {monitoreoLoading ? (
              <p className="text-neutral-400 text-center py-8">Cargando...</p>
            ) : monitoreoData.length ? (
              <div className="space-y-3">
                {monitoreoData.map((m) => (
                  <div key={m.id} className="border border-neutral-100 rounded-lg p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <span
                          className="inline-block w-3 h-3 rounded-full border border-neutral-200"
                          style={{ backgroundColor: m.color || '#2E4E9E' }}
                        />
                        <p className="font-semibold text-neutral-800">{m.nombre}</p>
                      </div>
                      <span
                        className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                          m.jornada_activa
                            ? 'bg-green-100 text-green-700'
                            : 'bg-neutral-100 text-neutral-500'
                        }`}
                      >
                        {m.jornada_activa ? `Activo desde ${m.hora_inicio}` : 'Sin jornada activa'}
                      </span>
                    </div>

                    <div className="grid grid-cols-2 gap-3 text-sm">
                      <div>
                        <p className="text-xs text-neutral-400 mb-1">Ruta de hoy</p>
                        {m.ruta.tiene_ruta_hoy ? (
                          <>
                            <p className="text-neutral-700">
                              {m.ruta.paradas_visitadas} de {m.ruta.total_paradas} paradas hechas
                            </p>
                            <div className="w-full bg-neutral-100 rounded-full h-2 overflow-hidden mt-1">
                              <div
                                className="h-2 rounded-full bg-secondary"
                                style={{
                                  width: `${
                                    m.ruta.total_paradas > 0
                                      ? Math.round((m.ruta.paradas_visitadas / m.ruta.total_paradas) * 100)
                                      : 0
                                  }%`,
                                }}
                              />
                            </div>
                          </>
                        ) : (
                          <p className="text-neutral-400 italic">Sin ruta asignada hoy</p>
                        )}
                      </div>

                      <div>
                        <p className="text-xs text-neutral-400 mb-1">Última ubicación conocida</p>
                        {m.ubicacion ? (
                          <>
                            <a href={`https://www.openstreetmap.org/?mlat=${m.ubicacion.latitud}&mlon=${m.ubicacion.longitud}#map=16/${m.ubicacion.latitud}/${m.ubicacion.longitud}`} target="_blank" rel="noopener noreferrer" className="text-secondary font-medium hover:underline">
                              Ver en el mapa →
                            </a>
                            <p className="text-xs text-neutral-400 mt-1">
                              {m.ubicacion.origen === 'en_vivo'
                                ? m.ubicacion.reciente
                                  ? 'Ubicación en vivo'
                                  : 'Última ubicación en vivo (no reciente)'
                                : 'Ubicación al iniciar jornada'}
                            </p>
                          </>
                        ) : (
                          <p className="text-neutral-400 italic">Sin ubicación registrada</p>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-neutral-400 text-center py-8">No hay preventistas activos.</p>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
