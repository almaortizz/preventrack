import { useState } from 'react'
import { NavLink } from 'react-router-dom'

function Icono({ children }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0">
      {children}
    </svg>
  )
}

const links = [
  {
    to: '/', label: 'Dashboard', end: true,
    icon: (<Icono><rect x="3" y="3" width="7" height="9" rx="1" /><rect x="14" y="3" width="7" height="5" rx="1" /><rect x="14" y="12" width="7" height="9" rx="1" /><rect x="3" y="16" width="7" height="5" rx="1" /></Icono>),
  },
  {
    to: '/clientes', label: 'Clientes',
    icon: (<Icono><path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2" /><circle cx="10" cy="7" r="4" /><path d="M21 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></Icono>),
  },
  {
    to: '/preventistas', label: 'Preventistas',
    icon: (<Icono><circle cx="12" cy="8" r="4" /><path d="M4 21c0-4 4-6 8-6s8 2 8 6" /></Icono>),
  },
  {
    to: '/productos', label: 'Productos',
    icon: (<Icono><path d="M21 8l-9-5-9 5v8l9 5 9-5z" /><path d="M3 8l9 5 9-5" /><path d="M12 13v8" /></Icono>),
  },
  {
    to: '/categorias', label: 'Categorías',
    icon: (<Icono><path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z" /><circle cx="7.5" cy="7.5" r="1" /></Icono>),
  },
  {
    to: '/ventas', label: 'Ventas',
    icon: (<Icono><circle cx="9" cy="21" r="1" /><circle cx="20" cy="21" r="1" /><path d="M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6" /></Icono>),
  },
  {
    to: '/cuotas', label: 'Cuotas',
    icon: (<Icono><rect x="2" y="5" width="20" height="14" rx="2" /><path d="M2 10h20" /></Icono>),
  },
  {
    to: '/rutas', label: 'Rutas',
    icon: (<Icono><path d="M12 22s7-6.5 7-12a7 7 0 0 0-14 0c0 5.5 7 12 7 12z" /><circle cx="12" cy="10" r="2.5" /></Icono>),
  },
  {
    to: '/visitas', label: 'Visitas',
    icon: (<Icono><path d="M9 11l3 3L22 4" /><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" /></Icono>),
  },
  {
    to: '/reportes', label: 'Reportes',
    icon: (<Icono><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6" /><path d="M8 13h8" /><path d="M8 17h8" /></Icono>),
  },
  {
    to: '/administradores', label: 'Administradores',
    icon: (<Icono><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" /></Icono>),
  },
]

export default function Sidebar() {
  const [abierto, setAbierto] = useState(false)

  return (
    <aside className={`${abierto ? 'w-64' : 'w-16'} bg-primary text-white flex flex-col min-h-screen transition-all duration-200`}>
      <div className={`flex items-center py-6 border-b border-white/10 ${abierto ? 'justify-between px-6' : 'justify-center'}`}>
        {abierto && <span className="font-bold text-lg">PreventTrack</span>}
        <button
          type="button"
          onClick={() => setAbierto(!abierto)}
          className="p-1 rounded-lg hover:bg-white/10"
          aria-label="Mostrar u ocultar menú"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 6h18" /><path d="M3 12h18" /><path d="M3 18h18" />
          </svg>
        </button>
      </div>
      <nav className="flex-1 py-4 px-2 space-y-1">
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            end={link.end}
            title={link.label}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-lg py-2 text-sm font-medium transition-colors ${
                abierto ? 'px-4' : 'justify-center px-0'
              } ${
                isActive
                  ? 'bg-secondary text-white'
                  : 'text-white/80 hover:bg-white/10 hover:text-white'
              }`
            }
          >
            {link.icon}
            {abierto && link.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}
