import { useEffect, useRef, useState } from 'react'
import { useAuth } from '../context/AuthContext'

export default function Header() {
  const { user, logout } = useAuth()
  const [abierto, setAbierto] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    function cerrarFuera(e) {
      if (ref.current && !ref.current.contains(e.target)) setAbierto(false)
    }
    document.addEventListener('mousedown', cerrarFuera)
    return () => document.removeEventListener('mousedown', cerrarFuera)
  }, [])

  const nombreCompleto =
    [user?.nombre, user?.apellidos].filter(Boolean).join(' ') ||
    user?.name ||
    user?.usuario ||
    'Usuario'

  const filas = [
    ['Usuario', user?.usuario],
    ['Teléfono', user?.telefono],
    ['Dirección', user?.direccion],
    ['Rol', user?.rol?.nombre],
  ].filter(([, v]) => v)

  return (
    <header className="h-16 bg-white border-b border-neutral-100 flex items-center justify-between px-6">
      <input
        type="text"
        placeholder="Buscar..."
        className="w-72 rounded-lg border border-neutral-200 bg-tertiary px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
      />
      <div className="relative" ref={ref}>
        <button
          type="button"
          onClick={() => setAbierto(!abierto)}
          title="Mi perfil"
          aria-label="Mi perfil"
          className="flex items-center justify-center w-10 h-10 rounded-full bg-primary text-white hover:opacity-90"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="8" r="4" /><path d="M4 21c0-4 4-6 8-6s8 2 8 6" />
          </svg>
        </button>

        {abierto && (
          <div className="absolute right-0 mt-2 w-72 bg-white rounded-xl shadow-lg border border-neutral-100 z-50">
            <div className="flex items-center gap-3 p-4 border-b border-neutral-100">
              <div className="flex items-center justify-center w-12 h-12 rounded-full bg-primary text-white shrink-0">
                <svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="8" r="4" /><path d="M4 21c0-4 4-6 8-6s8 2 8 6" />
                </svg>
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-neutral-800 truncate">{nombreCompleto}</p>
                <p className="text-xs text-neutral-400">Administrador</p>
              </div>
            </div>
            {filas.length > 0 && (
              <dl className="p-4 space-y-2 text-sm">
                {filas.map(([k, v]) => (
                  <div key={k} className="flex justify-between gap-3">
                    <dt className="text-neutral-400">{k}</dt>
                    <dd className="text-neutral-700 text-right">{v}</dd>
                  </div>
                ))}
              </dl>
            )}
            <button
              onClick={logout}
              className="w-full flex items-center gap-2 px-4 py-3 border-t border-neutral-100 text-sm font-medium text-red-600 hover:bg-neutral-50 rounded-b-xl"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><path d="M16 17l5-5-5-5" /><path d="M21 12H9" />
              </svg>
              Cerrar sesión
            </button>
          </div>
        )}
      </div>
    </header>
  )
}
