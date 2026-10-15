import { useEffect, useState } from 'react'
import client from '../api/client'

const ROL_COLABORADOR = 2

// ── Fechas en hora local (México), no en UTC ──
function aISO(fecha) {
  const y = fecha.getFullYear()
  const m = String(fecha.getMonth() + 1).padStart(2, '0')
  const d = String(fecha.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function desdeISO(iso) {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}

// Lunes de la semana de cualquier fecha (el domingo pertenece a la semana anterior)
function lunesDe(iso) {
  const fecha = desdeISO(iso)
  const dia = fecha.getDay() // 0 = domingo
  fecha.setDate(fecha.getDate() - (dia === 0 ? 6 : dia - 1))
  return aISO(fecha)
}

function sumarDias(iso, dias) {
  const fecha = desdeISO(iso)
  fecha.setDate(fecha.getDate() + dias)
  return aISO(fecha)
}

// "Del lunes 12 al sábado 17 de octubre" (las cuotas son de lunes a sábado)
function textoSemana(lunesISO) {
  const lunes = desdeISO(lunesISO)
  const sabado = desdeISO(sumarDias(lunesISO, 5))
  const mes = (f) => f.toLocaleDateString('es-MX', { month: 'long' })
  const inicio =
    mes(lunes) === mes(sabado) ? `${lunes.getDate()}` : `${lunes.getDate()} de ${mes(lunes)}`
  return `Del lunes ${inicio} al sábado ${sabado.getDate()} de ${mes(sabado)}`
}

const formEdicionVacio = { monto_objetivo: '', monto_comision: '' }

export default function Cuotas() {
  const [cuotas, setCuotas] = useState([])
  const [preventistas, setPreventistas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')

  // Nueva cuota (varios preventistas a la vez)
  const [showNueva, setShowNueva] = useState(false)
  const [semana, setSemana] = useState(lunesDe(aISO(new Date())))
  const [generales, setGenerales] = useState({ monto_objetivo: '', monto_comision: '' })
  const [filas, setFilas] = useState({}) // { usuarioId: { seleccionado, monto_objetivo, monto_comision } }
  const [conCuota, setConCuota] = useState([]) // ids que ya tienen cuota esa semana
  const [guardando, setGuardando] = useState(false)

  // Editar montos de una cuota existente
  const [editando, setEditando] = useState(null)
  const [formEdicion, setFormEdicion] = useState(formEdicionVacio)

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

  // Al abrir el formulario o cambiar de semana: quién ya tiene cuota esa semana
  useEffect(() => {
    if (!showNueva) return
    client
      .get('/cuotas', { params: { semana } })
      .then((res) => setConCuota((res.data.data ?? []).map((c) => c.usuario_id)))
      .catch(() => setConCuota([]))
  }, [showNueva, semana])

  function abrirNueva() {
    const inicial = {}
    preventistas.forEach((p) => {
      inicial[p.id] = { seleccionado: true, monto_objetivo: '', monto_comision: '' }
    })
    setFilas(inicial)
    setGenerales({ monto_objetivo: '', monto_comision: '' })
    setSemana(lunesDe(aISO(new Date())))
    setFormError('')
    setShowNueva(true)
  }

  // Preventistas a los que sí se les puede crear cuota esa semana
  const disponibles = preventistas.filter((p) => !conCuota.includes(p.id))
  const seleccionados = disponibles.filter((p) => filas[p.id]?.seleccionado)
  const todosMarcados = disponibles.length > 0 && seleccionados.length === disponibles.length

  function cambiarFila(id, cambios) {
    setFilas((prev) => ({ ...prev, [id]: { ...prev[id], ...cambios } }))
  }

  function marcarTodos(valor) {
    setFilas((prev) => {
      const nuevo = { ...prev }
      disponibles.forEach((p) => {
        nuevo[p.id] = { ...nuevo[p.id], seleccionado: valor }
      })
      return nuevo
    })
  }

  function aplicarATodos() {
    setFilas((prev) => {
      const nuevo = { ...prev }
      disponibles.forEach((p) => {
        nuevo[p.id] = {
          ...nuevo[p.id],
          monto_objetivo: generales.monto_objetivo,
          monto_comision: generales.monto_comision,
        }
      })
      return nuevo
    })
  }

  async function crearCuotas(e) {
    e.preventDefault()
    setFormError('')

    if (!seleccionados.length) {
      setFormError('Selecciona al menos un preventista.')
      return
    }
    const incompleto = seleccionados.find(
      (p) => filas[p.id].monto_objetivo === '' || filas[p.id].monto_comision === '',
    )
    if (incompleto) {
      setFormError(
        `Falta el objetivo o la comisión de ${incompleto.nombre} ${incompleto.apellidos}.`,
      )
      return
    }

    setGuardando(true)
    try {
      const res = await client.post('/cuotas/lote', {
        fecha_inicio_semana: semana,
        cuotas: seleccionados.map((p) => ({
          usuario_id: p.id,
          monto_objetivo: Number(filas[p.id].monto_objetivo),
          monto_comision: Number(filas[p.id].monto_comision),
        })),
      })
      const omitidos = res.data.omitidos ?? []
      setAviso(
        res.data.message +
          (omitidos.length ? ` Ya tenían cuota esa semana: ${omitidos.join(', ')}.` : ''),
      )
      setShowNueva(false)
      cargar()
    } catch (err) {
      setFormError(err.response?.data?.message || 'Ocurrió un error al crear las cuotas.')
    } finally {
      setGuardando(false)
    }
  }

  function abrirEditar(cuota) {
    setFormEdicion({
      monto_objetivo: cuota.monto_objetivo,
      monto_comision: cuota.monto_comision,
    })
    setEditando(cuota)
    setFormError('')
  }

  async function guardarEdicion(e) {
    e.preventDefault()
    setFormError('')
    try {
      // Solo el monto se puede editar una vez creada
      await client.put(`/cuotas/${editando.id}`, {
        monto_objetivo: Number(formEdicion.monto_objetivo),
        monto_comision: Number(formEdicion.monto_comision),
      })
      setEditando(null)
      cargar()
    } catch (err) {
      setFormError(err.response?.data?.message || 'Ocurrió un error al guardar la cuota.')
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

  const inputClase =
    'w-full rounded-lg border border-neutral-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary'

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-800">Cuotas de venta</h1>
        <button
          onClick={abrirNueva}
          className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
        >
          + Nueva cuota
        </button>
      </div>

      {error && <p className="text-red-600 text-sm mb-4">{error}</p>}
      {aviso && (
        <div className="mb-4 flex items-start justify-between gap-3 rounded-lg bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-800">
          <span>{aviso}</span>
          <button onClick={() => setAviso('')} className="font-semibold hover:underline">
            Cerrar
          </button>
        </div>
      )}

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

      {/* ── Nueva cuota: varios preventistas a la vez ── */}
      {showNueva && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-primary mb-4">Nueva cuota</h2>
            <form onSubmit={crearCuotas} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">Semana</label>
                <input
                  type="date"
                  value={semana}
                  onChange={(e) => e.target.value && setSemana(lunesDe(e.target.value))}
                  className={inputClase}
                  required
                />
                <p className="text-xs text-neutral-500 mt-1">
                  {textoSemana(semana)} (elige cualquier día: se ajusta al lunes)
                </p>
              </div>

              <div className="rounded-lg bg-neutral-50 border border-neutral-100 p-3">
                <p className="text-sm font-medium text-neutral-700 mb-2">Montos para todos</p>
                <div className="flex flex-wrap items-end gap-2">
                  <div className="flex-1 min-w-[140px]">
                    <label className="block text-xs text-neutral-500 mb-1">
                      Objetivo (meta de ventas)
                    </label>
                    <input
                      type="number"
                      min="0"
                      step="0.01"
                      value={generales.monto_objetivo}
                      onChange={(e) =>
                        setGenerales({ ...generales, monto_objetivo: e.target.value })
                      }
                      className={inputClase}
                    />
                  </div>
                  <div className="flex-1 min-w-[140px]">
                    <label className="block text-xs text-neutral-500 mb-1">
                      Comisión si cumple
                    </label>
                    <input
                      type="number"
                      min="0"
                      step="0.01"
                      value={generales.monto_comision}
                      onChange={(e) =>
                        setGenerales({ ...generales, monto_comision: e.target.value })
                      }
                      className={inputClase}
                    />
                  </div>
                  <button
                    type="button"
                    onClick={aplicarATodos}
                    className="px-4 py-2 rounded-lg border border-secondary text-secondary font-medium hover:bg-secondary/10"
                  >
                    Aplicar a todos
                  </button>
                </div>
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm font-medium text-neutral-700 mb-2">
                  <input
                    type="checkbox"
                    checked={todosMarcados}
                    onChange={(e) => marcarTodos(e.target.checked)}
                    disabled={!disponibles.length}
                  />
                  Seleccionar todos
                </label>

                <div className="border border-neutral-100 rounded-lg divide-y divide-neutral-100">
                  {preventistas.length ? (
                    preventistas.map((p) => {
                      const yaTiene = conCuota.includes(p.id)
                      const fila = filas[p.id] ?? {}
                      return (
                        <div
                          key={p.id}
                          className={`flex flex-wrap items-center gap-2 px-3 py-2 ${
                            yaTiene ? 'bg-neutral-50 text-neutral-400' : ''
                          }`}
                        >
                          <label className="flex items-center gap-2 flex-1 min-w-[180px] text-sm">
                            <input
                              type="checkbox"
                              checked={!yaTiene && !!fila.seleccionado}
                              onChange={(e) => cambiarFila(p.id, { seleccionado: e.target.checked })}
                              disabled={yaTiene}
                            />
                            {p.nombre} {p.apellidos}
                          </label>
                          {yaTiene ? (
                            <span className="text-xs italic">ya tiene cuota esta semana</span>
                          ) : (
                            <>
                              <input
                                type="number"
                                min="0"
                                step="0.01"
                                placeholder="Objetivo"
                                value={fila.monto_objetivo ?? ''}
                                onChange={(e) =>
                                  cambiarFila(p.id, { monto_objetivo: e.target.value })
                                }
                                disabled={!fila.seleccionado}
                                className="w-28 rounded-lg border border-neutral-200 px-2 py-1 text-sm disabled:bg-neutral-100"
                              />
                              <input
                                type="number"
                                min="0"
                                step="0.01"
                                placeholder="Comisión"
                                value={fila.monto_comision ?? ''}
                                onChange={(e) =>
                                  cambiarFila(p.id, { monto_comision: e.target.value })
                                }
                                disabled={!fila.seleccionado}
                                className="w-28 rounded-lg border border-neutral-200 px-2 py-1 text-sm disabled:bg-neutral-100"
                              />
                            </>
                          )}
                        </div>
                      )
                    })
                  ) : (
                    <p className="px-3 py-4 text-sm text-neutral-400 text-center">
                      No hay preventistas activos.
                    </p>
                  )}
                </div>
              </div>

              {formError && <p className="text-red-600 text-sm">{formError}</p>}

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowNueva(false)}
                  className="px-4 py-2 rounded-lg text-neutral-600 hover:bg-neutral-100"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={guardando || !seleccionados.length}
                  className="bg-primary text-white font-semibold px-4 py-2 rounded-lg hover:bg-primary/90 disabled:opacity-50"
                >
                  {guardando
                    ? 'Creando...'
                    : `Crear ${seleccionados.length} cuota${seleccionados.length === 1 ? '' : 's'}`}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Editar montos de una cuota existente ── */}
      {editando && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center px-4 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-bold text-primary mb-1">Editar cuota</h2>
            <p className="text-sm text-neutral-500 mb-4">
              {editando.usuario
                ? `${editando.usuario.nombre} ${editando.usuario.apellidos}`
                : '—'}{' '}
              · {editando.fecha_inicio_semana} — {editando.fecha_fin_semana}
            </p>
            <form onSubmit={guardarEdicion} className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Monto objetivo (meta de ventas de la semana)
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formEdicion.monto_objetivo}
                  onChange={(e) =>
                    setFormEdicion({ ...formEdicion, monto_objetivo: e.target.value })
                  }
                  className={inputClase}
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
                  value={formEdicion.monto_comision}
                  onChange={(e) =>
                    setFormEdicion({ ...formEdicion, monto_comision: e.target.value })
                  }
                  className={inputClase}
                  required
                />
              </div>

              {formError && <p className="text-red-600 text-sm">{formError}</p>}

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setEditando(null)}
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
