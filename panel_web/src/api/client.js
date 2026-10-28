import axios from 'axios'

// Cambia esta URL si tu backend Laravel corre en otro host/puerto.
 const API_BASE_URL = 'http://preventrack.local/api'

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