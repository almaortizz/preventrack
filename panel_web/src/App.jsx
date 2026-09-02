import { Routes, Route } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import DashboardLayout from './layouts/DashboardLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Placeholder from './pages/Placeholder'
import Clientes from './pages/Clientes'
import Categorias from './pages/Categorias'
import Productos from './pages/Productos'
import Preventistas from './pages/Preventistas'
import Ventas from './pages/Ventas'
import Reportes from './pages/Reportes'

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="clientes" element={<Clientes />} />
          <Route path="preventistas" element={<Preventistas />} />
          <Route path="reportes" element={<Reportes />} />
          <Route
            path="productos"
            element={<Productos />}
            />
          <Route
          path="categorias"
          element={<Categorias />}
          />

          <Route path="ventas" element={<Ventas />} />
          <Route
            path="cotizaciones"
            element={<Placeholder title="Cotizaciones" />}
          />
          <Route path="rutas" element={<Placeholder title="Rutas" />} />
          <Route path="visitas" element={<Placeholder title="Visitas" />} />
          <Route
            path="reportes"
            element={<Placeholder title="Reportes" />}
          />
        </Route>
      </Routes>
    </AuthProvider>
  )
}