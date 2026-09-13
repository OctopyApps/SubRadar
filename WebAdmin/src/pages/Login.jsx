import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/store/auth.jsx'
import { authApi } from '@/api/auth'

// ── Иконка SubRadar ────────────────────────────────────────────────────────────
function SubRadarLogo() {
  return (
      <img src="/logo.svg" alt="SubRadar" className="w-16 h-16" />
  )
}

// ── Таб-переключатель ──────────────────────────────────────────────────────────
function TabSwitch({ active, onChange }) {
  return (
    <div className="flex rounded-xl p-1 mb-6"
         style={{ backgroundColor: 'var(--sr-surface2)' }}>
      {['email', 'selfhosted'].map((tab) => (
        <button
          key={tab}
          onClick={() => onChange(tab)}
          className="flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all duration-200"
          style={{
            backgroundColor: active === tab ? 'var(--sr-surface)' : 'transparent',
            color: active === tab ? 'var(--sr-text-primary)' : 'var(--sr-text-secondary)',
            boxShadow: active === tab ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
          }}
        >
          {tab === 'email' ? 'Email / пароль' : 'Свой сервер'}
        </button>
      ))}
    </div>
  )
}

// ── Поле ввода ─────────────────────────────────────────────────────────────────
function Field({ label, type = 'text', value, onChange, placeholder, autoComplete }) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-semibold uppercase tracking-wide"
             style={{ color: 'var(--sr-text-secondary)', letterSpacing: '0.05em' }}>
        {label}
      </label>
      <input
        type={type}
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        autoComplete={autoComplete}
        className="input"
      />
    </div>
  )
}

// ── Сообщение об ошибке ────────────────────────────────────────────────────────
function ErrorBanner({ message }) {
  if (!message) return null
  return (
    <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl text-sm animate-fade-in"
         style={{ backgroundColor: 'rgba(255,59,48,0.08)', color: 'var(--sr-danger)' }}>
      <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
        <path fillRule="evenodd" d="M8 1a7 7 0 100 14A7 7 0 008 1zM7 5a1 1 0 012 0v3a1 1 0 01-2 0V5zm1 6a1 1 0 100-2 1 1 0 000 2z"/>
      </svg>
      {message}
    </div>
  )
}

// ── Форма email/пароль ─────────────────────────────────────────────────────────
function EmailForm({ onSuccess }) {
  const [email,    setEmail]    = useState('')
  const [password, setPassword] = useState('')
  const [loading,  setLoading]  = useState(false)
  const [error,    setError]    = useState('')

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await authApi.login(email, password)
      await onSuccess(res.token)
    } catch (err) {
      setError(err.message ?? 'Ошибка входа')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Field label="Email" type="email" value={email} onChange={setEmail}
             placeholder="admin@example.com" autoComplete="email" />
      <Field label="Пароль" type="password" value={password} onChange={setPassword}
             placeholder="••••••••" autoComplete="current-password" />
      <ErrorBanner message={error} />
      <button type="submit" className="btn-primary mt-1" disabled={loading || !email || !password}>
        {loading ? 'Вход...' : 'Войти'}
      </button>
    </form>
  )
}

// ── Форма self-hosted ──────────────────────────────────────────────────────────
function SelfHostedForm({ onSuccess }) {
  const [secret,  setSecret]  = useState('')
  const [loading, setLoading] = useState(false)
  const [error,   setError]   = useState('')

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await authApi.selfHosted(secret)
      await onSuccess(res.token)
    } catch (err) {
      setError(err.message ?? 'Неверный ключ')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex items-start gap-3 px-3 py-3 rounded-xl text-sm"
           style={{ backgroundColor: 'var(--sr-accent-light)', color: 'var(--sr-accent)' }}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" className="mt-0.5 shrink-0">
          <path fillRule="evenodd" d="M8 1a7 7 0 100 14A7 7 0 008 1zM7 5a1 1 0 012 0v3a1 1 0 01-2 0V5zm1 6a1 1 0 100-2 1 1 0 000 2z"/>
        </svg>
        <span style={{ color: 'var(--sr-text-secondary)' }}>
          Секретный ключ находится в{' '}
          <code className="font-mono text-xs px-1 py-0.5 rounded"
                style={{ backgroundColor: 'var(--sr-surface2)' }}>
            /etc/subradar/config.yaml
          </code>
          {' '}→ <code className="font-mono text-xs">auth.server_secret</code>
        </span>
      </div>
      <Field label="Секретный ключ" type="password" value={secret} onChange={setSecret}
             placeholder="server_secret из config.yaml" autoComplete="off" />
      <ErrorBanner message={error} />
      <button type="submit" className="btn-primary mt-1 text-sm"
              disabled={loading || !secret}
              style={{ backgroundColor: loading || !secret ? undefined : 'var(--sr-teal)' }}>
        {loading ? 'Проверка...' : 'Подключиться'}
      </button>
    </form>
  )
}

// ── Главный экран входа ────────────────────────────────────────────────────────
export default function Login() {
  const [tab, setTab] = useState('email')
  const { login }     = useAuth()
  const navigate      = useNavigate()

  async function handleSuccess(token) {
    const user = await login(token)
    if (user.role !== 'admin') {
      throw new Error('Доступ только для администраторов')
    }
    navigate('/dashboard', { replace: true })
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4"
         style={{ backgroundColor: 'var(--sr-background)' }}>

      {/* Карточка */}
      <div className="w-full max-w-sm animate-slide-up">
        {/* Лого + заголовок */}
        <div className="flex flex-col items-center gap-3 mb-8">
          <SubRadarLogo />
          <div className="text-center">
            <h1 className="text-2xl font-bold tracking-tight"
                style={{ color: 'var(--sr-text-primary)', letterSpacing: '-0.3px' }}>
              SubRadar Admin
            </h1>
            <p className="text-sm mt-1" style={{ color: 'var(--sr-text-secondary)' }}>
              Панель управления
            </p>
          </div>
        </div>

        {/* Форма */}
        <div className="card p-6">
          <TabSwitch active={tab} onChange={setTab} />
          {tab === 'email'
            ? <EmailForm      onSuccess={handleSuccess} />
            : <SelfHostedForm onSuccess={handleSuccess} />
          }
        </div>

        {/* Подвал */}
        <p className="text-center text-xs mt-6" style={{ color: 'var(--sr-text-tertiary)' }}>
          <p>SubRadar v{__APP_VERSION__} · open source</p>
        </p>
      </div>
    </div>
  )
}
