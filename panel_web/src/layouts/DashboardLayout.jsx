import { Outlet } from 'react-router-dom'
import Sidebar from '../components/Sidebar'
import Header from '../components/Header'

export default function DashboardLayout() {
  return (
    <div className="flex min-h-screen bg-tertiary">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header />
        <main className="flex-1 p-6">
          <Outlet />
        </main>
        <footer className="text-center py-5">
          <span className="inline-block border-t border-neutral-300 pt-3 px-2 text-sm text-neutral-500">
            © 2026 Sistema Web PreventTrack
          </span>
        </footer>
      </div>
    </div>
  )
}