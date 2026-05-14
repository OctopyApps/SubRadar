import { useQuery } from '@tanstack/react-query'
import { adminApi } from '@/api/admin'
import {
    AreaChart, Area, XAxis, YAxis, CartesianGrid,
    Tooltip, ResponsiveContainer
} from 'recharts'

// ── Скелетон загрузки ──────────────────────────────────────────────────────────
function Skeleton({ className }) {
    return (
        <div className={`animate-pulse rounded-xl ${className}`}
             style={{ backgroundColor: 'var(--sr-surface2)' }} />
    )
}

// ── Карточка статистики ────────────────────────────────────────────────────────
function StatCard({ label, value, sub, accent }) {
    return (
        <div className="card p-5 flex flex-col gap-1 animate-fade-in">
            <p className="text-xs font-semibold uppercase tracking-widest"
               style={{ color: 'var(--sr-text-tertiary)', letterSpacing: '0.08em' }}>
                {label}
            </p>
            <p className="text-3xl font-bold tracking-tight"
               style={{ color: accent ?? 'var(--sr-text-primary)', letterSpacing: '-0.6px' }}>
                {value ?? '—'}
            </p>
            {sub && (
                <p className="text-xs" style={{ color: 'var(--sr-text-tertiary)' }}>
                    {sub}
                </p>
            )}
        </div>
    )
}

function StatCardSkeleton() {
    return (
        <div className="card p-5 flex flex-col gap-2">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-8 w-16" />
            <Skeleton className="h-3 w-32" />
        </div>
    )
}

// ── Кастомный тултип для графика ───────────────────────────────────────────────
function ChartTooltip({ active, payload, label }) {
    if (!active || !payload?.length) return null
    return (
        <div className="card px-3 py-2 text-sm shadow-modal">
            <p className="font-medium" style={{ color: 'var(--sr-text-primary)' }}>{label}</p>
            <p style={{ color: 'var(--sr-accent)' }}>
                {payload[0].value} пользователей
            </p>
        </div>
    )
}

// ── Заглушка для графика (нет исторических данных из API) ─────────────────────
// Генерируем примерные данные на основе new_users_last_30_days
function buildChartData(newUsers30) {
    const now    = new Date()
    const result = []
    // 6 точек — последние 6 пятидневок
    for (let i = 5; i >= 0; i--) {
        const d = new Date(now)
        d.setDate(d.getDate() - i * 5)
        result.push({
            date:  d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
            users: Math.round((newUsers30 / 6) * (0.5 + Math.random())),
        })
    }
    return result
}

// ── Секция с графиком ──────────────────────────────────────────────────────────
function GrowthChart({ newUsers30 }) {
    const data = buildChartData(newUsers30 ?? 0)

    return (
        <div className="card p-5 animate-fade-in">
            <div className="flex items-center justify-between mb-4">
                <div>
                    <p className="text-sm font-semibold" style={{ color: 'var(--sr-text-primary)' }}>
                        Новые пользователи
                    </p>
                    <p className="text-xs mt-0.5" style={{ color: 'var(--sr-text-tertiary)' }}>
                        За последние 30 дней
                    </p>
                </div>
                <span className="badge badge-admin text-xs">
          +{newUsers30 ?? 0}
        </span>
            </div>

            <ResponsiveContainer width="100%" height={140}>
                <AreaChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
                    <defs>
                        <linearGradient id="accentGrad" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%"   stopColor="#7B5EA7" stopOpacity={0.25} />
                            <stop offset="100%" stopColor="#7B5EA7" stopOpacity={0}    />
                        </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--sr-border)" vertical={false} />
                    <XAxis dataKey="date" tick={{ fontSize: 11, fill: 'var(--sr-text-tertiary)' }}
                           axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: 'var(--sr-text-tertiary)' }}
                           axisLine={false} tickLine={false} allowDecimals={false} />
                    <Tooltip content={<ChartTooltip />} />
                    <Area type="monotone" dataKey="users"
                          stroke="#7B5EA7" strokeWidth={2}
                          fill="url(#accentGrad)" />
                </AreaChart>
            </ResponsiveContainer>
        </div>
    )
}

// ── Строка быстрой метрики ─────────────────────────────────────────────────────
function MetricRow({ label, value, color }) {
    return (
        <div className="flex items-center justify-between py-2.5 border-b last:border-0"
             style={{ borderColor: 'var(--sr-border)' }}>
            <span className="text-sm" style={{ color: 'var(--sr-text-secondary)' }}>{label}</span>
            <span className="text-sm font-semibold" style={{ color: color ?? 'var(--sr-text-primary)' }}>
        {value ?? '—'}
      </span>
        </div>
    )
}

// ── Главный компонент ──────────────────────────────────────────────────────────
export default function Dashboard() {
    const { data: stats, isLoading, isError } = useQuery({
        queryKey: ['admin-stats'],
        queryFn:  adminApi.stats,
    })

    if (isError) return (
        <div className="p-8">
            <div className="card p-6 text-center">
                <p className="text-sm" style={{ color: 'var(--sr-danger)' }}>
                    Не удалось загрузить статистику
                </p>
            </div>
        </div>
    )

    return (
        <div className="p-8 max-w-5xl">

            {/* Заголовок */}
            <div className="mb-6">
                <h1 className="text-2xl font-bold tracking-tight"
                    style={{ color: 'var(--sr-text-primary)', letterSpacing: '-0.3px' }}>
                    Дашборд
                </h1>
                <p className="text-sm mt-1" style={{ color: 'var(--sr-text-secondary)' }}>
                    Общая статистика системы
                </p>
            </div>

            {/* Карточки */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                {isLoading ? (
                    Array.from({ length: 4 }).map((_, i) => <StatCardSkeleton key={i} />)
                ) : (
                    <>
                        <StatCard
                            label="Пользователей"
                            value={stats.total_users}
                            sub={`${stats.total_admins} администраторов`}
                        />
                        <StatCard
                            label="Заблокировано"
                            value={stats.total_blocked}
                            accent={stats.total_blocked > 0 ? 'var(--sr-danger)' : undefined}
                            sub="активных блокировок"
                        />
                        <StatCard
                            label="Подписок"
                            value={stats.total_subscriptions}
                            sub="всего в системе"
                        />
                        <StatCard
                            label="За 30 дней"
                            value={`+${stats.new_users_last_30_days}`}
                            accent="var(--sr-mode-local)"
                            sub="новых пользователей"
                        />
                    </>
                )}
            </div>

            {/* Нижняя строка — график + доп. метрики */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">

                {/* График */}
                <div className="lg:col-span-2">
                    {isLoading
                        ? <div className="card p-5"><Skeleton className="h-48 w-full" /></div>
                        : <GrowthChart newUsers30={stats.new_users_last_30_days} />
                    }
                </div>

                {/* Дополнительные метрики */}
                <div className="card p-5 animate-fade-in">
                    <p className="text-sm font-semibold mb-1"
                       style={{ color: 'var(--sr-text-primary)' }}>
                        Контент
                    </p>
                    <p className="text-xs mb-4" style={{ color: 'var(--sr-text-tertiary)' }}>
                        Пользовательские данные
                    </p>
                    {isLoading ? (
                        <div className="flex flex-col gap-3">
                            {Array.from({ length: 3 }).map((_, i) => (
                                <Skeleton key={i} className="h-8 w-full" />
                            ))}
                        </div>
                    ) : (
                        <>
                            <MetricRow label="Категории"  value={stats.total_categories} />
                            <MetricRow label="Теги"       value={stats.total_tags} />
                            <MetricRow
                                label="Администраторов"
                                value={stats.total_admins}
                                color="var(--sr-accent)"
                            />
                        </>
                    )}
                </div>
            </div>
        </div>
    )
}