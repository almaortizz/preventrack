import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_ADMIN = 1

const emptyForm = {
  nombre: '',
  apellidos: '',
  edad: '',
  telefono: '',
  usuario: '',
  password: '',
  estado: 'activo',
}

function validarTelefono(telefono) {
  if (!telefono) return true
  return /^\d{10}$/.test(telefono)
}

function validarPassword(password, esRequerida) {
  if (!password) return !esRequerida
  return /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$/.test(password)
}

export default function Administradores() {
  const [admins, setAdmins] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [mostrarPassword, setMostrarPassword] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')

  function cargar() {
    setLoading(true)
    client
      .get(`/usuarios?rol_id=${ROL_ADMIN}`)
      .then((res) => setAdmins(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de administradores.'))
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

  function abrirEditar(a) {
    setForm({
      nombre: a.nombre ?? '',
      apellidos: a.apellidos ?? '',
      edad: a.edad ?? '',
      telefono: a.telefono ?? '',
      usuario: a.usuario ?? '',
      password: '',
      estado: a.estado ?? 'activo',
    })
    setEditingId(a.id)
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

    const payload = { ...form, rol_id: ROL_ADMIN }
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
        err.response?.data?.message || 'Ocurrió un error al guardar el administrador.',
      )
    }
  }

  async function toggleEstado(a) {
    try {
      if (a.estado === 'activo') {
        await client.post(`/usuarios/${a.id}/bloquear`)
      } else {
        await client.post(`/usuarios/${a.id}/desbloquear`)
      }
      cargar()
    } catch {
      alert('No se pudo cambiar el estado del administrador.')
    }
  }

  async function eliminar(a) {
    if (!confirm(`¿Eliminar al administrador "${a.nombre} ${a.apellidos}"?`)) return
    try {
      await client.delete(`/usuarios/${a.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar el administrador.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Administradores</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nuevo administrador
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Nombre</th>
              <th className="px-4 py-3">Usuario</th>
              <th className="px-4 py-3">Teléfono</th>
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
            ) : admins.length ? (
              admins.map((a) => (
                <tr key={a.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">{a.nombre} {a.apellidos}</td>
                  <td className="px-4 py-3">{a.usuario}</td>
                  <td className="px-4 py-3">{a.telefono || '—'}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold capitalize ${
                        a.estado === 'activo'
                          ? 'bg-green-100 text-green-700'
                          : 'bg-red-100 text-red-700'
                      }`}
                    >
                      {a.estado}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right space-x-3">
                    <button
                      onClick={() => abrirEditar(a)}
                      className="text-secondary font-medium hover:underline"
                    >
                      Editar
                    </button>
                    <button
                      onClick={() => toggleEstado(a)}
                      className="text-amber-600 font-medium hover:underline"
                    >
                      {a.estado === 'activo' ? 'Bloquear' : 'Desbloquear'}
                    </button>
                    <button
                      onClick={() => eliminar(a)}
                      className="text-red-600 font-medium hover:underline"
                    >
                      Eliminar
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-neutral-400">
                  No hay administradores registrados.
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
              {editingId ? 'Editar administrador' : 'Nuevo administrador'}
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
    </div>
  )
}