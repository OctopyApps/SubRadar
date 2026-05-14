import { api } from './client'

export const authApi = {
  login:      (email, password) => api.post('/auth/login', { email, password }),
  selfHosted: (secret)          => api.post('/auth/self-hosted', { secret }),
  me:         ()                => api.get('/auth/me'),
}
