import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from '@/store/auth'
import LoginPage      from '@/pages/Login'
import DashboardPage  from '@/pages/Dashboard'
import UsersPage      from '@/pages/Users'
import UserDetailPage from '@/pages/UserDetail'
import CategoriesPage from '@/pages/Categories'
import Layout         from '@/components/Layout'

// Защищённый маршрут — редиректит на /login если нет токена
function PrivateRoute({ children }) {
  const { user, loading } = useAuth()
  if (loading) return <div className="min-h-screen bg-sr-background" />
  if (!user)   return <Navigate to="/login" replace />
  if (user.role !== 'admin') return (
    <div className="min-h-screen flex items-center justify-center bg-sr-background">
      <p className="text-secondary text-sm">Доступ только для администраторов</p>
    </div>
  )
  return children
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={
        <PrivateRoute>
          <Layout />
        </PrivateRoute>
      }>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard"       element={<DashboardPage />} />
        <Route path="users"           element={<UsersPage />} />
        <Route path="users/:id"       element={<UserDetailPage />} />
        <Route path="categories"      element={<CategoriesPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}
