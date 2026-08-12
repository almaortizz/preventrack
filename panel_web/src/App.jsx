import { Routes, Route } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import DashboardLayout from './layouts/DashboardLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Placeholder from './pages/Placeholder'

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
          <Route path="clientes" element={<Placeholder title="Clientes" />} />
          <Route
            path="productos"
            element={<Placeholder title="Productos" />}
          />
          <Route
            path="categorias"
            element={<Placeholder title="Categorías" />}
          />
          <Route path="ventas" element={<Placeholder title="Ventas" />} />
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