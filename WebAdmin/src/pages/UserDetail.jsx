import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '@/api/admin'

// ── Утилиты ────────────────────────────────────────────────────────────────────
function formatDate(str) {
    if (!str) return '—'
    return new Date(str).toLocaleDateString('ru-RU', {
        day: 'numeric', month: 'long', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    })
}

function formatLastSeen(str) {
    if (!str) return 'никогда'
    const diff = Date.now() - new Date(str).getTime()
    const min  = Math.floor(diff / 60000)
    if (min < 1)  return 'только что'
    if (min < 60) return `${min} мин назад`
    const hr = Math.floor(min / 60)
    if (hr < 24)  return `${hr} ч назад`
    return `${Math.floor(hr / 24)} дн назад`
}

// ── Скелетон ───────────────────────────────────────────────────────────────────
function Skeleton({ className }) {
    return <div className={`animate-pulse rounded-xl ${className}`}
                style={{ backgroundColor: 'var(--sr-surface2)' }} />
}

function PageSkeleton() {
    return (
        <div className="p-8 max-w-2xl flex flex-col gap-4">
            <Skeleton className="h-6 w-32" />
            <div className="card p-6 flex flex-col gap-4">
                <div className="flex items-center gap-4">
                    <Skeleton className="w-16 h-16 rounded-full" />
                    <div className="flex flex-col gap-2 flex-1">
                        <Skeleton className="h-5 w-48" />
                        <Skeleton className="h-4 w-64" />
                    </div>
                </div>
                <Skeleton className="h-px w-full" />
                {Array.from({ length: 4 }).map((_, i) => (
                    <div key={i} className="flex justify-between">
                        <Skeleton className="h-4 w-28" />
                        <Skeleton className="h-4 w-36" />
                    </div>
                ))}
            </div>
        </div>
    )
}

// ── Аватар ─────────────────────────────────────────────────────────────────────
function Avatar({ user }) {
    const initials = (user.display_name || user.email)
        .split(/[\s@]/).filter(Boolean).slice(0, 2)
        .map(s => s[0].toUpperCase()).join('')
    return (
        <div className="w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold text-white shrink-0"
             style={{ background: user.is_blocked
                     ? 'var(--sr-text-tertiary)'
                     : 'linear-gradient(135deg, #7B5EA7, #9B7FD4)' }}>
            {initials}
        </div>
    )
}

// ── Строка детали ──────────────────────────────────────────────────────────────
function DetailRow({ label, children }) {
    return (
        <div className="flex items-center justify-between py-3 border-b last:border-0"
             style={{ borderColor: 'var(--sr-border)' }}>
            <span className="text-sm" style={{ color: 'var(--sr-text-secondary)' }}>{label}</span>
            <span className="text-sm font-medium" style={{ color: 'var(--sr-text-primary)' }}>
        {children}
      </span>
        </div>
    )
}

// ── Бейджи ─────────────────────────────────────────────────────────────────────
function RoleBadge({ role }) {
    return role === 'admin'
        ? <span className="badge badge-admin">admin</span>
        : <span className="badge badge-user">user</span>
}

// ── Модалка подтверждения удаления ────────────────────────────────────────────
function DeleteModal({ user, onConfirm, onCancel, isLoading }) {
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fade-in"
             style={{ backgroundColor: 'rgba(0,0,0,0.4)' }}
             onClick={onCancel}>
            <div className="card p-6 max-w-sm w-full shadow-modal animate-slide-up"
                 onClick={e => e.stopPropagation()}>
                <h3 className="text-base font-semibold mb-2"
                    style={{ color: 'var(--sr-text-primary)' }}>
                    Удалить пользователя?
                </h3>
                <p className="text-sm mb-6" style={{ color: 'var(--sr-text-secondary)' }}>
                    Аккаунт <strong>{user.email}</strong> и все его данные (подписки, теги, категории)
                    будут удалены безвозвратно.
                </p>
                <div className="flex gap-3">
                    <button onClick={onCancel} className="btn-secondary flex-1">
                        Отмена
                    </button>
                    <button onClick={onConfirm} disabled={isLoading} className="btn-danger flex-1">
                        {isLoading ? 'Удаление…' : 'Удалить'}
                    </button>
                </div>
            </div>
        </div>
    )
}

// ── Секция действий ────────────────────────────────────────────────────────────
function ActionsCard({ user, onBlock, onUnblock, onMakeAdmin, onMakeUser, onDelete,
                         isUpdating, isDeleting }) {
    return (
        <div className="card p-5">
            <p className="text-xs font-semibold uppercase tracking-widest mb-4"
               style={{ color: 'var(--sr-text-tertiary)', letterSpacing: '0.08em' }}>
                Действия
            </p>

            <div className="flex flex-col gap-2">
                {/* Блокировка */}
                {user.is_blocked ? (
                    <button onClick={onUnblock} disabled={isUpdating} className="btn-secondary text-sm"
                            style={{ color: 'var(--sr-mode-local)' }}>
                        ✓ Разблокировать
                    </button>
                ) : (
                    <button onClick={onBlock} disabled={isUpdating} className="btn-secondary text-sm"
                            style={{ color: 'var(--sr-danger)' }}>
                        Заблокировать
                    </button>
                )}

                {/* Роль */}
                {user.role !== 'admin' ? (
                    <button onClick={onMakeAdmin} disabled={isUpdating} className="btn-secondary text-sm">
                        Сделать администратором
                    </button>
                ) : (
                    <button onClick={onMakeUser} disabled={isUpdating} className="btn-secondary text-sm">
                        Снять права администратора
                    </button>
                )}

                {/* Разделитель */}
                <div className="border-t my-1" style={{ borderColor: 'var(--sr-border)' }} />

                {/* Удаление */}
                <button onClick={onDelete} disabled={isDeleting} className="btn-danger text-sm">
                    Удалить пользователя
                </button>
            </div>
        </div>
    )
}

// ── Главный компонент ──────────────────────────────────────────────────────────
export default function UserDetail() {
    const { id }        = useParams()
    const navigate      = useNavigate()
    const queryClient   = useQueryClient()
    const [showDelete, setShowDelete] = useState(false)

    const { data: user, isLoading, isError } = useQuery({
        queryKey: ['admin-user', id],
        queryFn:  () => adminApi.getUser(id),
    })

    const { mutate: updateUser, isPending: isUpdating } = useMutation({
        mutationFn: (data) => adminApi.updateUser(id, data),
        onSuccess: (updated) => {
            queryClient.setQueryData(['admin-user', id], updated)
            queryClient.invalidateQueries({ queryKey: ['admin-users'] })
        },
    })

    const { mutate: deleteUser, isPending: isDeleting } = useMutation({
        mutationFn: () => adminApi.deleteUser(id),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['admin-users'] })
            navigate('/users', { replace: true })
        },
    })

    if (isLoading) return <PageSkeleton />

    if (isError) return (
        <div className="p-8">
            <div className="card p-6 text-center">
                <p className="text-sm" style={{ color: 'var(--sr-danger)' }}>
                    Пользователь не найден
                </p>
                <button onClick={() => navigate('/users')} className="btn-secondary mt-4 text-sm">
                    ← Назад к списку
                </button>
            </div>
        </div>
    )

    return (
        <div className="p-8 max-w-2xl">

            {/* Назад */}
            <button
                onClick={() => navigate('/users')}
                className="flex items-center gap-1.5 text-sm mb-6 transition-opacity hover:opacity-70"
                style={{ color: 'var(--sr-text-secondary)' }}
            >
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none"
                     stroke="currentColor" strokeWidth="1.75" strokeLinecap="round">
                    <path d="M10 12L6 8l4-4"/>
                </svg>
                Пользователи
            </button>

            <div className="flex flex-col gap-4 animate-slide-up">

                {/* Карточка профиля */}
                <div className="card p-6">
                    {/* Шапка */}
                    <div className="flex items-center gap-4 mb-5">
                        <Avatar user={user} />
                        <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                                <h1 className="text-xl font-bold tracking-tight"
                                    style={{ color: 'var(--sr-text-primary)', letterSpacing: '-0.3px' }}>
                                    {user.display_name || 'Без имени'}
                                </h1>
                                <RoleBadge role={user.role} />
                                {user.is_blocked && (
                                    <span className="badge badge-blocked">заблокирован</span>
                                )}
                            </div>
                            <p className="text-sm mt-0.5 truncate"
                               style={{ color: 'var(--sr-text-secondary)' }}>
                                {user.email}
                            </p>
                        </div>
                    </div>

                    <div className="border-t" style={{ borderColor: 'var(--sr-border)' }} />

                    {/* Детали */}
                    <div className="mt-1">
                        <DetailRow label="ID">{user.id}</DetailRow>
                        <DetailRow label="Провайдер">{user.provider}</DetailRow>
                        <DetailRow label="Последний вход">{formatLastSeen(user.last_seen_at)}</DetailRow>
                        <DetailRow label="Зарегистрирован">{formatDate(user.created_at)}</DetailRow>

                        {user.is_blocked && (
                            <>
                                <DetailRow label="Заблокирован">
                                    {formatDate(user.blocked_at)}
                                </DetailRow>
                                {user.blocked_reason && (
                                    <DetailRow label="Причина">
                                        <span style={{ color: 'var(--sr-danger)' }}>{user.blocked_reason}</span>
                                    </DetailRow>
                                )}
                            </>
                        )}
                    </div>
                </div>

                {/* Карточка действий */}
                <ActionsCard
                    user={user}
                    isUpdating={isUpdating}
                    isDeleting={isDeleting}
                    onBlock={()      => updateUser({ is_blocked: true,  blocked_reason: 'Заблокирован администратором' })}
                    onUnblock={()    => updateUser({ is_blocked: false })}
                    onMakeAdmin={()  => updateUser({ role: 'admin' })}
                    onMakeUser={()   => updateUser({ role: 'user'  })}
                    onDelete={()     => setShowDelete(true)}
                />
            </div>

            {/* Модалка удаления */}
            {showDelete && (
                <DeleteModal
                    user={user}
                    isLoading={isDeleting}
                    onCancel={() => setShowDelete(false)}
                    onConfirm={() => deleteUser()}
                />
            )}
        </div>
    )
}