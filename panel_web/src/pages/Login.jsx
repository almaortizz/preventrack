import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function Login() {
  const [usuario, setUsuario] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(usuario, password)
      navigate('/')
    } catch (err) {
      setError(
        err.response?.data?.message || 'Usuario o contraseña incorrectos',
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-tertiary px-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg p-8">
      <div className="flex justify-center mb-4">
     <img src="/logo.png" alt="PreventTrack" className="h-24 w-24" />
   </div>
        <h1 className="text-2xl font-bold text-primary text-center mb-1">
          Bienvenido
        </h1>
        <p className="text-neutral-400 text-center mb-6">
          Panel administrativo
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
       <div>
  <label className="block text-sm font-medium text-neutral-700 mb-1">
    Usuario
  </label>
  <div className="relative">
    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-neutral-400">
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="8" r="4" />
        <path d="M4 20c0-4 4-6 8-6s8 2 8 6" />
      </svg>
    </span>
    <input
      type="text"
      value={usuario}
      onChange={(e) => setUsuario(e.target.value)}
      className="w-full rounded-lg border border-neutral-200 pl-10 pr-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
      required
    />
  </div>
</div>
         <div>
  <label className="block text-sm font-medium text-neutral-700 mb-1">
    Contraseña
  </label>
  <div className="relative">
    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-neutral-400">
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="11" width="18" height="10" rx="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
      </svg>
    </span>
    <input
      type="password"
      value={password}
      onChange={(e) => setPassword(e.target.value)}
      className="w-full rounded-lg border border-neutral-200 pl-10 pr-3 py-2 focus:outline-none focus:ring-2 focus:ring-secondary"
      required
    />
  </div>
</div>

          {error && <p className="text-red-600 text-sm">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-primary text-white font-semibold py-2 rounded-lg transition-colors disabled:opacity-60"
          >
            {loading ? 'Ingresando...' : 'Ingresar'}
          </button>
        </form>
      </div>
    </div>
  )
}