import { useAuth } from '../context/AuthContext'

export default function Header() {
  const { user, logout } = useAuth()

  return (
    <header className="h-16 bg-white border-b border-neutral-100 flex items-center justify-between px-6">
      <div className="relative">
        <input
          type="text"
          placeholder="Buscar..."
          className="w-72 rounded-lg border border-neutral-200 bg-tertiary px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-secondary"
        />
      </div>
      <div className="flex items-center gap-4">
        <span className="text-sm text-neutral-600">
          {user?.name ?? user?.usuario ?? 'Usuario'}
        </span>
        <button
          onClick={logout}
          className="text-sm font-medium text-primary hover:text-primary-600"
        >
          Cerrar sesión
        </button>
      </div>
    </header>
  )
}
