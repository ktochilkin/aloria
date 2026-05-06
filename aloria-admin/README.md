# aloria-admin

Vite + React + TypeScript + Tailwind v4. Админка контента и геймификации Aloria.

## Запуск

```bash
npm install
npm run dev
```

Открыть http://localhost:5173. API проксируется через Vite на `http://127.0.0.1:5050` (см. `vite.config.ts`). Должен быть запущен `aloria-api` рядом.

## Сборка

```bash
npm run build
# результат в dist/
```

## Маршруты

- `/sections` — разделы обучения
- `/lessons` — уроки (группировка по разделам)
- `/lessons/:id` — редактор урока (markdown + frontmatter + загрузка картинок)
- `/quizzes` — список тестов и редактор вопросов
- `/achievements` — карточки ачивок с конструктором условий
- `/users` — список пользователей и детальная карточка с историей
- `/audit` — лог действий в админке

## Auth

Нет. Админка предполагается в закрытом контуре. Перед публикацией наружу — добавить либо basic auth на nginx-уровне, либо OAuth flow.
