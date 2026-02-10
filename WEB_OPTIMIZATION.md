/// Оптимизации для веб-платформы
/// 
/// Этот файл содержит рекомендации по сборке и запуску веб-версии
/// для оптимальной производительности на iOS Safari

## Сборка для продакшена

Для оптимальной производительности используйте:

```bash
# Сборка с CanvasKit (рекомендуется для iOS)
flutter build web --web-renderer canvaskit --release

# Или с автовыбором рендерера
flutter build web --web-renderer auto --release

# С tree-shaking для уменьшения размера
flutter build web --release --tree-shake-icons
```

## Оптимизации

1. **CanvasKit рендерер**: Лучше работает на iOS Safari, чем HTML рендерер
2. **Плавная прокрутка**: Используется `BouncingScrollPhysics` для веб-платформы
3. **GPU ускорение**: CSS оптимизации в `web/index.html`
4. **Touch events**: Улучшенная обработка сенсорных событий

## Дополнительные настройки

В `web/index.html` добавлены:
- `-webkit-overflow-scrolling: touch` для плавной прокрутки
- `transform: translateZ(0)` для GPU ускорения
- `-webkit-tap-highlight-color: transparent` для отключения подсветки
- `minimal-ui` в viewport для полноэкранного режима

## Тестирование

Проверьте на реальном устройстве iOS:
1. Откройте Safari DevTools на Mac
2. Подключите iPhone через USB
3. Проверьте производительность в Web Inspector
