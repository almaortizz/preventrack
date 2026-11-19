// Barra para moverse entre las páginas de una lista paginada de la API.
// `meta` es la respuesta de Laravel (current_page, last_page, total).
export default function Paginacion({ meta, onCambiar }) {
  if (!meta || !meta.last_page || meta.last_page <= 1) {
    return meta?.total ? (
      <p className="text-xs text-neutral-400 mt-3 text-right">
        {meta.total} registro{meta.total === 1 ? '' : 's'}
      </p>
    ) : null
  }

  const actual = meta.current_page
  const ultima = meta.last_page
  const boton =
    'px-3 py-1.5 rounded-lg text-sm font-semibold text-secondary hover:bg-neutral-100 disabled:opacity-40 disabled:hover:bg-transparent'

  return (
    <div className="flex items-center justify-end gap-3 mt-3">
      <button className={boton} disabled={actual <= 1} onClick={() => onCambiar(actual - 1)}>
        ← Anterior
      </button>
      <span className="text-sm text-neutral-600">
        Página {actual} de {ultima}
        <span className="text-neutral-400"> ({meta.total} registros)</span>
      </span>
      <button className={boton} disabled={actual >= ultima} onClick={() => onCambiar(actual + 1)}>
        Siguiente →
      </button>
    </div>
  )
}
