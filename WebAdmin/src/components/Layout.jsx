import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '@/store/auth.jsx'

// ── Иконки навигации ───────────────────────────────────────────────────────────
function IconDashboard() {
    return (
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round">
            <rect x="2" y="2" width="6" height="6" rx="1.5"/>
            <rect x="10" y="2" width="6" height="6" rx="1.5"/>
            <rect x="2" y="10" width="6" height="6" rx="1.5"/>
            <rect x="10" y="10" width="6" height="6" rx="1.5"/>
        </svg>
    )
}

function IconUsers() {
    return (
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="7" cy="6" r="3"/>
            <path d="M1 16c0-3.314 2.686-5 6-5s6 1.686 6 5"/>
            <path d="M13 3.5a3 3 0 010 5M17 16c0-2.5-1.5-4.2-4-4.8" opacity="0.5"/>
        </svg>
    )
}

function IconCategories() {
    return (
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
            <path d="M2 5h14M2 9h9M2 13h6"/>
            <circle cx="14" cy="12" r="3"/>
            <path d="M16.5 14.5l1.5 1.5"/>
        </svg>
    )
}

function IconLogout() {
    return (
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
            <path d="M6 2H3a1 1 0 00-1 1v10a1 1 0 001 1h3M10 11l3-3-3-3M13 8H6"/>
        </svg>
    )
}

function IconSubRadar() {
    return (
        <img src="/logo.svg" alt="SubRadar" className="w-16 h-16" />
    )
}

// ── Пункт навигации ────────────────────────────────────────────────────────────
function NavItem({ to, icon, label }) {
    return (
        <NavLink
            to={to}
            className={({ isActive }) => [
                'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150',
                isActive
                    ? 'text-accent bg-accent-light'
                    : 'hover:bg-surface2',
            ].join(' ')}
            style={({ isActive }) => ({
                color: isActive ? 'var(--sr-accent)' : 'var(--sr-text-secondary)',
            })}
        >
            {icon}
            {label}
        </NavLink>
    )
}

// ── Аватар пользователя ────────────────────────────────────────────────────────
function UserAvatar({ user }) {
    const initials = (user.display_name || user.email)
        .split(/[\s@]/)
        .filter(Boolean)
        .slice(0, 2)
        .map(s => s[0].toUpperCase())
        .join('')

    return (
        <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0 text-xs font-semibold text-white"
             style={{ background: 'linear-gradient(135deg, #7B5EA7, #9B7FD4)' }}>
            {initials}
        </div>
    )
}

// ── Сайдбар ────────────────────────────────────────────────────────────────────
function Sidebar() {
    const { user, logout } = useAuth()
    const navigate         = useNavigate()

    function handleLogout() {
        logout()
        navigate('/login', { replace: true })
    }

    return (
        <aside className="w-56 shrink-0 flex flex-col border-r"
               style={{
                   backgroundColor: 'var(--sr-surface)',
                   borderColor:     'var(--sr-border)',
                   minHeight:       '100vh',
               }}>

            {/* Лого */}
            <div className="flex items-center gap-2.5 px-4 py-5 border-b"
                 style={{ borderColor: 'var(--sr-border)' }}>
                <IconSubRadar />
                <div>
                    <div className="text-sm font-semibold leading-tight"
                         style={{ color: 'var(--sr-text-primary)' }}>
                        SubRadar
                    </div>
                    <div className="text-xs"
                         style={{ color: 'var(--sr-text-tertiary)' }}>
                        Admin Panel
                    </div>
                </div>
            </div>

            {/* Навигация */}
            <nav className="flex flex-col gap-1 px-3 py-4 flex-1">
                <p className="px-3 mb-2 text-xs font-semibold uppercase tracking-widest"
                   style={{ color: 'var(--sr-text-tertiary)', letterSpacing: '0.08em' }}>
                    Управление
                </p>
                <NavItem to="/dashboard"  icon={<IconDashboard />}   label="Дашборд" />
                <NavItem to="/users"      icon={<IconUsers />}        label="Пользователи" />
                <NavItem to="/categories" icon={<IconCategories />}   label="Категории" />
            </nav>

            {/* Профиль + выход */}
            <div className="px-3 py-4 border-t"
                 style={{ borderColor: 'var(--sr-border)' }}>
                {/* Текущий пользователь */}
                <div className="flex items-center gap-2.5 px-3 py-2 mb-1 rounded-xl"
                     style={{ backgroundColor: 'var(--sr-surface2)' }}>
                    <UserAvatar user={user} />
                    <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium truncate"
                           style={{ color: 'var(--sr-text-primary)' }}>
                            {user?.display_name || user?.email}
                        </p>
                        <p className="text-xs truncate"
                           style={{ color: 'var(--sr-text-tertiary)' }}>
                            {user?.role}
                        </p>
                    </div>
                </div>

                {/* Кнопка выхода */}
                <button
                    onClick={handleLogout}
                    className="flex items-center gap-2.5 w-full px-3 py-2 rounded-xl text-sm transition-all duration-150 hover:bg-surface2"
                    style={{ color: 'var(--sr-text-secondary)' }}
                >
                    <IconLogout />
                    Выйти
                </button>
            </div>
        </aside>
    )
}

// ── Основной лэйаут ────────────────────────────────────────────────────────────
export default function Layout() {
    return (
        <div className="flex" style={{ minHeight: '100vh', backgroundColor: 'var(--sr-background)' }}>
            <Sidebar />
            <main className="flex-1 overflow-auto">
                <Outlet />
            </main>
        </div>
    )
}