import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminApi } from '@/api/admin'

// ── Скелетон ───────────────────────────────────────────────────────────────────
function Skeleton({ className }) {
    return <div className={`animate-pulse rounded-xl ${className}`}
                style={{ backgroundColor: 'var(--sr-surface2)' }} />
}

// ── Иконка SF Symbol → эмодзи-заглушка ────────────────────────────────────────
// SF Symbol недоступны в вебе — показываем нейтральную иконку
function CategoryIcon({ icon }) {
    // Маппинг популярных SF Symbol → эмодзи
    const map = {
        'play.circle':            '▶️',
        'music.note':             '🎵',
        'gamecontroller':         '🎮',
        'cart':                   '🛒',
        'book':                   '📚',
        'cloud':                  '☁️',
        'tv':                     '📺',
        'mic':                    '🎤',
        'photo':                  '📷',
        'envelope':               '✉️',
        'globe':                  '🌐',
        'lock':                   '🔒',
        'person.2':               '👥',
        'briefcase':              '💼',
        'heart':                  '❤️',
        'star':                   '⭐',
        'bolt':                   '⚡',
        'flame':                  '🔥',
        'ellipsis.circle':        '•••',
    }
    const emoji = map[icon] ?? '📦'
    return (
        <div className="w-9 h-9 rounded-xl flex items-center justify-center text-lg shrink-0"
             style={{ backgroundColor: 'var(--sr-accent-light)' }}>
            {emoji}
        </div>
    )
}

// ── Карточка категории ─────────────────────────────────────────────────────────
function CategoryCard({ cat, onDelete, isDeleting }) {
    const [confirm, setConfirm] = useState(false)

    return (
        <div className="flex items-center gap-3 px-4 py-3 border-b last:border-0 group transition-colors"
             style={{ borderColor: 'var(--sr-border)' }}>
            <CategoryIcon icon={cat.icon} />

            <div className="flex-1 min-w-0">
                <p className="text-sm font-medium" style={{ color: 'var(--sr-text-primary)' }}>
                    {cat.name}
                </p>
                <p className="text-xs mt-0.5 font-mono" style={{ color: 'var(--sr-text-tertiary)' }}>
                    {cat.icon}
                </p>
            </div>

            <span className="badge badge-admin text-xs mr-2">системная</span>

            {/* Подтверждение удаления инлайн */}
            {confirm ? (
                <div className="flex items-center gap-2 animate-fade-in">
          <span className="text-xs" style={{ color: 'var(--sr-text-secondary)' }}>
            Удалить?
          </span>
                    <button
                        onClick={() => { onDelete(cat.id); setConfirm(false) }}
                        disabled={isDeleting}
                        className="px-2.5 py-1 rounded-lg text-xs font-medium transition-all hover:opacity-80"
                        style={{ backgroundColor: 'rgba(255,59,48,0.1)', color: 'var(--sr-danger)' }}
                    >
                        Да
                    </button>
                    <button
                        onClick={() => setConfirm(false)}
                        className="px-2.5 py-1 rounded-lg text-xs font-medium transition-all hover:opacity-80"
                        style={{ backgroundColor: 'var(--sr-surface2)', color: 'var(--sr-text-secondary)' }}
                    >
                        Нет
                    </button>
                </div>
            ) : (
                <button
                    onClick={() => setConfirm(true)}
                    className="opacity-0 group-hover:opacity-100 transition-opacity px-2.5 py-1 rounded-lg text-xs font-medium"
                    style={{ backgroundColor: 'rgba(255,59,48,0.1)', color: 'var(--sr-danger)' }}
                >
                    Удалить
                </button>
            )}
        </div>
    )
}

// ── Форма добавления ───────────────────────────────────────────────────────────
// Список SF Symbol для выбора иконки
const ICON_OPTIONS = [
    { value: 'play.circle',     label: '▶️  Стриминг'     },
    { value: 'music.note',      label: '🎵  Музыка'        },
    { value: 'gamecontroller',  label: '🎮  Игры'          },
    { value: 'cart',            label: '🛒  Покупки'       },
    { value: 'book',            label: '📚  Образование'   },
    { value: 'cloud',           label: '☁️  Облако'        },
    { value: 'tv',              label: '📺  ТВ'            },
    { value: 'mic',             label: '🎤  Подкасты'      },
    { value: 'photo',           label: '📷  Фото'          },
    { value: 'globe',           label: '🌐  Новости'       },
    { value: 'briefcase',       label: '💼  Бизнес'        },
    { value: 'heart',           label: '❤️  Здоровье'      },
    { value: 'bolt',            label: '⚡  Утилиты'       },
    { value: 'flame',           label: '🔥  Популярное'    },
    { value: 'ellipsis.circle', label: '•••  Другое'       },
]

function AddCategoryForm({ onAdd, isLoading }) {
    const [name, setName] = useState('')
    const [icon, setIcon] = useState('ellipsis.circle')
    const [error, setError] = useState('')

    async function handleSubmit(e) {
        e.preventDefault()
        setError('')
        const trimmed = name.trim()
        if (!trimmed) { setError('Введите название'); return }
        try {
            await onAdd(trimmed, icon)
            setName('')
            setIcon('ellipsis.circle')
        } catch (err) {
            setError(err.message ?? 'Ошибка создания')
        }
    }

    return (
        <form onSubmit={handleSubmit} className="card p-5 mb-4 animate-fade-in">
            <p className="text-xs font-semibold uppercase tracking-widest mb-4"
               style={{ color: 'var(--sr-text-tertiary)', letterSpacing: '0.08em' }}>
                Новая системная категория
            </p>

            <div className="flex gap-3">
                {/* Иконка */}
                <div className="flex flex-col gap-1.5 w-44 shrink-0">
                    <label className="text-xs font-semibold uppercase tracking-wide"
                           style={{ color: 'var(--sr-text-secondary)', letterSpacing: '0.05em' }}>
                        Иконка
                    </label>
                    <select
                        value={icon}
                        onChange={e => setIcon(e.target.value)}
                        className="input text-sm"
                    >
                        {ICON_OPTIONS.map(o => (
                            <option key={o.value} value={o.value}>{o.label}</option>
                        ))}
                    </select>
                </div>

                {/* Название */}
                <div className="flex flex-col gap-1.5 flex-1">
                    <label className="text-xs font-semibold uppercase tracking-wide"
                           style={{ color: 'var(--sr-text-secondary)', letterSpacing: '0.05em' }}>
                        Название
                    </label>
                    <input
                        type="text"
                        value={name}
                        onChange={e => setName(e.target.value)}
                        placeholder="Например: Стриминг"
                        className="input"
                        maxLength={64}
                    />
                </div>

                {/* Кнопка */}
                <div className="flex flex-col justify-end">
                    <button type="submit" className="btn-primary whitespace-nowrap" disabled={isLoading}>
                        {isLoading ? 'Создание…' : '+ Добавить'}
                    </button>
                </div>
            </div>

            {error && (
                <p className="text-xs mt-2 animate-fade-in" style={{ color: 'var(--sr-danger)' }}>
                    {error}
                </p>
            )}

            <p className="text-xs mt-3" style={{ color: 'var(--sr-text-tertiary)' }}>
                Системные категории видны всем пользователям во всех режимах хранения.
            </p>
        </form>
    )
}

// ── Пустое состояние ───────────────────────────────────────────────────────────
function EmptyState() {
    return (
        <div className="py-16 flex flex-col items-center gap-3">
            <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl"
                 style={{ backgroundColor: 'var(--sr-surface2)' }}>
                📦
            </div>
            <p className="text-sm font-medium" style={{ color: 'var(--sr-text-secondary)' }}>
                Системных категорий пока нет
            </p>
            <p className="text-xs text-center max-w-xs" style={{ color: 'var(--sr-text-tertiary)' }}>
                Добавьте категорию выше — она сразу станет доступна всем пользователям
            </p>
        </div>
    )
}

// ── Главный компонент ──────────────────────────────────────────────────────────
export default function Categories() {
    const queryClient = useQueryClient()

    const { data: cats, isLoading } = useQuery({
        queryKey: ['admin-categories'],
        queryFn:  adminApi.listCategories,
    })

    const { mutate: createCat, isPending: isCreating } = useMutation({
        mutationFn: ({ name, icon }) => adminApi.createCategory(name, icon),
        onSuccess:  () => queryClient.invalidateQueries({ queryKey: ['admin-categories'] }),
    })

    const { mutate: deleteCat, isPending: isDeleting } = useMutation({
        mutationFn: (id) => adminApi.deleteCategory(id),
        onSuccess:  () => queryClient.invalidateQueries({ queryKey: ['admin-categories'] }),
    })

    return (
        <div className="p-8 max-w-2xl">

            {/* Заголовок */}
            <div className="mb-6">
                <h1 className="text-2xl font-bold tracking-tight"
                    style={{ color: 'var(--sr-text-primary)', letterSpacing: '-0.3px' }}>
                    Системные категории
                </h1>
                <p className="text-sm mt-1" style={{ color: 'var(--sr-text-secondary)' }}>
                    Категории доступные всем пользователям по умолчанию
                </p>
            </div>

            {/* Форма */}
            <AddCategoryForm
                isLoading={isCreating}
                onAdd={(name, icon) => new Promise((resolve, reject) =>
                    createCat({ name, icon }, { onSuccess: resolve, onError: reject })
                )}
            />

            {/* Список */}
            <div className="card overflow-hidden">
                {isLoading ? (
                    <div className="flex flex-col gap-0">
                        {Array.from({ length: 4 }).map((_, i) => (
                            <div key={i} className="flex items-center gap-3 px-4 py-3 border-b"
                                 style={{ borderColor: 'var(--sr-border)' }}>
                                <Skeleton className="w-9 h-9 rounded-xl" />
                                <div className="flex flex-col gap-1.5 flex-1">
                                    <Skeleton className="h-4 w-32" />
                                    <Skeleton className="h-3 w-24" />
                                </div>
                            </div>
                        ))}
                    </div>
                ) : cats?.length === 0 ? (
                    <EmptyState />
                ) : (
                    cats?.map(cat => (
                        <CategoryCard
                            key={cat.id}
                            cat={cat}
                            isDeleting={isDeleting}
                            onDelete={(id) => deleteCat(id)}
                        />
                    ))
                )}
            </div>

            {/* Подсказка */}
            {cats?.length > 0 && (
                <p className="text-xs mt-3" style={{ color: 'var(--sr-text-tertiary)' }}>
                    {cats.length} {cats.length === 1 ? 'категория' : cats.length < 5 ? 'категории' : 'категорий'}
                    {' '}· наведи на категорию чтобы удалить
                </p>
            )}
        </div>
    )
}