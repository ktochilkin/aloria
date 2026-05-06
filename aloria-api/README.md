# aloria-api

ASP.NET Core 10 backend для учебного контента, тестов, прогресса и ачивок.

## Стек

- .NET 10 (минимальные API)
- EF Core + SQLite (на старте), переключаемо на Postgres через `Db:Provider`
- Идентификаторы — `Guid`, время — UTC
- Auth: нет (закрытый контур)

## Запуск

```bash
cd src/Aloria.Api
dotnet run
```

API слушает `http://0.0.0.0:5050`. Swagger — `http://localhost:5050/swagger`.

При первом запуске:
- Создаётся `aloria.db` (SQLite, рядом с проектом).
- Импортируются markdown-уроки из `../../assets/lessons/` Flutter-приложения.
- Создаётся 9 дефолтных ачивок.

## Доступ с iPhone в той же Wi-Fi

API слушает `0.0.0.0:5050`, поэтому достижим по LAN-IP машины. Узнать его на macOS:

```bash
ipconfig getifaddr en0    # обычно 192.168.x.x
```

Затем во Flutter-проекте добавить `--dart-define=ALORIA_API_URL=http://192.168.x.x:5050`. На iOS App Transport Security блокирует HTTP — добавить exception в Info.plist для домена/IP.

## Переход на Postgres

1. `dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL`
2. В `Program.cs` раскомментировать ветку с `UseNpgsql`.
3. В `appsettings.json` поставить `Db:Provider = postgres` и заполнить `ConnectionStrings:Postgres`.
4. Удалить миграции SQLite, сгенерировать новые: `dotnet ef migrations add Initial`, `dotnet ef database update`.

## Структура

```
src/Aloria.Api/
├── Domain/          сущности EF Core
├── Data/            DbContext, конфигурация моделей
├── Dtos/            публичные и админские DTO
├── Endpoints/       минимальные API-эндпоинты
├── Services/        UserService, QuizService, GrantService, etc.
└── Program.cs       композиция: DI, миграции, сид, маршруты
```

## Эндпоинты

**Публичные** (`/api/v1/*`) — для мобильного приложения:
- `GET /learning/sections?portfolioId=`
- `GET /learning/sections/{slug}?portfolioId=`
- `GET /learning/lessons/{id}`
- `POST /learning/lessons/{id}/complete?portfolioId=`
- `GET /quizzes/{id}`
- `POST /quizzes/{id}/attempts?portfolioId=` (header `Idempotency-Key`)
- `GET /me/progress?portfolioId=`
- `GET /me/achievements?portfolioId=`
- `GET /me/grants?portfolioId=`

**Админка** (`/api/admin/*`) — открыта в закрытом контуре без auth:
- CRUD `/sections`, `/lessons`, `/quizzes`, `/achievements`
- `GET /users`, `GET /users/{id}`, `POST /users/{id}/grants`
- `GET /audit?take=`
- `POST /uploads` (multipart)

## Top-up через тест

`QuizService.SubmitAttemptAsync` проверяет ответы на сервере. Если все правильные — пишет `QuizAttempt(IsPassed=true)`, добавляет XP, дёргает `GrantService.GrantAsync` (идемпотентно по ключу `quiz-{attemptId}`), который вызывает `IBrokerageGateway`.

`StubBrokerageGateway` пишет grant как `committed` без реального вызова. Когда у торгового бэка появится API — реализуется `HttpBrokerageGateway` и регистрируется вместо stub в `Program.cs`.
