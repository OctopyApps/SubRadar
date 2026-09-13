/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Семантические токены из iOS — ios-guidelines.md
        sr: {
          background:    'var(--sr-background)',
          surface:       'var(--sr-surface)',
          surface2:      'var(--sr-surface2)',
          border:        'var(--sr-border)',
          accent:        'var(--sr-accent)',
          'accent-light':'var(--sr-accent-light)',
          text:          'var(--sr-text-primary)',
          'text-2':      'var(--sr-text-secondary)',
          'text-3':      'var(--sr-text-tertiary)',
          danger:        'var(--sr-danger)',
          warning:       'var(--sr-warning)',
          teal:          'var(--sr-teal)',
          'mode-local':  'var(--sr-mode-local)',
          'mode-shared': 'var(--sr-mode-shared)',
        },
      },
      fontFamily: {
        sans: ['"SF Pro Display"', '"SF Pro Text"', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
        mono: ['"SF Mono"', 'monospace'],
      },
      borderRadius: {
        'xl':  '12px',
        '2xl': '16px',
        '3xl': '24px',
      },
      boxShadow: {
        'card': '0 1px 3px 0 rgba(0,0,0,0.08), 0 1px 2px -1px rgba(0,0,0,0.04)',
        'card-hover': '0 4px 12px 0 rgba(0,0,0,0.10), 0 2px 4px -1px rgba(0,0,0,0.06)',
        'modal': '0 20px 60px -12px rgba(0,0,0,0.25)',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%':   { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%':   { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
}
