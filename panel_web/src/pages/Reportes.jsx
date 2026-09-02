import { useState } from 'react'
import client from '../api/client'

export default function Reportes() {
  const [descargando, setDescargando] = useState('')
  const [error, setError] = useState('')

  const [fechaInicioVentas, setFechaInicioVentas] = useState('')
  const [fechaFinVentas, setFechaFinVentas] = useState('')

  const [fechaInicioJornadas, setFechaInicioJornadas] = useState('')
  const [fechaFinJornadas, setFechaFinJornadas] = useState('')

  async function descargar(clave, url, params = {}) {
    setError('')
    setDescargando(clave)
    try {
      const res = await client.get(url, {
        params,
        responseType: 'blob',
      })

      const nombreArchivo =
        res.headers['content-disposition']?.match(/filename="?([^"]+)"?/)?.[1] ||
        `${clave}.xlsx`

      const blobUrl = window.URL.createObjectURL(new Blob([res.data]))
      const enlace = document.createElement('a')
      enlace.href = blobUrl
      enlace.download = nombreArchivo
      document.body.appendChild(enlace)
      enlace.click()
      enlace.remove()
      window.URL.revokeObjectURL(blobUrl)
    } catch {
      setError('No se pudo descargar el reporte. Intenta de nuevo.')
    } finally {
      setDescargando('')
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-neutral-800 mb-6">Reportes</h1>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Reporte de ventas */}
        <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-5">
          <h2 className="font-bold text-neutral-800 mb-1">Ventas</h2>
          <p className="text-sm text-neutral-500 mb-4">
            Exporta todos los pedidos registrados, con opción de filtrar por fecha.
          </p>
          <div className="flex gap-2 mb-4">
            <div className="flex-1">
              <label className="block text-xs font-medium text-neutral-600 mb-1">Desde</label>
              <input
                type="date"
                value={fechaInicioVentas}
                onChange={(e) => setFechaInicioVentas(e.target.value)}
                className="w-full rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
              />
            </div>
            <div className="flex-1">
              <label className="block text-xs font-medium text-neutral-600 mb-1">Hasta</label>
              <input
                type="date"
                value={fechaFinVentas}
                onChange={(e) => setFechaFinVentas(e.target.value)}
                className="w-full rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
              />
            </div>
          </div>
          <button
            onClick={() =>
              descargar('reporte_ventas', '/reportes/ventas', {
                fecha_inicio: fechaInicioVentas || undefined,
                fecha_fin: fechaFinVentas || undefined,
              })
            }
            disabled={descargando === 'reporte_ventas'}
            className="w-full bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {descargando === 'reporte_ventas' ? 'Descargando...' : 'Descargar Excel'}
          </button>
        </div>

        {/* Reporte de clientes */}
        <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-5">
          <h2 className="font-bold text-neutral-800 mb-1">Clientes</h2>
          <p className="text-sm text-neutral-500 mb-4">
            Exporta el listado completo de clientes registrados.
          </p>
          <button
            onClick={() => descargar('reporte_clientes', '/reportes/clientes')}
            disabled={descargando === 'reporte_clientes'}
            className="w-full bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {descargando === 'reporte_clientes' ? 'Descargando...' : 'Descargar Excel'}
          </button>
        </div>

        {/* Reporte de productos */}
        <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-5">
          <h2 className="font-bold text-neutral-800 mb-1">Productos</h2>
          <p className="text-sm text-neutral-500 mb-4">
            Exporta el catálogo de productos con su stock y precios.
          </p>
          <button
            onClick={() => descargar('reporte_productos', '/reportes/productos')}
            disabled={descargando === 'reporte_productos'}
            className="w-full bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {descargando === 'reporte_productos' ? 'Descargando...' : 'Descargar Excel'}
          </button>
        </div>

        {/* Reporte de comisiones */}
        <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-5">
          <h2 className="font-bold text-neutral-800 mb-1">Comisiones</h2>
          <p className="text-sm text-neutral-500 mb-4">
            Exporta las comisiones generadas por los preventistas.
          </p>
          <button
            onClick={() => descargar('reporte_comisiones', '/reportes/comisiones')}
            disabled={descargando === 'reporte_comisiones'}
            className="w-full bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {descargando === 'reporte_comisiones' ? 'Descargando...' : 'Descargar Excel'}
          </button>
        </div>

        {/* Reporte de jornadas */}
        <div className="bg-white rounded-xl shadow-sm border border-neutral-100 p-5">
          <h2 className="font-bold text-neutral-800 mb-1">Jornadas</h2>
          <p className="text-sm text-neutral-500 mb-4">
            Exporta los registros de entrada, comida y salida de los preventistas.
          </p>
          <div className="flex gap-2 mb-4">
            <div className="flex-1">
              <label className="block text-xs font-medium text-neutral-600 mb-1">Desde</label>
              <input
                type="date"
                value={fechaInicioJornadas}
                onChange={(e) => setFechaInicioJornadas(e.target.value)}
                className="w-full rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
              />
            </div>
            <div className="flex-1">
              <label className="block text-xs font-medium text-neutral-600 mb-1">Hasta</label>
              <input
                type="date"
                value={fechaFinJornadas}
                onChange={(e) => setFechaFinJornadas(e.target.value)}
                className="w-full rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
              />
            </div>
          </div>
          <button
            onClick={() =>
              descargar('reporte_jornadas', '/reportes/jornadas', {
                fecha_inicio: fechaInicioJornadas || undefined,
                fecha_fin: fechaFinJornadas || undefined,
              })
            }
            disabled={descargando === 'reporte_jornadas'}
            className="w-full bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {descargando === 'reporte_jornadas' ? 'Descargando...' : 'Descargar Excel'}
          </button>
        </div>
      </div>
    </div>
  )
}