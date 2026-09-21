import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_COLABORADOR = 2

const RESULTADO_STYLES = {
  venta: 'bg-green-100 text-green-700',
  sin_venta: 'bg-yellow-100 text-yellow-700',
}

const RESULTADO_LABEL = {
  venta: 'Con venta',
  sin_venta: 'Sin venta',
}

export default function Visitas() {
  const [visitas, setVisitas] = useState([])
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [filtroPreventista, setFiltroPreventista] = useState('')
  const [filtroFecha, setFiltroFecha] = useState('')
  const [filtroResultado, setFiltroResultado] = useState('')

  function cargar() {
    setLoading(true)
    const params = {}
    if (filtroPreventista) params.usuario_id = filtroPreventista
    if (filtroFecha) params.fecha = filtroFecha
    if (filtroResultado) params.resultado = filtroResultado

    client
      .get('/visitas', { params })
      .then((res) => setVisitas(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de visitas.'))
      .finally(() => setLoading(false))
  }

  function cargarPreventistas() {
    client.get('/usuarios').then((res) => {
      const todos = res.data.data ?? []
      setPreventistas(todos.filter((u) => u.rol_id === ROL_COLABORADOR))
    })
  }

  useEffect(() => {
    cargarPreventistas()
  }, [])

  useEffect(() => {
    cargar()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtroPreventista, filtroFecha, filtroResultado])

  function limpiarFiltros() {
    setFiltroPreventista('')
    setFiltroFecha('')
    setFiltroResultado('')
  }

  async function eliminar(visita) {
    if (!confirm('¿Eliminar este registro de visita? Esta acción no se puede deshacer.')) return
    try {
      await client.delete(`/visitas/${visita.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar la visita.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold text-neutral-800">Visitas</h1>
      </div>

      {/* Filtros */}
      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-4 mb-4 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-xs font-medium text-neutral-600 mb-1">Preventista</label>
          <select
            value={filtroPreventista}
            onChange={(e) => setFiltroPreventista(e.target.value)}
            className="rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
          >
            <option value="">Todos</option>
            {preventistas.map((p) => (
              <option key={p.id} value={p.id}>
                {p.nombre} {p.apellidos}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-xs font-medium text-neutral-600 mb-1">Fecha</label>
          <input
            type="date"
            value={filtroFecha}
            onChange={(e) => setFiltroFecha(e.target.value)}
            className="rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
          />
        </div>

        <div>
          <label className="block text-xs font-medium text-neutral-600 mb-1">Resultado</label>
          <select
            value={filtroResultado}
            onChange={(e) => setFiltroResultado(e.target.value)}
            className="rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
          >
            <option value="">Todos</option>
            <option value="venta">Con venta</option>
            <option value="sin_venta">Sin venta</option>
          </select>
        </div>

        <button
          onClick={limpiarFiltros}
          className="text-secondary text-sm font-semibold hover:underline"
        >
          Limpiar filtros
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Preventista</th>
              <th className="px-4 py-3">Cliente</th>
              <th className="px-4 py-3">Dirección</th>
              <th className="px-4 py-3">Resultado</th>
              <th className="px-4 py-3">Fecha</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-neutral-400">
                  Cargando...
                </td>
              </tr>
            ) : visitas.length ? (
              visitas.map((v) => (
                <tr key={v.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">
                    {v.usuario ? `${v.usuario.nombre} ${v.usuario.apellidos}` : '—'}
                  </td>
                  <td className="px-4 py-3">
                    {v.domicilio?.cliente?.nombre_negocio || '—'}
                  </td>
                  <td className="px-4 py-3">{v.domicilio?.direccion || '—'}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                        RESULTADO_STYLES[v.resultado] || 'bg-neutral-100 text-neutral-600'
                      }`}
                    >
                      {RESULTADO_LABEL[v.resultado] || v.resultado}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {new Date(v.fecha_hora).toLocaleString('es-MX')}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => eliminar(v)}
                      className="text-red-600 font-medium hover:underline"
                    >
                      Eliminar
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-neutral-400">
                  No hay visitas registradas.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}