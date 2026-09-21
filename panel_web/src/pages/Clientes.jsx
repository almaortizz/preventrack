import { useEffect, useState } from 'react'
import client from '../api/client'

const emptyForm = {
  folio: '',
  nombre_negocio: '',
  propietario: '',
  razon_social: '',
  rfc: '',
  telefono: '',
  zona: '',
  estado: 'activo',
}

const emptyDomicilio = {
  direccion: '',
  municipio: '',
  latitud: '',
  longitud: '',
  es_principal: false,
  estado: 'activo',
}

export default function Clientes() {
  const [clientes, setClientes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')

  // Direcciones
  const [expandidoId, setExpandidoId] = useState(null)
  const [showDomForm, setShowDomForm] = useState(false)
  const [domCliente, setDomCliente] = useState(null)
  const [domEditingId, setDomEditingId] = useState(null)
  const [domForm, setDomForm] = useState(emptyDomicilio)
  const [domError, setDomError] = useState('')
  const [buscandoUbicacion, setBuscandoUbicacion] = useState(false)

  function cargar() {
    setLoading(true)
    client
      .get('/clientes')
      .then((res) => setClientes(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de clientes.'))
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

  function abrirEditar(cliente) {
    setForm({
      folio: cliente.folio ?? '',
      nombre_negocio: cliente.nombre_negocio ?? '',
      propietario: cliente.propietario ?? '',
      razon_social: cliente.razon_social ?? '',
      rfc: cliente.rfc ?? '',
      telefono: cliente.telefono ?? '',
      zona: cliente.zona ?? '',
      estado: cliente.estado ?? 'activo',
    })
    setEditingId(cliente.id)
    setFormError('')
    setShowForm(true)
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')
    try {
      if (editingId) {
        await client.put(`/clientes/${editingId}`, form)
      } else {
        await client.post('/clientes', form)
      }
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al guardar el cliente.',
      )
    }
  }

  async function eliminar(cliente) {
    if (!confirm(`¿Eliminar al cliente "${cliente.nombre_negocio}"?`)) return
    try {
      await client.delete(`/clientes/${cliente.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar el cliente.')
    }
  }

  // --- Direcciones ---

  function abrirNuevaDireccion(cliente) {
    setDomCliente(cliente)
    setDomEditingId(null)
    setDomForm(emptyDomicilio)
    setDomError('')
    setShowDomForm(true)
  }

  function abrirEditarDireccion(cliente, domicilio) {
    setDomCliente(cliente)
    setDomEditingId(domicilio.id)
    setDomForm({
      direccion: domicilio.direccion ?? '',
      municipio: domicilio.municipio ?? '',
      latitud: domicilio.latitud ?? '',
      longitud: domicilio.longitud ?? '',
      es_principal: !!domicilio.es_principal,
      estado: domicilio.estado ?? 'activo',
    })
    setDomError('')
    setShowDomForm(true)
  }

  function usarUbicacionActual() {
    if (!navigator.geolocation) {
      setDomError('Tu navegador no soporta geolocalización.')
      return
    }
    setBuscandoUbicacion(true)
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setDomForm((f) => ({
          ...f,
          latitud: pos.coords.latitude.toFixed(7),
          longitud: pos.coords.longitude.toFixed(7),
        }))
        setBuscandoUbicacion(false)
      },
      () => {
        setDomError('No se pudo obtener tu ubicación. Revisa los permisos del navegador.')
        setBuscandoUbicacion(false)
      },
    )
  }

  async function guardarDireccion(e) {
    e.preventDefault()
    setDomError('')

    const datos = {
      direccion: domForm.direccion,
      municipio: domForm.municipio || null,
      latitud: domForm.latitud !== '' ? Number(domForm.latitud) : null,
      longitud: domForm.longitud !== '' ? Number(domForm.longitud) : null,
      es_principal: domForm.es_principal,
      estado: domForm.estado,
    }

    try {
      if (domEditingId) {
        await client.put(`/domicilios/${domEditingId}`, datos)
      } else {
        await client.post(`/clientes/${domCliente.id}/domicilios`, datos)
      }
      setShowDomForm(false)
      cargar()
    } catch (err) {
      setDomError(
        err.response?.data?.message || 'Ocurrió un error al guardar la dirección.',
      )
    }
  }

  async function eliminarDireccion(domicilio) {
    if (!confirm(`¿Eliminar la dirección "${domicilio.direccion}"?`)) return
    try {
      await client.delete(`/domicilios/${domicilio.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar la dirección.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Clientes</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nuevo cliente
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Folio</th>
              <th className="px-4 py-3">Negocio</th>
              <th className="px-4 py-3">Propietario</th>
              <th className="px-4 py-3">Teléfono</th>
              <th className="px-4 py-3">Zona</th>
              <th className="px-4 py-3">Estado</th>
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
            ) : clientes.length ? (
              clientes.map((c) => (
                <>
                  <tr key={c.id} className="border-b border-neutral-50 last:border-0">
                    <td className="px-4 py-3">{c.folio}</td>
                    <td className="px-4 py-3">{c.nombre_negocio}</td>
                    <td className="px-4 py-3">{c.propietario || '—'}</td>
                    <td className="px-4 py-3">{c.telefono || '—'}</td>
                    <td className="px-4 py-3">{c.zona || '—'}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-block px-2 py-1 rounded-full text-xs font-semibold capitalize ${
                          c.estado === 'activo'
                            ? 'bg-green-100 text-green-700'
                            : 'bg-red-100 text-red-700'
                        }`}
                      >
                        {c.estado}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right space-x-3">
                      <button
                        onClick={() =>
                          setExpandidoId(expandidoId === c.id ? null : c.id)
                        }
                        className="text-primary font-medium hover:underline"
                      >
                        {expandidoId === c.id ? 'Ocultar' : 'Direcciones'}
                      </button>
                      <button
                        onClick={() => abrirEditar(c)}
                        className="text-secondary font-medium hover:underline"
                      >
                        Editar
                      </button>
                      <button
                        onClick={() => eliminar(c)}
                        className="text-red-600 font-medium hover:underline"
                      >
                        Eliminar
                      </button>
                    </td>
                  </tr>
                  {expandidoId === c.id && (
                    <tr>
                      <td colSpan={7} className="px-4 py-3 bg-neutral-50">
                        <div className="flex items-center justify-between mb-2">
                          <h3 className="font-semibold text-neutral-700 text-sm">
                            Direcciones de {c.nombre_negocio}
                          </h3>
                          <button
                            onClick={() => abrirNuevaDireccion(c)}
                            className="text-secondary text-sm font-semibold hover:underline"
                          >
                            + Agregar dirección
                          </button>
                        </div>
                        {(c.domicilios || []).length ? (
                          <table className="w-full text-sm">
                            <thead>
                              <tr className="text-left text-neutral-400">
                                <th className="py-2">Dirección</th>
                                <th className="py-2">Municipio</th>
                                <th className="py-2">Coordenadas</th>
                                <th className="py-2"></th>
                              </tr>
                            </thead>
                            <tbody>
                              {c.domicilios.map((d) => (
                                <tr key={d.id} className="border-t border-neutral-100">
                                  <td className="py-2">
                                    {d.direccion}
                                    {d.es_principal && (
                                      <span className="ml-2 text-xs text-secondary font-semibold">
                                        (principal)
                                      </span>
                                    )}
                                  </td>
                                  <td className="py-2">{d.municipio || '—'}</td>
                                  <td className="py-2">
                                    {d.latitud && d.longitud ? (
                                      <span className="text-green-700 text-xs font-medium">
                                        ✓ Guardadas
                                      </span>
                                    ) : (
                                      <span className="text-red-600 text-xs font-medium">
                                        Sin coordenadas
                                      </span>
                                    )}
                                  </td>
                                  <td className="py-2 text-right space-x-3">
                                    <button
                                      onClick={() => abrirEditarDireccion(c, d)}
                                      className="text-secondary font-medium hover:underline"
                                    >
                                      Editar
                                    </button>
                                    <button
                                      onClick={() => eliminarDireccion(d)}
                                      className="text-red-600 font-medium hover:underline"
                                    >
                                      Eliminar
                                    </button>
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        ) : (
                          <p className="text-neutral-400 text-sm">
                            Este cliente no tiene direcciones registradas.
                          </p>
                        )}
                      </td>
                    </tr>
                  )}
                </>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-neutral-400">
                  No hay clientes registrados.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Modal cliente */}
      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-bold text-primary mb-4">
              {editingId ? 'Editar cliente' : 'Nuevo cliente'}
            </h2>
            <form onSubmit={guardar} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Folio</label>
                <input
                  type="text"
                  value={form.folio}
                  onChange={(e) => setForm({ ...form, folio: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Nombre del negocio</label>
                <input
                  type="text"
                  value={form.nombre_negocio}
                  onChange={(e) => setForm({ ...form, nombre_negocio: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Propietario</label>
                <input
                  type="text"
                  value={form.propietario}
                  onChange={(e) => setForm({ ...form, propietario: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Teléfono</label>
                <input
                  type="text"
                  value={form.telefono}
                  onChange={(e) => setForm({ ...form, telefono: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Zona</label>
                <input
                  type="text"
                  value={form.zona}
                  onChange={(e) => setForm({ ...form, zona: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
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

      {/* Modal dirección */}
      {showDomForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-bold text-primary mb-4">
              {domEditingId ? 'Editar dirección' : 'Nueva dirección'} — {domCliente?.nombre_negocio}
            </h2>
            <form onSubmit={guardarDireccion} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Dirección</label>
                <input
                  type="text"
                  value={domForm.direccion}
                  onChange={(e) => setDomForm({ ...domForm, direccion: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Municipio</label>
                <input
                  type="text"
                  value={domForm.municipio}
                  onChange={(e) => setDomForm({ ...domForm, municipio: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Coordenadas (para que aparezca en el mapa de la app)
                </label>
                <button
                  type="button"
                  onClick={usarUbicacionActual}
                  disabled={buscandoUbicacion}
                  className="w-full mb-2 bg-secondary text-white text-sm font-semibold px-3 py-2 rounded-lg hover:bg-secondary/90 disabled:opacity-50"
                >
                  {buscandoUbicacion ? 'Obteniendo ubicación...' : '📍 Usar mi ubicación actual'}
                </button>
                <div className="flex gap-2">
                  <input
                    type="number"
                    step="any"
                    placeholder="Latitud"
                    value={domForm.latitud}
                    onChange={(e) => setDomForm({ ...domForm, latitud: e.target.value })}
                    className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                  />
                  <input
                    type="number"
                    step="any"
                    placeholder="Longitud"
                    value={domForm.longitud}
                    onChange={(e) => setDomForm({ ...domForm, longitud: e.target.value })}
                    className="flex-1 rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
                  />
                </div>
                <p className="text-xs text-neutral-400 mt-1">
                  El botón usa la ubicación de este dispositivo. Úsalo cuando estés físicamente en la dirección del cliente, o pídele a tu compañera que la capture desde su celular en la app.
                </p>
              </div>

              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="es_principal"
                  checked={domForm.es_principal}
                  onChange={(e) => setDomForm({ ...domForm, es_principal: e.target.checked })}
                />
                <label htmlFor="es_principal" className="text-sm text-neutral-700">
                  Dirección principal
                </label>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Estado</label>
                <select
                  value={domForm.estado}
                  onChange={(e) => setDomForm({ ...domForm, estado: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                >
                  <option value="activo">Activo</option>
                  <option value="inactivo">Inactivo</option>
                </select>
              </div>

              {domError && <p className="text-red-600 text-sm">{domError}</p>}

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowDomForm(false)}
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
    </div>
  )
}