import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Send } from 'lucide-react';
import { clsx } from 'clsx';
import { api } from '../lib/api';
import type { PushDispatchOutcome } from '../lib/types';
import { Button, Card, Field, Input, PageHeader, Textarea } from '../components/ui';

// Экраны, на которые осмысленно вести тапом по пушу (совпадают с нижней
// навигацией приложения). Свободный ввод не даём — чтобы не увести в несуществующий маршрут.
const ROUTES = [
  { value: '/learn', label: 'Обучение' },
  { value: '/positions', label: 'Портфель' },
  { value: '/market', label: 'Обзор рынка' },
];

export function BroadcastPage() {
  const [title, setTitle] = useState('Aloria');
  const [body, setBody] = useState('');
  const [route, setRoute] = useState('/learn');

  const send = useMutation({
    mutationFn: () =>
      api.post<PushDispatchOutcome>('/api/admin/push/broadcast', { title, body, route }),
  });

  const canSend = !!title.trim() && !!body.trim() && !send.isPending;

  return (
    <div>
      <PageHeader
        title="Рассылка"
        subtitle="Пуш уходит на все активные устройства всех пользователей. Только вручную — автоматических нет."
      />

      <Card className="p-6 max-w-2xl">
        <div className="grid gap-4">
          <Field label="Заголовок">
            <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={80} placeholder="Aloria" />
          </Field>
          <Field label="Текст" hint="Коротко и по делу — системные баннеры обрезают длинный текст.">
            <Textarea rows={3} value={body} onChange={(e) => setBody(e.target.value)} maxLength={240} placeholder="Что нового или зачем стоит зайти" />
          </Field>
          <Field label="Куда ведёт тап" hint="Экран, который откроется при нажатии на уведомление.">
            <div className="flex gap-1.5">
              {ROUTES.map((r) => (
                <button
                  key={r.value}
                  type="button"
                  onClick={() => setRoute(r.value)}
                  className={clsx(
                    'flex-1 h-10 rounded-lg text-sm font-semibold border transition-all',
                    route === r.value
                      ? 'bg-(--color-primary) text-white border-transparent'
                      : 'bg-(--color-surface) text-(--color-fg-muted) border-(--color-border) hover:bg-(--color-bg)'
                  )}
                >
                  {r.label}
                </button>
              ))}
            </div>
          </Field>

          <div className="flex items-center gap-3">
            <Button
              variant="primary"
              disabled={!canSend}
              onClick={() => {
                if (confirm('Отправить пуш всем зарегистрированным устройствам?')) send.mutate();
              }}
            >
              <Send className="size-4" /> {send.isPending ? 'Отправляю…' : 'Отправить всем'}
            </Button>
          </div>

          {send.data && (
            <div className="text-sm text-(--color-fg-muted)">
              {send.data.targeted === 0 ? (
                'Нет ни одного активного устройства — пуш никому не ушёл.'
              ) : (
                <>
                  Отправлено <b className="text-(--color-success)">{send.data.sent}</b> из {send.data.targeted} устройств
                  {send.data.disabled > 0 && <> · отключено мёртвых токенов: {send.data.disabled}</>}
                </>
              )}
            </div>
          )}
          {send.error && <div className="text-sm text-(--color-error)">{(send.error as Error).message}</div>}
        </div>
      </Card>
    </div>
  );
}
