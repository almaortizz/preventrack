import axios from 'axios'

// Dirección de la API. Se puede cambiar en cada PC sin tocar el código con
// VITE_API_URL en panel_web/.env.local (ese archivo no se sube a git), p. ej.
// VITE_API_URL=http://127.0.0.1:8000/api. Si no está, se usa la de siempre.
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://preventrack.local/api'

const client = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    Accept: 'application/json',
  },
})

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('pt_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Había una sesión abierta y la API ya no la acepta (p. ej. se bloqueó
      // al usuario): se avisa en la pantalla de inicio de sesión
      if (localStorage.getItem('pt_token')) {
        sessionStorage.setItem('pt_aviso_sesion', '1')
      }
      localStorage.removeItem('pt_token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  },
)

// Trae todas las páginas de una lista paginada de la API (de 100 en 100)
export async function obtenerTodos(url, params = {}) {
  let pagina = 1
  let todos = []
  for (;;) {
    const res = await client.get(url, {
      params: { ...params, per_page: 100, page: pagina },
    })
    const data = res.data
    if (Array.isArray(data)) return data
    todos = todos.concat(data.data ?? [])
    if (!data.last_page || pagina >= data.last_page) return todos
    pagina++
  }
}

export default client