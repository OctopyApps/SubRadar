// Базовый URL — в dev идёт через vite proxy (/api → localhost:8080)
// В продакшене берётся из переменной окружения
const BASE_URL = import.meta.env.VITE_API_URL ?? '/api'

// ── Хранение токена ────────────────────────────────────────────────────
export const tokenStorage = {
  get:    ()      => localStorage.getItem('sr_admin_token'),
  set:    (token) => localStorage.setItem('sr_admin_token', token),
  remove: ()      => localStorage.removeItem('sr_admin_token'),
}

// ── Базовый fetch ──────────────────────────────────────────────────────

class ApiError extends Error {
  constructor(status, message) {
    super(message)
    this.status = status
  }
}

async function request(method, path, body) {
  const token = tokenStorage.get()
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers['Authorization'] = `Bearer ${token}`

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  })

  // 401 — токен протух, разлогиниваем
  if (res.status === 401) {
    tokenStorage.remove()
    window.location.href = '/login'
    throw new ApiError(401, 'Сессия истекла')
  }

  const data = await res.json().catch(() => ({}))

  if (!res.ok) {
    throw new ApiError(res.status, data.error ?? `Ошибка ${res.status}`)
  }

  return data
}

export const api = {
  get:    (path)        => request('GET',    path),
  post:   (path, body)  => request('POST',   path, body),
  patch:  (path, body)  => request('PATCH',  path, body),
  delete: (path)        => request('DELETE', path),
}
