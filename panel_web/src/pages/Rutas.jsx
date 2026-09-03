import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_COLABORADOR = 2

const ESTADO_STYLES = {
  planeada: 'bg-yellow-100 text-yellow-700',
  en_curso: 'bg-blue-100 text-blue-700',
  finalizada: 'bg-green-100 text-green-700',
}

const ESTADO_LABEL = {
  planeada: 'Planeada',
  en_curso: 'En curso',
  finalizada: 'Finalizada',
}

export default function Rutas() {
  const [rutas, setRutas] = useState([])
  const [clientes, setClientes] = useState([])
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [expandidaId, setExpandidaId] = useState(null)

  const [showForm, setShowForm] = useState(false)
  const [usuarioId, setUsuarioId] = useState('')
  const [fecha, setFecha] = useState('')
  const [paradas, setParadas] = useState([]) // [{ domicilio_id, texto }]
  const [clienteTemp, setClienteTemp] = useState('')
  const [domicilioTemp, setDomicilioTemp] = useState('')
  const [formError, setFormError] = useState('')

  function cargar() {
    setLoading(true)
    client
      .get('/rutas')
      .then((res) => setRutas(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de rutas.'))
      .finally(() => setLoading(false))
  }

  function cargarCatalogos() {
    client.get('/clientes').then((res) => setClientes(res.data.data ?? []))
    client.get('/usuarios').then((res) => {
      const todos = res.data.data ?? []
      setPreventistas(
        todos.filter((u) => u.rol_id === ROL_COLABORADOR && u.estado === 'activo'),
      )
    })
  }

  useEffect(() => {
    cargar()
    cargarCatalogos()
  }, [])

  const clienteTempObj = clientes.find((c) => c.id === Number(clienteTemp))

  function abrirNuevo() {
    setUsuarioId('')
    setFecha('')
    setParadas([])
    setClienteTemp('')
    setDomicilioTemp('')
    setFormError('')
    setShowForm(true)
  }

  function agregarParada() {
    if (!domicilioTemp) return
    const cliente = clientes.find((c) => c.id === Number(clienteTemp))
    const domicilio = cliente?.domicilios?.find((d) => d.id === Number(domicilioTemp))
    if (!domicilio) return

    setParadas((prev) => [
      ...prev,
      {
        domicilio_id: domicilio.id,
        texto: `${cliente.nombre_negocio} — ${domicilio.direccion}`,
      },
    ])
    setClienteTemp('')
    setDomicilioTemp('')
  }

  function quitarParada(index) {
    setParadas((prev) => prev.filter((_, i) => i !== index))
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')

    if (!usuarioId) {
      setFormError('Selecciona el preventista.')
      return
    }
    if (!fecha) {
      setFormError('Selecciona la fecha de la ruta.')
      return
    }
    if (!paradas.length) {
      setFormError('Agrega al menos una parada.')
      return
    }

    try {
      await client.post('/rutas', {
        usuario_id: Number(usuarioId),
        fecha,
        domicilios: paradas.map((p) => p.domicilio_id),
      })
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al registrar la ruta.',
      )
    }
  }

  async function marcarVisitada(ruta, detalleId) {
    try {
      await client.post(`/rutas/${ruta.id}/visitar/${detalleId}`)
      cargar()
    } catch {
      alert('No se pudo marcar la parada como visitada.')
    }
  }

  async function eliminar(ruta) {
    if (!confirm(`¿Eliminar la ruta del ${ruta.fecha}?`)) return
    try {
      await client.delete(`/rutas/${ruta.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar la ruta.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Rutas</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nueva ruta
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Preventista</th>
              <th className="px-4 py-3">Fecha</th>
              <th className="px-4 py-3">Paradas</th>
              <th className="px-4 py-3">Estado</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-neutral-400">
                  Cargando...
                </td>
              </tr>
            ) : rutas.length ? (
              rutas.map((r) => (
                <>
                  <tr key={r.id} className="border-b border-neutral-50 last:border-0">
                    <td className="px-4 py-3">
                      {r.usuario ? `${r.usuario.nombre} ${r.usuario.apellidos}` : '—'}
                    </td>
                    <td className="px-4 py-3">{r.fecha}</td>
                    <td className="px-4 py-3">{r.detalle?.length ?? 0}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                          ESTADO_STYLES[r.estado] || 'bg-neutral-100 text-neutral-600'
                        }`}
                      >
                        {ESTADO_LABEL[r.estado] || r.estado}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right space-x-3">
                      <button
                        onClick={() =>
                          setExpandidaId(expandidaId === r.id ? null : r.id)
                        }
                        className="text-secondary font-medium hover:underline"
                      >
                        {expandidaId === r.id ? 'Ocultar' : 'Ver paradas'}
                      </button>
                      <button
                        onClick={() => eliminar(r)}
                        className="text-red-600 font-medium hover:underline"
                      >
                        Eliminar
                      </button>
                    </td>
                  </tr>
                  {expandidaId === r.id && (
                    <tr>
                      <td colSpan={5} className="px-4 py-3 bg-neutral-50">
                        <table className="w-full text-sm">
                          <thead>
                            <tr className="text-left text-neutral-400">
                              <th className="py-2">#</th>
                              <th className="py-2">Cliente</th>
                              <th className="py-2">Dirección</th>
                              <th className="py-2">Estado</th>
                              <th className="py-2"></th>
                            </tr>
                          </thead>
                          <tbody>
                            {(r.detalle || [])
                              .slice()
                              .sort((a, b) => a.orden_visita - b.orden_visita)
                              .map((d) => (
                                <tr key={d.id} className="border-t border-neutral-100">
                                  <td className="py-2">{d.orden_visita}</td>
                                  <td className="py-2">
                                    {d.domicilio?.cliente?.nombre_negocio || '—'}
                                  </td>
                                  <td className="py-2">{d.domicilio?.direccion || '—'}</td>
                                  <td className="py-2">
                                    <span
                                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                                        d.estado === 'visitada'
                                          ? 'bg-green-100 text-green-700'
                                          : 'bg-yellow-100 text-yellow-700'
                                      }`}
                                    >
                                      {d.estado === 'visitada' ? 'Visitada' : 'Pendiente'}
                                    </span>
                                  </td>
                                  <td className="py-2 text-right">
                                    {d.estado !== 'visitada' && (
                                      <button
                                        onClick={() => marcarVisitada(r, d.id)}
                                        className="text-green-600 font-medium hover:underline"
                                      >
                                        Marcar visitada
                                      </button>
                                    )}
                                  </td>
                                </tr>
                              ))}
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
                </>
              ))
            ) : (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-neutral-400">
                  No hay rutas registradas.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-primary mb-4">Nueva ruta</h2>
            <form onSubmit={guardar} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Preventista</label>
                <select
                  value={usuarioId}
                  onChange={(e) => setUsuarioId(e.target.value)}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                >
                  <option value="">Selecciona un preventista</option>
                  {preventistas.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.nombre} {p.apellidos}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Fecha</label>
                <input
                  type="date"
                  value={fecha}
                  onChange={(e) => setFecha(e.target.value)}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Agregar parada</label>
                <div className="flex gap-2 mb-2">
                  <select
                    value={clienteTemp}
                    onChange={(e) => {
                      setClienteTemp(e.target.value)
                      setDomicilioTemp('')
                    }}
                    className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                  >
                    <option value="">Cliente</option>
                    {clientes.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.nombre_negocio}
                      </option>
                    ))}
                  </select>
                  <select
                    value={domicilioTemp}
                    onChange={(e) => setDomicilioTemp(e.target.value)}
                    className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                    disabled={!clienteTemp}
                  >
                    <option value="">Dirección</option>
                    {(clienteTempObj?.domicilios || []).map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.direccion}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={agregarParada}
                    className="bg-secondary text-white text-sm font-semibold px-3 py-2 rounded-lg hover:bg-secondary/90"
                  >
                    Agregar
                  </button>
                </div>

                {paradas.length > 0 && (
                  <ol className="list-decimal list-inside space-y-1 text-sm text-neutral-700 bg-neutral-50 rounded-lg p-3">
                    {paradas.map((p, index) => (
                      <li key={index} className="flex items-center justify-between">
                        <span>{p.texto}</span>
                        <button
                          type="button"
                          onClick={() => quitarParada(index)}
                          className="text-red-600 text-xs font-medium ml-2"
                        >
                          Quitar
                        </button>
                      </li>
                    ))}
                  </ol>
                )}
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
                  Guardar ruta
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}