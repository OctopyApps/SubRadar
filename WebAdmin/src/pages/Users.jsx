import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { adminApi } from '@/api/admin'

const PAGE_SIZE = 20

// ── Утилиты ────────────────────────────────────────────────────────────────────
function formatDate(str) {
    if (!str) return '—'
    return new Date(str).toLocaleDateString('ru-RU', {
        day: 'numeric', month: 'short', year: 'numeric'
    })
}

function formatLastSeen(str) {
    if (!str) return 'никогда'
    const d    = new Date(str)
    const diff = Date.now() - d.getTime()
    const min  = Math.floor(diff / 60000)
    if (min < 1)   return 'только что'
    if (min < 60)  return `${min} мин назад`
    const hr = Math.floor(min / 60)
    if (hr  < 24)  return `${hr} ч назад`
    const day = Math.floor(hr / 24)
    if (day < 7)   return `${day} дн назад`
    return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })
}

// ── Скелетон ───────────────────────────────────────────────────────────────────
function Skeleton({ className }) {
    return <div className={`animate-pulse rounded-lg ${className}`}
                style={{ backgroundColor: 'var(--sr-surface2)' }} />
}

// ── Бейджи ─────────────────────────────────────────────────────────────────────
function RoleBadge({ role }) {
    return role === 'admin'
        ? <span className="badge badge-admin">admin</span>
        : <span className="badge badge-user">user</span>
}

function BlockedBadge() {
    return <span className="badge badge-blocked">заблокирован</span>
}

// ── Аватар ─────────────────────────────────────────────────────────────────────
function Avatar({ user }) {
    const initials = (user.display_name || user.email)
        .split(/[\s@]/).filter(Boolean).slice(0, 2)
        .map(s => s[0].toUpperCase()).join('')
    return (
        <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0 text-xs font-semibold text-white"
             style={{ background: user.is_blocked
                     ? 'var(--sr-text-tertiary)'
                     : 'linear-gradient(135deg, #7B5EA7, #9B7FD4)' }}>
            {initials}
        </div>
    )
}

// ── Поиск и фильтры ────────────────────────────────────────────────────────────
function Toolbar({ search, onSearch, role, onRole }) {
    return (
        <div className="flex items-center gap-3 mb-4">
            {/* Поиск */}
            <div className="relative flex-1 max-w-xs">
                <svg className="absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
                     width="14" height="14" viewBox="0 0 14 14" fill="none"
                     stroke="var(--sr-text-tertiary)" strokeWidth="1.75" strokeLinecap="round">
                    <circle cx="6" cy="6" r="4"/><path d="M10 10l2.5 2.5"/>
                </svg>
                <input
                    type="text"
                    value={search}
                    onChange={e => onSearch(e.target.value)}
                    placeholder="Поиск по email или имени…"
                    className="input pl-8"
                />
            </div>

            {/* Фильтр по роли */}
            <select
                value={role}
                onChange={e => onRole(e.target.value)}
                className="input w-auto pr-8 cursor-pointer"
                style={{ backgroundImage: 'none' }}
            >
                <option value="">Все роли</option>
                <option value="admin">Администраторы</option>
                <option value="user">Пользователи</option>
            </select>
        </div>
    )
}

// ── Строка таблицы ─────────────────────────────────────────────────────────────
function UserRow({ user, onBlock, onUnblock, onMakeAdmin, isUpdating }) {
    const navigate = useNavigate()

    return (
        <tr
            className="transition-colors duration-100 cursor-pointer"
            style={{ borderBottom: '1px solid var(--sr-border)' }}
            onClick={() => navigate(`/users/${user.id}`)}
            onMouseEnter={e => e.currentTarget.style.backgroundColor = 'var(--sr-surface2)'}
            onMouseLeave={e => e.currentTarget.style.backgroundColor = 'transparent'}
        >
            {/* Пользователь */}
            <td className="px-4 py-3">
                <div className="flex items-center gap-3">
                    <Avatar user={user} />
                    <div className="min-w-0">
                        <p className="text-sm font-medium truncate"
                           style={{ color: 'var(--sr-text-primary)' }}>
                            {user.display_name || '—'}
                        </p>
                        <p className="text-xs truncate"
                           style={{ color: 'var(--sr-text-secondary)' }}>
                            {user.email}
                        </p>
                    </div>
                </div>
            </td>

            {/* Роль + статус */}
            <td className="px-4 py-3">
                <div className="flex items-center gap-1.5 flex-wrap">
                    <RoleBadge role={user.role} />
                    {user.is_blocked && <BlockedBadge />}
                </div>
            </td>

            {/* Последняя активность */}
            <td className="px-4 py-3 text-xs" style={{ color: 'var(--sr-text-tertiary)' }}>
                {formatLastSeen(user.last_seen_at)}
            </td>

            {/* Дата регистрации */}
            <td className="px-4 py-3 text-xs" style={{ color: 'var(--sr-text-tertiary)' }}>
                {formatDate(user.created_at)}
            </td>

            {/* Действия */}
            <td className="px-4 py-3" onClick={e => e.stopPropagation()}>
                <div className="flex items-center gap-1 justify-end">
                    {user.role !== 'admin' && (
                        <ActionButton
                            label="→ admin"
                            color="var(--sr-accent)"
                            disabled={isUpdating}
                            onClick={() => onMakeAdmin(user.id)}
                        />
                    )}
                    {user.is_blocked ? (
                        <ActionButton
                            label="Разблокировать"
                            color="var(--sr-mode-local)"
                            disabled={isUpdating}
                            onClick={() => onUnblock(user.id)}
                        />
                    ) : (
                        <ActionButton
                            label="Заблокировать"
                            color="var(--sr-danger)"
                            disabled={isUpdating}
                            onClick={() => onBlock(user.id)}
                        />
                    )}
                </div>
            </td>
        </tr>
    )
}

function ActionButton({ label, color, onClick, disabled }) {
    return (
        <button
            onClick={onClick}
            disabled={disabled}
            className="px-2.5 py-1 rounded-lg text-xs font-medium transition-all duration-150 hover:opacity-80 active:scale-95 disabled:opacity-40"
            style={{ backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)`, color }}
        >
            {label}
        </button>
    )
}

// ── Пагинация ──────────────────────────────────────────────────────────────────
function Pagination({ total, offset, limit, onChange }) {
    const page      = Math.floor(offset / limit)
    const pageCount = Math.ceil(total / limit)
    if (pageCount <= 1) return null

    return (
        <div className="flex items-center justify-between px-4 py-3 border-t"
             style={{ borderColor: 'var(--sr-border)' }}>
            <p className="text-xs" style={{ color: 'var(--sr-text-tertiary)' }}>
                {offset + 1}–{Math.min(offset + limit, total)} из {total}
            </p>
            <div className="flex gap-1">
                <button
                    onClick={() => onChange(offset - limit)}
                    disabled={page === 0}
                    className="btn-secondary px-3 py-1.5 text-xs disabled:opacity-40"
                >
                    ←
                </button>
                <button
                    onClick={() => onChange(offset + limit)}
                    disabled={page >= pageCount - 1}
                    className="btn-secondary px-3 py-1.5 text-xs disabled:opacity-40"
                >
                    →
                </button>
            </div>
        </div>
    )
}

// ── Главный компонент ──────────────────────────────────────────────────────────
export default function Users() {
    const [search, setSearch] = useState('')
    const [role,   setRole]   = useState('')
    const [offset, setOffset] = useState(0)

    // Сбрасываем страницу при смене фильтров
    function handleSearch(v) { setSearch(v); setOffset(0) }
    function handleRole(v)   { setRole(v);   setOffset(0) }

    const queryClient = useQueryClient()

    const { data, isLoading } = useQuery({
        queryKey: ['admin-users', { search, role, offset }],
        queryFn:  () => adminApi.listUsers({ search, role, limit: PAGE_SIZE, offset }),
        placeholderData: prev => prev,
    })

    const { mutate: updateUser, isPending: isUpdating } = useMutation({
        mutationFn: ({ id, data }) => adminApi.updateUser(id, data),
        onSuccess:  () => queryClient.invalidateQueries({ queryKey: ['admin-users'] }),
    })

    const handleBlock     = id => updateUser({ id, data: { is_blocked: true,  blocked_reason: 'Заблокирован администратором' } })
    const handleUnblock   = id => updateUser({ id, data: { is_blocked: false } })
    const handleMakeAdmin = id => updateUser({ id, data: { role: 'admin' } })

    return (
        <div className="p-8 max-w-5xl">

            {/* Заголовок */}
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight"
                        style={{ color: 'var(--sr-text-primary)', letterSpacing: '-0.3px' }}>
                        Пользователи
                    </h1>
                    <p className="text-sm mt-1" style={{ color: 'var(--sr-text-secondary)' }}>
                        {data ? `${data.total} пользователей` : 'Загрузка…'}
                    </p>
                </div>
            </div>

            <Toolbar search={search} onSearch={handleSearch} role={role} onRole={handleRole} />

            {/* Таблица */}
            <div className="card overflow-hidden">
                <table className="w-full">
                    <thead>
                    <tr style={{ borderBottom: '1px solid var(--sr-border)' }}>
                        {['Пользователь', 'Роль', 'Последний вход', 'Зарегистрирован', ''].map(h => (
                            <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide"
                                style={{ color: 'var(--sr-text-tertiary)', letterSpacing: '0.06em' }}>
                                {h}
                            </th>
                        ))}
                    </tr>
                    </thead>
                    <tbody>
                    {isLoading
                        ? Array.from({ length: 5 }).map((_, i) => (
                            <tr key={i} style={{ borderBottom: '1px solid var(--sr-border)' }}>
                                {Array.from({ length: 5 }).map((_, j) => (
                                    <td key={j} className="px-4 py-3">
                                        <Skeleton className="h-4 w-full" />
                                    </td>
                                ))}
                            </tr>
                        ))
                        : data?.users.length === 0
                            ? (
                                <tr>
                                    <td colSpan={5} className="px-4 py-12 text-center text-sm"
                                        style={{ color: 'var(--sr-text-tertiary)' }}>
                                        Пользователи не найдены
                                    </td>
                                </tr>
                            )
                            : data?.users.map(user => (
                                <UserRow
                                    key={user.id}
                                    user={user}
                                    isUpdating={isUpdating}
                                    onBlock={handleBlock}
                                    onUnblock={handleUnblock}
                                    onMakeAdmin={handleMakeAdmin}
                                />
                            ))
                    }
                    </tbody>
                </table>

                {data && (
                    <Pagination
                        total={data.total}
                        offset={offset}
                        limit={PAGE_SIZE}
                        onChange={setOffset}
                    />
                )}
            </div>
        </div>
    )
}