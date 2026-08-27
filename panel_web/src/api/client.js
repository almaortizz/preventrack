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

export default client