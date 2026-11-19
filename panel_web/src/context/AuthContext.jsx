import { createContext, useContext, useEffect, useState } from 'react'
import client from '../api/client'

const AuthContext = createContext(null)

// Rol de preventista (colaborador): solo usa la app móvil, no el panel.
const ROL_COLABORADOR = 2
const esColaborador = (u) => Number(u?.rol_id) === ROL_COLABORADOR

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const token = localStorage.getItem('pt_token')
    if (!token) {
      setLoading(false)
      return
    }
    client
      .get('/me')
      .then((res) => {
        if (esColaborador(res.data)) {
          localStorage.removeItem('pt_token')
          return
        }
        setUser(res.data)
      })
      .catch(() => localStorage.removeItem('pt_token'))
      .finally(() => setLoading(false))
  }, [])

  async function login(usuario, password) {
    const res = await client.post('/login', { usuario, password })

    if (esColaborador(res.data.usuario)) {
      // Se cierra la sesión que se acaba de crear en el servidor y se rechaza el acceso.
      try {
        await client.post('/logout', null, {
          headers: { Authorization: `Bearer ${res.data.token}` },
        })
      } catch {
        // si falla, igual no se guarda el token en el navegador
      }
      const error = new Error('Acceso denegado')
      error.response = {
        data: { message: 'Este usuario es preventista. Solo puede usar la app móvil.' },
      }
      throw error
    }

    localStorage.setItem('pt_token', res.data.token)
    setUser(res.data.usuario ?? null)
    return res.data
  }

  async function logout() {
    try {
      await client.post('/logout')
    } finally {
      localStorage.removeItem('pt_token')
      setUser(null)
    }
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return ctx
}