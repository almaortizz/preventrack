import { useEffect, useState } from 'react'
import client from '../api/client'

const STORAGE_URL = 'http://127.0.0.1:8000/storage/'

const emptyForm = {
  codigo: '',
  nombre: '',
  descripcion: '',
  categoria_id: '',
  precio_venta: '',
  costo: '',
  stock: '',
  estado: 'activo',
}

export default function Productos() {
  const [productos, setProductos] = useState([])
  const [categorias, setCategorias] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [imagenFile, setImagenFile] = useState(null)
  const [formError, setFormError] = useState('')

  function cargar() {
    setLoading(true)
    client
      .get('/productos')
      .then((res) => setProductos(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de productos.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    cargar()
    client
      .get('/categorias')
      .then((res) => setCategorias(res.data.data ?? []))
      .catch(() => {})
  }, [])

  function abrirNuevo() {
    setForm(emptyForm)
    setImagenFile(null)
    setEditingId(null)
    setFormError('')
    setShowForm(true)
  }

  function abrirEditar(p) {
    setForm({
      codigo: p.codigo ?? '',
      nombre: p.nombre ?? '',
      descripcion: p.descripcion ?? '',
      categoria_id: p.categoria_id ?? '',
      precio_venta: p.precio_venta ?? '',
      costo: p.costo ?? '',
      stock: p.stock ?? '',
      estado: p.estado ?? 'activo',
    })
    setImagenFile(null)
    setEditingId(p.id)
    setFormError('')
    setShowForm(true)
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')

    const fd = new FormData()
    Object.entries(form).forEach(([key, value]) => {
      if (value !== '' && value !== null) fd.append(key, value)
    })
    if (imagenFile) fd.append('imagen', imagenFile)

    try {
      if (editingId) {
        fd.append('_method', 'PUT')
        await client.post(`/productos/${editingId}`, fd)
      } else {
        await client.post('/productos', fd)
      }
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al guardar el producto.',
      )
    }
  }

  async function eliminar(p) {
    if (!confirm(`¿Eliminar el producto "${p.nombre}"?`)) return
    try {
      await client.delete(`/productos/${p.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar el producto.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Productos</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nuevo producto
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Imagen</th>
              <th className="px-4 py-3">Código</th>
              <th className="px-4 py-3">Nombre</th>
              <th className="px-4 py-3">Categoría</th>
              <th className="px-4 py-3">Precio</th>
              <th className="px-4 py-3">Costo</th>
              <th className="px-4 py-3">Stock</th>
              <th className="px-4 py-3">Estado</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={9} className="px-4 py-6 text-center text-neutral-400">
                  Cargando...
                </td>
              </tr>
            ) : productos.length ? (
              productos.map((p) => (
                <tr key={p.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">
                    {p.imagen ? (
                      <img
                        src={STORAGE_URL + p.imagen}
                        alt={p.nombre}
                        className="h-10 w-10 rounded-lg object-cover border border-neutral-100"
                      />
                    ) : (
                      <div className="h-10 w-10 rounded-lg bg-neutral-100" />
                    )}
                  </td>
                  <td className="px-4 py-3">{p.codigo}</td>
                  <td className="px-4 py-3">{p.nombre}</td>
                  <td className="px-4 py-3">{p.categoria?.nombre || '—'}</td>
                  <td className="px-4 py-3">${p.precio_venta}</td>
                  <td className="px-4 py-3">${p.costo}</td>
                  <td className="px-4 py-3">{p.stock ?? 0}</td>
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
                      onClick={() => abrirEditar(p)}
                      className="text-secondary font-medium hover:underline"
                    >
                      Editar
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
                <td colSpan={9} className="px-4 py-6 text-center text-neutral-400">
                  No hay productos registrados.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-primary mb-4">
              {editingId ? 'Editar producto' : 'Nuevo producto'}
            </h2>
            <form onSubmit={guardar} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Código</label>
                <input
                  type="text"
                  value={form.codigo}
                  onChange={(e) => setForm({ ...form, codigo: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>
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
                <label className="block text-sm font-medium text-neutral-700 mb-1">Descripción</label>
                <input
                  type="text"
                  value={form.descripcion}
                  onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Imagen</label>
                <label
                  htmlFor="imagenInput"
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 flex items-center text-sm text-neutral-500 cursor-pointer hover:border-secondary"
                >
                  {imagenFile ? imagenFile.name : 'Selecciona una imagen...'}
                </label>
                <input
                  id="imagenInput"
                  type="file"
                  accept="image/*"
                  onChange={(e) => setImagenFile(e.target.files[0] ?? null)}
                  className="hidden"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Categoría</label>
                <select
                  value={form.categoria_id}
                  onChange={(e) => setForm({ ...form, categoria_id: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                >
                  <option value="">Selecciona una categoría</option>
                  {categorias.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.nombre}
                    </option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Precio venta</label>
                  <input
                    type="number"
                    step="0.01"
                    value={form.precio_venta}
                    onChange={(e) => setForm({ ...form, precio_venta: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Costo</label>
                  <input
                    type="number"
                    step="0.01"
                    value={form.costo}
                    onChange={(e) => setForm({ ...form, costo: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                    required
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Stock</label>
                <input
                  type="number"
                  value={form.stock}
                  onChange={(e) => setForm({ ...form, stock: e.target.value })}
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