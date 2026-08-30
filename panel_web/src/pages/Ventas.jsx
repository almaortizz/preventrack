import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_COLABORADOR = 2

const ESTADO_STYLES = {
  pendiente: 'bg-yellow-100 text-yellow-700',
  en_ruta: 'bg-blue-100 text-blue-700',
  entregado: 'bg-green-100 text-green-700',
  cancelado: 'bg-red-100 text-red-700',
}

const ESTADO_LABEL = {
  pendiente: 'Pendiente',
  en_ruta: 'En ruta',
  entregado: 'Entregado',
  cancelado: 'Cancelado',
}

const emptyForm = {
  cliente_id: '',
  domicilio_id: '',
  preventista_vendedor_id: '',
  descuento: '',
  notas: '',
}

export default function Ventas() {
  const [ventas, setVentas] = useState([])
  const [clientes, setClientes] = useState([])
  const [productos, setProductos] = useState([])
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState(emptyForm)
  const [items, setItems] = useState([{ producto_id: '', cantidad: 1 }])
  const [formError, setFormError] = useState('')

  // Para asignar entrega
  const [asignando, setAsignando] = useState(null) // venta seleccionada
  const [entregaId, setEntregaId] = useState('')

  // Para agregar domicilio nuevo al vuelo
  const [nuevaDireccion, setNuevaDireccion] = useState('')
  const [guardandoDireccion, setGuardandoDireccion] = useState(false)

  function cargar() {
    setLoading(true)
    client
      .get('/ventas')
      .then((res) => setVentas(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de pedidos.'))
      .finally(() => setLoading(false))
  }

  function cargarCatalogos() {
    client.get('/clientes').then((res) => setClientes(res.data.data ?? []))
    client.get('/productos').then((res) => setProductos(res.data.data ?? []))
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

  const clienteSeleccionado = clientes.find((c) => c.id === Number(form.cliente_id))

  function abrirNuevo() {
    setForm(emptyForm)
    setItems([{ producto_id: '', cantidad: 1 }])
    setNuevaDireccion('')
    setFormError('')
    setShowForm(true)
  }

  function actualizarItem(index, campo, valor) {
    setItems((prev) =>
      prev.map((it, i) => (i === index ? { ...it, [campo]: valor } : it)),
    )
  }

  function agregarItem() {
    setItems((prev) => [...prev, { producto_id: '', cantidad: 1 }])
  }

  function quitarItem(index) {
    setItems((prev) => prev.filter((_, i) => i !== index))
  }

  function totalEstimado() {
    return items.reduce((acc, it) => {
      const p = productos.find((p) => p.id === Number(it.producto_id))
      if (!p) return acc
      return acc + Number(p.precio_venta) * Number(it.cantidad || 0)
    }, 0)
  }

  async function agregarDireccionRapida() {
    if (!nuevaDireccion.trim() || !form.cliente_id) return
    setGuardandoDireccion(true)
    try {
      const res = await client.post(`/clientes/${form.cliente_id}/domicilios`, {
        direccion: nuevaDireccion.trim(),
        es_principal: true,
      })
      setNuevaDireccion('')
      // Refrescamos el cliente en la lista local para que aparezca el nuevo domicilio
      const clienteActualizado = await client.get(`/clientes/${form.cliente_id}`)
      setClientes((prev) =>
        prev.map((c) => (c.id === Number(form.cliente_id) ? clienteActualizado.data : c)),
      )
      setForm((f) => ({ ...f, domicilio_id: String(res.data.id) }))
    } catch {
      setFormError('No se pudo guardar la dirección.')
    } finally {
      setGuardandoDireccion(false)
    }
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')

    const productosValidos = items
      .filter((it) => it.producto_id && Number(it.cantidad) > 0)
      .map((it) => ({
        producto_id: Number(it.producto_id),
        cantidad: Number(it.cantidad),
      }))

    if (!form.domicilio_id) {
      setFormError('Selecciona o agrega una dirección de entrega.')
      return
    }
    if (!productosValidos.length) {
      setFormError('Agrega al menos un producto.')
      return
    }

    try {
      await client.post('/ventas', {
        domicilio_id: Number(form.domicilio_id),
        preventista_vendedor_id: Number(form.preventista_vendedor_id),
        descuento: form.descuento ? Number(form.descuento) : 0,
        notas: form.notas || null,
        productos: productosValidos,
      })
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al registrar el pedido.',
      )
    }
  }

  function abrirAsignar(venta) {
    setAsignando(venta)
    setEntregaId('')
  }

  async function confirmarAsignacion() {
    if (!entregaId) return
    try {
      await client.post(`/ventas/${asignando.id}/asignar-entrega`, {
        preventista_entrega_id: Number(entregaId),
      })
      setAsignando(null)
      cargar()
    } catch {
      alert('No se pudo asignar la entrega.')
    }
  }

  async function marcarEntregado(venta) {
    if (!confirm(`¿Marcar el pedido ${venta.numero_orden} como entregado?`)) return
    try {
      await client.post(`/ventas/${venta.id}/marcar-entregado`)
      cargar()
    } catch {
      alert('No se pudo marcar como entregado.')
    }
  }

  async function cancelar(venta) {
    const motivo = prompt(`Motivo de cancelación del pedido ${venta.numero_orden}:`)
    if (motivo === null) return
    try {
      await client.post(`/ventas/${venta.id}/cancelar`, { motivo_cancelacion: motivo })
      cargar()
    } catch {
      alert('No se pudo cancelar el pedido.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Ventas</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nuevo pedido
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Orden</th>
              <th className="px-4 py-3">Cliente</th>
              <th className="px-4 py-3">Vendedor</th>
              <th className="px-4 py-3">Total</th>
              <th className="px-4 py-3">Estado</th>
              <th className="px-4 py-3">Fecha</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-neutral-400">
                  Cargando...
                </td>
              </tr>
            ) : ventas.length ? (
              ventas.map((v) => (
                <tr key={v.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3 font-medium">{v.numero_orden}</td>
                  <td className="px-4 py-3">
                    {v.domicilio?.cliente?.nombre_negocio || '—'}
                  </td>
                  <td className="px-4 py-3">
                    {v.vendedor ? `${v.vendedor.nombre} ${v.vendedor.apellidos}` : '—'}
                  </td>
                  <td className="px-4 py-3">${Number(v.total).toFixed(2)}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                        ESTADO_STYLES[v.estado] || 'bg-neutral-100 text-neutral-600'
                      }`}
                    >
                      {ESTADO_LABEL[v.estado] || v.estado}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {new Date(v.fecha_hora).toLocaleDateString('es-MX')}
                  </td>
                  <td className="px-4 py-3 text-right space-x-3">
                    {v.estado === 'pendiente' && (
                      <>
                        <button
                          onClick={() => abrirAsignar(v)}
                          className="text-secondary font-medium hover:underline"
                        >
                          Asignar entrega
                        </button>
                        <button
                          onClick={() => cancelar(v)}
                          className="text-red-600 font-medium hover:underline"
                        >
                          Cancelar
                        </button>
                      </>
                    )}
                    {v.estado === 'en_ruta' && (
                      <>
                        <button
                          onClick={() => marcarEntregado(v)}
                          className="text-green-600 font-medium hover:underline"
                        >
                          Marcar entregado
                        </button>
                        <button
                          onClick={() => cancelar(v)}
                          className="text-red-600 font-medium hover:underline"
                        >
                          Cancelar
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-neutral-400">
                  No hay pedidos registrados.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Modal nuevo pedido */}
      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-primary mb-4">Nuevo pedido</h2>
            <form onSubmit={guardar} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Cliente</label>
                <select
                  value={form.cliente_id}
                  onChange={(e) =>
                    setForm({ ...form, cliente_id: e.target.value, domicilio_id: '' })
                  }
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                >
                  <option value="">Selecciona un cliente</option>
                  {clientes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.nombre_negocio}
                    </option>
                  ))}
                </select>
              </div>

              {form.cliente_id && (
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">
                    Dirección de entrega
                  </label>
                  <select
                    value={form.domicilio_id}
                    onChange={(e) => setForm({ ...form, domicilio_id: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary mb-2"
                  >
                    <option value="">Selecciona una dirección</option>
                    {(clienteSeleccionado?.domicilios || []).map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.direccion}
                      </option>
                    ))}
                  </select>

                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={nuevaDireccion}
                      onChange={(e) => setNuevaDireccion(e.target.value)}
                      placeholder="O escribe una dirección nueva"
                      className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                    />
                    <button
                      type="button"
                      onClick={agregarDireccionRapida}
                      disabled={guardandoDireccion}
                      className="bg-secondary text-white text-sm font-semibold px-3 py-2 rounded-lg hover:bg-secondary/90 disabled:opacity-50"
                    >
                      Agregar
                    </button>
                  </div>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Preventista vendedor</label>
                <select
                  value={form.preventista_vendedor_id}
                  onChange={(e) => setForm({ ...form, preventista_vendedor_id: e.target.value })}
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
                <label className="block text-sm font-medium text-neutral-700 mb-1">Productos</label>
                <div className="space-y-2">
                  {items.map((it, index) => (
                    <div key={index} className="flex gap-2 items-center">
                      <select
                        value={it.producto_id}
                        onChange={(e) => actualizarItem(index, 'producto_id', e.target.value)}
                        className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                      >
                        <option value="">Producto</option>
                        {productos.map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.nombre} (${Number(p.precio_venta).toFixed(2)})
                          </option>
                        ))}
                      </select>
                      <input
                        type="number"
                        min="1"
                        value={it.cantidad}
                        onChange={(e) => actualizarItem(index, 'cantidad', e.target.value)}
                        className="w-20 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                      />
                      {items.length > 1 && (
                        <button
                          type="button"
                          onClick={() => quitarItem(index)}
                          className="text-red-600 text-sm font-medium"
                        >
                          Quitar
                        </button>
                      )}
                    </div>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={agregarItem}
                  className="mt-2 text-secondary text-sm font-semibold hover:underline"
                >
                  + Agregar producto
                </button>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Descuento</label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={form.descuento}
                  onChange={(e) => setForm({ ...form, descuento: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Notas</label>
                <textarea
                  value={form.notas}
                  onChange={(e) => setForm({ ...form, notas: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  rows={2}
                />
              </div>

              <div className="text-right text-sm font-semibold text-neutral-700">
                Total estimado: ${totalEstimado().toFixed(2)}
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
                  Registrar pedido
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal asignar entrega */}
      {asignando && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-sm">
            <h2 className="text-lg font-bold text-primary mb-4">
              Asignar entrega — {asignando.numero_orden}
            </h2>
            <select
              value={entregaId}
              onChange={(e) => setEntregaId(e.target.value)}
              className="w-full rounded-lg border border-neutral-200 px-3 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-secondary"
            >
              <option value="">Selecciona un preventista</option>
              {preventistas.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.nombre} {p.apellidos}
                </option>
              ))}
            </select>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setAsignando(null)}
                className="px-4 py-2 rounded-lg text-neutral-600 hover:bg-neutral-100"
              >
                Cancelar
              </button>
              <button
                onClick={confirmarAsignacion}
                className="bg-primary text-white font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
              >
                Confirmar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}