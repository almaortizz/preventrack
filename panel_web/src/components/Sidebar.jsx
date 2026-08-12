import { NavLink } from 'react-router-dom'

const links = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/clientes', label: 'Clientes' },
  { to: '/productos', label: 'Productos' },
  { to: '/categorias', label: 'Categorías' },
  { to: '/ventas', label: 'Ventas' },
  { to: '/cotizaciones', label: 'Cotizaciones' },
  { to: '/rutas', label: 'Rutas' },
  { to: '/visitas', label: 'Visitas' },
  { to: '/reportes', label: 'Reportes' },
]

export default function Sidebar() {
  return (
    <aside className="w-64 bg-primary text-white flex flex-col min-h-screen">
      <div className="flex items-center gap-3 px-6 py-6 border-b border-white/10">
        <span className="font-bold text-lg">PreventTrack</span>
      </div>
      <nav className="flex-1 py-4 px-2 space-y-1">
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            end={link.end}
            className={({ isActive }) =>
              `block rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-secondary text-white'
                  : 'text-white/80 hover:bg-white/10 hover:text-white'
              }`
            }
          >
            {link.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}