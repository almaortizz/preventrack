import { useEffect, useState } from 'react'
import client from '../api/client'

function fmt(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${dia}`
}

function rangoFechas(tipo) {
  const hoy = new Date()
  const fin = fmt(hoy)
  if (tipo === 'semana') {
    const d = new Date(hoy)
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7)) // lunes
    return { fecha_inicio: fmt(d), fecha_fin: fin }
  }
  if (tipo === 'mes') {
    return { fecha_inicio: fmt(new Date(hoy.getFullYear(), hoy.getMonth(), 1)), fecha_fin: fin }
  }
  return { fecha_inicio: fin, fecha_fin: fin }
}

const COLUMNAS_VENTAS = [
  { t: 'Pedido', v: (v) => v.numero_orden ?? v.id },
  { t: 'Cliente', v: (v) => v.domicilio?.cliente?.nombre_negocio ?? '—' },
  { t: 'Vendedor', v: (v) => v.vendedor?.nombre ?? '—' },
  { t: 'Estado', v: (v) => v.estado, cap: true },
  { t: 'Total', v: (v) => `$${v.total}` },
  { t: 'Fecha', v: (v) => (v.fecha_hora ? new Date(v.fecha_hora).toLocaleDateString() : '—') },
]

const COLUMNAS_CLIENTES = [
  { t: 'Folio', v: (c) => c.folio },
  { t: 'Negocio', v: (c) => c.nombre_negocio },
  { t: 'Propietario', v: (c) => c.propietario || '—' },
  { t: 'Teléfono', v: (c) => c.telefono || '—' },
  { t: 'Zona', v: (c) => c.zona || '—' },
]

const COLUMNAS_PRODUCTOS = [
  { t: 'Código', v: (p) => p.codigo },
  { t: 'Producto', v: (p) => p.nombre },
  { t: 'Precio', v: (p) => `$${p.precio_venta}` },
  { t: 'Stock', v: (p) => p.stock ?? '—' },
]

export default function Dashboard() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [verTodos, setVerTodos] = useState(false)
  const [masPedidos, setMasPedidos] = useState([])
  const [cargandoMas, setCargandoMas] = useState(false)

  async function alternarPedidos() {
    if (verTodos) {
      setVerTodos(false)
      return
    }
    setCargandoMas(true)
    try {
      const res = await client.get('/ventas', { params: { per_page: 50 } })
      setMasPedidos(res.data.data ?? [])
    } catch {
      setMasPedidos([])
    } finally {
      setCargandoMas(false)
      setVerTodos(true)
    }
  }
  const [detalle, setDetalle] = useState(null) // { titulo, columnas, filas, loading }

  useEffect(() => {
    client
      .get('/dashboard')
      .then((res) => setData(res.data))
      .catch(() => setError('No se pudo cargar la información del dashboard.'))
  }, [])

  async function abrirDetalle(card) {
    setDetalle({ titulo: card.label, columnas: card.columnas, filas: [], loading: true })
    try {
      const res = await client.get(card.url, { params: { ...card.params, per_page: 200 } })
      let filas = res.data.data ?? res.data ?? []
      if (card.sinCancelados) filas = filas.filter((v) => v.estado !== 'cancelado')
      setDetalle({ titulo: card.label, columnas: card.columnas, filas, loading: false })
    } catch {
      setDetalle({ titulo: card.label, columnas: card.columnas, filas: [], loading: false, error: true })
    }
  }

  const cards = [
    { label: 'Ventas hoy', value: data ? `$${data.ventas.total_hoy}` : '—', url: '/ventas', params: rangoFechas('hoy'), columnas: COLUMNAS_VENTAS, sinCancelados: true },
    { label: 'Ventas de la semana', value: data ? `$${data.ventas.total_semana}` : '—', url: '/ventas', params: rangoFechas('semana'), columnas: COLUMNAS_VENTAS, sinCancelados: true },
    { label: 'Ventas del mes', value: data ? `$${data.ventas.total_mes}` : '—', url: '/ventas', params: rangoFechas('mes'), columnas: COLUMNAS_VENTAS, sinCancelados: true },
    { label: 'Pendientes', value: data ? data.contadores.pendientes : '—', url: '/ventas', params: { estado: 'pendiente' }, columnas: COLUMNAS_VENTAS },
    { label: 'En ruta', value: data ? data.contadores.en_ruta : '—', url: '/ventas', params: { estado: 'en_ruta' }, columnas: COLUMNAS_VENTAS },
    { label: 'Entregados hoy', value: data ? data.contadores.entregados_hoy : '—', url: '/ventas', params: { estado: 'entregado', ...rangoFechas('hoy') }, columnas: COLUMNAS_VENTAS },
    { label: 'Cancelados hoy', value: data ? data.contadores.cancelados_hoy : '—', url: '/ventas', params: { estado: 'cancelado', ...rangoFechas('hoy') }, columnas: COLUMNAS_VENTAS },
    { label: 'Clientes', value: data ? data.totales.clientes : '—', url: '/clientes', params: {}, columnas: COLUMNAS_CLIENTES },
    { label: 'Productos', value: data ? data.totales.productos : '—', url: '/productos', params: {}, columnas: COLUMNAS_PRODUCTOS },
  ]

  return (
    <div>
      <h1 className="text-2xl font-bold text-neutral-800 mb-6">Dashboard</h1>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map((card) => (
          <button
            type="button"
            key={card.label}
            onClick={() => abrirDetalle(card)}
            className="text-left bg-white rounded-xl shadow-sm p-5 border border-neutral-100 hover:shadow-md hover:border-secondary transition cursor-pointer"
          >
            <p className="text-sm text-neutral-400">{card.label}</p>
            <p className="text-3xl font-bold text-primary mt-2">
              {card.value}
            </p>
            <p className="text-xs text-secondary mt-2">Ver detalle →</p>
          </button>
        ))}
      </div>

      <h2 className="text-lg font-semibold text-neutral-800 mt-8 mb-3">
        Últimos pedidos
      </h2>
      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">ID</th>
              <th className="px-4 py-3">Estado</th>
              <th className="px-4 py-3">Total</th>
              <th className="px-4 py-3">Fecha</th>
            </tr>
          </thead>
          <tbody>
            {data?.ultimos_pedidos?.length ? (
              (verTodos && masPedidos.length ? masPedidos : data.ultimos_pedidos).map((venta) => (
                <tr key={venta.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">{venta.id}</td>
                  <td className="px-4 py-3 capitalize">{venta.estado}</td>
                  <td className="px-4 py-3">${venta.total}</td>
                  <td className="px-4 py-3">
                    {new Date(venta.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-neutral-400">
                  {data ? 'No hay pedidos registrados.' : 'Cargando...'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {data?.ultimos_pedidos?.length > 0 && (
        <button
          type="button"
          onClick={alternarPedidos}
          disabled={cargandoMas}
          className="mt-3 text-sm font-semibold text-secondary hover:underline disabled:opacity-60"
        >
          {cargandoMas ? 'Cargando...' : verTodos ? 'Mostrar menos' : 'Mostrar más'}
        </button>
      )}

      {detalle && (
        <div
          className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
          onClick={() => setDetalle(null)}
        >
          <div
            className="bg-white rounded-xl shadow-xl w-full max-w-3xl max-h-[85vh] flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-100">
              <h2 className="text-lg font-bold text-neutral-800">{detalle.titulo}</h2>
              <button
                type="button"
                onClick={() => setDetalle(null)}
                className="text-neutral-400 hover:text-neutral-700 text-xl leading-none"
                aria-label="Cerrar"
              >
                ✕
              </button>
            </div>
            <div className="overflow-auto p-2">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-neutral-400 border-b border-neutral-100">
                    {detalle.columnas.map((c) => (
                      <th key={c.t} className="px-4 py-3">{c.t}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {detalle.loading ? (
                    <tr>
                      <td colSpan={detalle.columnas.length} className="px-4 py-6 text-center text-neutral-400">
                        Cargando...
                      </td>
                    </tr>
                  ) : detalle.error ? (
                    <tr>
                      <td colSpan={detalle.columnas.length} className="px-4 py-6 text-center text-red-600">
                        No se pudo cargar el detalle.
                      </td>
                    </tr>
                  ) : detalle.filas.length ? (
                    detalle.filas.map((f, i) => (
                      <tr key={f.id ?? i} className="border-b border-neutral-50 last:border-0">
                        {detalle.columnas.map((c) => (
                          <td key={c.t} className={`px-4 py-3 ${c.cap ? 'capitalize' : ''}`}>
                            {c.v(f)}
                          </td>
                        ))}
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={detalle.columnas.length} className="px-4 py-6 text-center text-neutral-400">
                        No hay registros.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            {!detalle.loading && !detalle.error && (
              <p className="px-6 py-3 text-xs text-neutral-400 border-t border-neutral-100">
                {detalle.filas.length} registro(s)
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
