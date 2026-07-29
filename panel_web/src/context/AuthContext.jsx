import { createContext, useContext, useEffect, useState } from 'react'
import client from '../api/client'

const AuthContext = createContext(null)

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
      .then((res) => setUser(res.data))
      .catch(() => localStorage.removeItem('pt_token'))
      .finally(() => setLoading(false))
  }, [])

  async function login(usuario, password) {
    const res = await client.post('/login', { usuario, password })
    localStorage.setItem('pt_token', res.data.token)
    setUser(res.data.user ?? null)
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
