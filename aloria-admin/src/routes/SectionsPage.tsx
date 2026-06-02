import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Pencil, Star } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminSection, AdminSectionInput } from '../lib/types';
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, Spinner, Textarea } from '../components/ui';

export function SectionsPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['sections'],
    queryFn: () => api.get<AdminSection[]>('/api/admin/sections'),
  });
  const [editing, setEditing] = useState<AdminSection | 'new' | null>(null);

  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/api/admin/sections/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['sections'] }),
  });

  return (
    <div>
      <PageHeader
        title="Этапы обучения"
        subtitle="Спиральный курс: каждый этап замкнут вокруг класса инструментов или задачи."
        actions={
          <Button variant="primary" onClick={() => setEditing('new')}>
            <Plus className="size-4" /> Новый этап
          </Button>
        }
      />

      {isLoading && <Spinner />}
      {data && data.length === 0 && <EmptyState title="Этапов ещё нет" hint="Создай первый — и он появится в списке." />}
      {data && data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">#</th>
                <th className="px-4 py-3 font-semibold">Slug</th>
                <th className="px-4 py-3 font-semibold">Этап</th>
                <th className="px-4 py-3 font-semibold text-center">~мин</th>
                <th className="px-4 py-3 font-semibold text-center">Уроков</th>
                <th className="px-4 py-3 font-semibold text-center">Капстоунов</th>
                <th className="px-4 py-3 font-semibold text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {data.map((s) => (
                <tr key={s.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50">
                  <td className="px-4 py-3 text-(--color-fg-muted) font-mono">{s.order}</td>
                  <td className="px-4 py-3 font-mono text-xs">{s.slug}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold">{s.title}</span>
                      {s.isOptional && <Badge tone="neutral">опционально</Badge>}
                    </div>
                    {s.goal && (
                      <div className="text-xs text-(--color-fg-muted) mt-0.5 line-clamp-2 max-w-[420px]">
                        {s.goal}
                      </div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-center text-(--color-fg-muted)">
                    {s.targetMinutes ?? '—'}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <Badge tone="primary">{s.lessonCount}</Badge>
                  </td>
                  <td className="px-4 py-3 text-center">
                    {s.practiceCount > 0 ? (
                      <span className="inline-flex items-center gap-1 text-xs text-(--color-warning)">
                        <Star className="size-3" /> {s.practiceCount}
                      </span>
                    ) : <span className="text-(--color-fg-muted)">—</span>}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 justify-end">
                      <Button variant="ghost" onClick={() => setEditing(s)}>
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        onClick={() => {
                          if (confirm(`Удалить этап "${s.title}"? Уроки внутри тоже удалятся.`)) remove.mutate(s.id);
                        }}
                      >
                        <Trash2 className="size-4 text-(--color-error)" />
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {editing && (
        <SectionEditor
          initial={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            qc.invalidateQueries({ queryKey: ['sections'] });
          }}
        />
      )}
    </div>
  );
}

function SectionEditor({ initial, onClose, onSaved }: { initial: AdminSection | null; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState<AdminSectionInput>(
    initial
      ? {
          slug: initial.slug,
          title: initial.title,
          description: initial.description,
          order: initial.order,
          prerequisiteSectionId: initial.prerequisiteSectionId,
          kind: initial.kind,
          isOptional: initial.isOptional,
          iconName: initial.iconName,
          tint: initial.tint,
          goal: initial.goal,
          targetMinutes: initial.targetMinutes,
        }
      : {
          slug: '',
          title: '',
          description: '',
          order: 0,
          prerequisiteSectionId: null,
          kind: 'stage',
          isOptional: false,
          iconName: null,
          tint: null,
          goal: null,
          targetMinutes: null,
        },
  );

  const save = useMutation({
    mutationFn: async () => {
      if (initial) await api.put<void>(`/api/admin/sections/${initial.id}`, form);
      else await api.post<string>('/api/admin/sections', form);
    },
    onSuccess: onSaved,
  });

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50" onClick={onClose}>
      <Card className="w-[680px] max-w-[95vw] max-h-[92vh] overflow-y-auto p-6" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        <div className="text-lg font-bold mb-4">{initial ? 'Редактировать этап' : 'Новый этап'}</div>
        <div className="grid gap-4">
          <div className="grid grid-cols-3 gap-3">
            <Field label="Порядок">
              <Input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} />
            </Field>
            <Field label="Slug" hint="URL: stocks, bonds">
              <Input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} placeholder="stocks" />
            </Field>
            <Field label="~ минут">
              <Input
                type="number"
                value={form.targetMinutes ?? ''}
                onChange={(e) => setForm({ ...form, targetMinutes: e.target.value === '' ? null : parseInt(e.target.value) || 0 })}
              />
            </Field>
          </div>
          <Field label="Название">
            <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Акции как доля бизнеса" />
          </Field>
          <Field label="Подзаголовок" hint="Короткая фраза под названием в списке этапов">
            <Textarea rows={2} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </Field>
          <Field label="Цель этапа" hint="Что узнаю / смогу после прохождения. Показывается в карточке этапа.">
            <Textarea
              rows={3}
              value={form.goal ?? ''}
              onChange={(e) => setForm({ ...form, goal: e.target.value || null })}
              placeholder="Понять акцию как долю в бизнесе, разобрать..."
            />
          </Field>
          <div className="grid grid-cols-3 gap-3">
            <Field label="Иконка" hint="Material icon, напр. business">
              <Input
                value={form.iconName ?? ''}
                onChange={(e) => setForm({ ...form, iconName: e.target.value || null })}
                placeholder="business"
              />
            </Field>
            <Field label="Цвет" hint="primary | secondary | success | warning">
              <Input
                value={form.tint ?? ''}
                onChange={(e) => setForm({ ...form, tint: e.target.value || null })}
                placeholder="success"
              />
            </Field>
            <Field label="Тип">
              <Input
                value={form.kind ?? 'stage'}
                onChange={(e) => setForm({ ...form, kind: e.target.value || 'stage' })}
                placeholder="stage"
              />
            </Field>
          </div>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={form.isOptional ?? false}
              onChange={(e) => setForm({ ...form, isOptional: e.target.checked })}
              className="size-4"
            />
            <span className="text-sm">Опциональный этап (по желанию ученика)</span>
          </label>
        </div>
        <div className="flex justify-end gap-2 mt-6">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button variant="primary" onClick={() => save.mutate()} disabled={save.isPending}>
            {save.isPending ? 'Сохраняю…' : 'Сохранить'}
          </Button>
        </div>
        {save.error && <div className="text-sm text-(--color-error) mt-3">{(save.error as Error).message}</div>}
      </Card>
    </div>
  );
}
