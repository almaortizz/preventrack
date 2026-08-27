import { useEffect, useState } from 'react'
import client from '../api/client'

export default function Dashboard() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    client
      .get('/dashboard')
      .then((res) => setData(res.data))
      .catch(() => setError('No se pudo cargar la información del dashboard.'))
  }, [])

  const cards = [
    { label: 'Ventas hoy', value: data ? `$${data.ventas.total_hoy}` : '—' },
    { label: 'Ventas de la semana', value: data ? `$${data.ventas.total_semana}` : '—' },
    { label: 'Ventas del mes', value: data ? `$${data.ventas.total_mes}` : '—' },
    { label: 'Pendientes', value: data ? data.contadores.pendientes : '—' },
    { label: 'En ruta', value: data ? data.contadores.en_ruta : '—' },
    { label: 'Entregados hoy', value: data ? data.contadores.entregados_hoy : '—' },
    { label: 'Cancelados hoy', value: data ? data.contadores.cancelados_hoy : '—' },
    { label: 'Clientes', value: data ? data.totales.clientes : '—' },
    { label: 'Productos', value: data ? data.totales.productos : '—' },
  ]

  return (
    <div>
      <h1 className="text-2xl font-bold text-neutral-800 mb-6">Dashboard</h1>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map((card) => (
          <div
            key={card.label}
            className="bg-white rounded-xl shadow-sm p-5 border border-neutral-100"
          >
            <p className="text-sm text-neutral-400">{card.label}</p>
            <p className="text-3xl font-bold text-primary mt-2">
              {card.value}
            </p>
          </div>
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
              data.ultimos_pedidos.map((venta) => (
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
    </div>
  )
}