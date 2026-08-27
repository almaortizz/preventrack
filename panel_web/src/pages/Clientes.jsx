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

export default function Clientes() {
  const [clientes, setClientes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')

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
    </div>
  )
}