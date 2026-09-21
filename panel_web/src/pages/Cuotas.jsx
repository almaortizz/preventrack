import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_COLABORADOR = 2

function lunesDeEstaSemana() {
  const hoy = new Date()
  const dia = hoy.getDay() // 0 = domingo
  const diff = hoy.getDate() - dia + (dia === 0 ? -6 : 1)
  const lunes = new Date(hoy.setDate(diff))
  return lunes.toISOString().slice(0, 10)
}

function domingoDeEstaSemana(lunesISO) {
  const lunes = new Date(lunesISO)
  const domingo = new Date(lunes)
  domingo.setDate(lunes.getDate() + 6)
  return domingo.toISOString().slice(0, 10)
}

const emptyForm = {
  usuario_id: '',
  fecha_inicio_semana: lunesDeEstaSemana(),
  fecha_fin_semana: domingoDeEstaSemana(lunesDeEstaSemana()),
  monto_objetivo: '',
  monto_comision: '',
}

export default function Cuotas() {
  const [cuotas, setCuotas] = useState([])
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')

  function cargar() {
    setLoading(true)
    client
      .get('/cuotas')
      .then((res) => setCuotas(res.data.data ?? []))
      .catch(() => setError('No se pudo cargar la lista de cuotas.'))
      .finally(() => setLoading(false))
  }

  function cargarPreventistas() {
    client.get('/usuarios').then((res) => {
      const todos = res.data.data ?? []
      setPreventistas(
        todos.filter((u) => u.rol_id === ROL_COLABORADOR && u.estado === 'activo'),
      )
    })
  }

  useEffect(() => {
    cargar()
    cargarPreventistas()
  }, [])

  function abrirNuevo() {
    setForm(emptyForm)
    setEditingId(null)
    setFormError('')
    setShowForm(true)
  }

  function abrirEditar(cuota) {
    setForm({
      usuario_id: cuota.usuario_id,
      fecha_inicio_semana: cuota.fecha_inicio_semana,
      fecha_fin_semana: cuota.fecha_fin_semana,
      monto_objetivo: cuota.monto_objetivo,
      monto_comision: cuota.monto_comision,
    })
    setEditingId(cuota.id)
    setFormError('')
    setShowForm(true)
  }

  async function guardar(e) {
    e.preventDefault()
    setFormError('')
    try {
      if (editingId) {
        // Solo el monto se puede editar una vez creada
        await client.put(`/cuotas/${editingId}`, {
          monto_objetivo: Number(form.monto_objetivo),
          monto_comision: Number(form.monto_comision),
        })
      } else {
        await client.post('/cuotas', {
          usuario_id: Number(form.usuario_id),
          fecha_inicio_semana: form.fecha_inicio_semana,
          fecha_fin_semana: form.fecha_fin_semana,
          monto_objetivo: Number(form.monto_objetivo),
          monto_comision: Number(form.monto_comision),
        })
      }
      setShowForm(false)
      cargar()
    } catch (err) {
      setFormError(
        err.response?.data?.message || 'Ocurrió un error al guardar la cuota.',
      )
    }
  }

  async function eliminar(cuota) {
    if (!confirm(`¿Eliminar la cuota de ${cuota.usuario?.nombre} para esa semana?`)) return
    try {
      await client.delete(`/cuotas/${cuota.id}`)
      cargar()
    } catch {
      alert('No se pudo eliminar la cuota.')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Cuotas de venta</h1>
        <button
          onClick={abrirNuevo}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nueva cuota
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm border border-neutral-100 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-neutral-400 border-b border-neutral-100">
              <th className="px-4 py-3">Preventista</th>
              <th className="px-4 py-3">Semana</th>
              <th className="px-4 py-3">Objetivo</th>
              <th className="px-4 py-3">Comisión si cumple</th>
              <th className="px-4 py-3">Alcanzado</th>
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
            ) : cuotas.length ? (
              cuotas.map((c) => (
                <tr key={c.id} className="border-b border-neutral-50 last:border-0">
                  <td className="px-4 py-3">
                    {c.usuario ? `${c.usuario.nombre} ${c.usuario.apellidos}` : '—'}
                  </td>
                  <td className="px-4 py-3">
                    {c.fecha_inicio_semana} — {c.fecha_fin_semana}
                  </td>
                  <td className="px-4 py-3">${Number(c.monto_objetivo).toFixed(2)}</td>
                  <td className="px-4 py-3">${Number(c.monto_comision).toFixed(2)}</td>
                  <td className="px-4 py-3">${Number(c.monto_alcanzado ?? 0).toFixed(2)}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                        c.cumplida
                          ? 'bg-green-100 text-green-700'
                          : 'bg-yellow-100 text-yellow-700'
                      }`}
                    >
                      {c.cumplida ? 'Cumplida' : 'En progreso'}
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
                  No hay cuotas registradas.
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
              {editingId ? 'Editar cuota' : 'Nueva cuota'}
            </h2>
            <form onSubmit={guardar} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Preventista</label>
                <select
                  value={form.usuario_id}
                  onChange={(e) => setForm({ ...form, usuario_id: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary disabled:bg-neutral-100"
                  required
                  disabled={!!editingId}
                >
                  <option value="">Selecciona un preventista</option>
                  {preventistas.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.nombre} {p.apellidos}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex gap-2">
                <div className="flex-1">
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Inicio de semana</label>
                  <input
                    type="date"
                    value={form.fecha_inicio_semana}
                    onChange={(e) =>
                      setForm({ ...form, fecha_inicio_semana: e.target.value })
                    }
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary disabled:bg-neutral-100"
                    required
                    disabled={!!editingId}
                  />
                </div>
                <div className="flex-1">
                  <label className="block text-sm font-medium text-neutral-700 mb-1">Fin de semana</label>
                  <input
                    type="date"
                    value={form.fecha_fin_semana}
                    onChange={(e) => setForm({ ...form, fecha_fin_semana: e.target.value })}
                    className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary disabled:bg-neutral-100"
                    required
                    disabled={!!editingId}
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Monto objetivo (meta de ventas de la semana)
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={form.monto_objetivo}
                  onChange={(e) => setForm({ ...form, monto_objetivo: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Comisión si cumple la meta
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={form.monto_comision}
                  onChange={(e) => setForm({ ...form, monto_comision: e.target.value })}
                  className="w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
                  required
                />
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