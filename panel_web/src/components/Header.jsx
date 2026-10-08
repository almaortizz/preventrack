import { useAuth } from '../context/AuthContext'

export default function Header() {
  const { user, logout } = useAuth()

  return (
    <header className="h-16 bg-white border-b border-neutral-100 flex items-center justify-between px-6">
      <input
        type="text"
        placeholder="Buscar..."
        className="w-72 rounded-lg border border-neutral-200 bg-tertiary px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
      />
      <div className="flex items-center gap-4">
        <span className="text-sm text-neutral-600">
          {user?.name ?? user?.usuario ?? 'Usuario'}
        </span>
        <button
          onClick={logout}
          title="Cerrar sesión"
          aria-label="Cerrar sesión"
          className="flex items-center gap-2 text-sm font-medium text-primary hover:text-primary/80"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><path d="M16 17l5-5-5-5" /><path d="M21 12H9" />
          </svg>
        </button>
      </div>
    </header>
  )
}
