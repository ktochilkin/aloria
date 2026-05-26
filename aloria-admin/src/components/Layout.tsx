import { NavLink, Outlet } from 'react-router';
import { BookOpen, Layers, ListChecks, Trophy, Users, Activity, Send } from 'lucide-react';
import { clsx } from 'clsx';

const navItems = [
  { to: '/sections', icon: Layers, label: 'Разделы' },
  { to: '/lessons', icon: BookOpen, label: 'Уроки' },
  { to: '/quizzes', icon: ListChecks, label: 'Тесты' },
  { to: '/achievements', icon: Trophy, label: 'Ачивки' },
  { to: '/users', icon: Users, label: 'Пользователи' },
  { to: '/broadcast', icon: Send, label: 'Рассылка' },
  { to: '/audit', icon: Activity, label: 'Аудит' },
];

export function Layout() {
  return (
    <div className="flex min-h-screen">
      <aside className="w-64 shrink-0 border-r border-(--color-border) bg-(--color-surface) flex flex-col">
        <div className="px-5 py-5 border-b border-(--color-border)">
          <div className="text-lg font-bold text-(--color-fg)">Aloria · Admin</div>
          <div className="text-xs text-(--color-fg-muted) mt-0.5">Учебный контент и геймификация</div>
        </div>
        <nav className="flex flex-col gap-0.5 p-3 flex-1">
          {navItems.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                clsx(
                  'flex items-center gap-2.5 px-3 h-10 rounded-lg text-sm font-semibold',
                  isActive
                    ? 'bg-(--color-primary-50) text-(--color-primary)'
                    : 'text-(--color-fg-muted) hover:bg-(--color-bg) hover:text-(--color-fg)'
                )
              }
            >
              <Icon className="size-4" />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="px-5 py-3 text-[11px] text-(--color-fg-muted) border-t border-(--color-border)">
          Закрытый контур · без auth
        </div>
      </aside>
      <main className="flex-1 min-w-0 overflow-x-auto">
        <div className="max-w-6xl mx-auto p-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
