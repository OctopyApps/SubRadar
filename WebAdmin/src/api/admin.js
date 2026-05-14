import { api } from './client'

export const adminApi = {
  // Статистика
  stats: () => api.get('/admin/stats'),

  // Пользователи
  listUsers:  (params = {}) => {
    const q = new URLSearchParams()
    if (params.limit)  q.set('limit',  params.limit)
    if (params.offset) q.set('offset', params.offset)
    if (params.role)   q.set('role',   params.role)
    if (params.search) q.set('search', params.search)
    return api.get(`/admin/users?${q}`)
  },
  getUser:    (id)          => api.get(`/admin/users/${id}`),
  updateUser: (id, data)    => api.patch(`/admin/users/${id}`, data),
  deleteUser: (id)          => api.delete(`/admin/users/${id}`),

  // Системные категории
  listCategories:  ()             => api.get('/admin/categories'),
  createCategory:  (name, icon)   => api.post('/admin/categories', { name, icon }),
  deleteCategory:  (id)           => api.delete(`/admin/categories/${id}`),
}
