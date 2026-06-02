import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminConcept, AdminConceptInput } from '../lib/types';
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, Spinner, Textarea } from '../components/ui';

export function ConceptsPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['concepts'],
    queryFn: () => api.get<AdminConcept[]>('/api/admin/concepts'),
  });
  const [editing, setEditing] = useState<AdminConcept | 'new' | null>(null);

  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/api/admin/concepts/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['concepts'] }),
  });

  return (
    <div>
      <PageHeader
        title="Концепции"
        subtitle="Понятия курса (риск, ликвидность и т.п.). Уроки ссылаются на них через introduces / deepens / applies."
        actions={
          <Button variant="primary" onClick={() => setEditing('new')}>
            <Plus className="size-4" /> Новая концепция
          </Button>
        }
      />

      {isLoading && <Spinner />}
      {data && data.length === 0 && (
        <EmptyState title="Концепций ещё нет" hint="Создай первую — она будет доступна для привязки к урокам." />
      )}
      {data && data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">#</th>
                <th className="px-4 py-3 font-semibold">Slug</th>
                <th className="px-4 py-3 font-semibold">Концепция</th>
                <th className="px-4 py-3 font-semibold text-center">В уроках</th>
                <th className="px-4 py-3 font-semibold text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {data.map((c) => (
                <tr key={c.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50">
                  <td className="px-4 py-3 text-(--color-fg-muted) font-mono">{c.order}</td>
                  <td className="px-4 py-3 font-mono text-xs">{c.slug}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold">{c.title}</div>
                    <div className="text-xs text-(--color-fg-muted) mt-0.5 line-clamp-2 max-w-[520px]">
                      {c.shortDefinition}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <Badge tone={c.lessonsCount > 0 ? 'primary' : 'neutral'}>{c.lessonsCount}</Badge>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 justify-end">
                      <Button variant="ghost" onClick={() => setEditing(c)}>
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        onClick={() => {
                          if (confirm(`Удалить «${c.title}»? Связи с уроками тоже исчезнут.`)) remove.mutate(c.id);
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
        <ConceptEditor
          initial={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            qc.invalidateQueries({ queryKey: ['concepts'] });
          }}
        />
      )}
    </div>
  );
}

function ConceptEditor({ initial, onClose, onSaved }: { initial: AdminConcept | null; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState<AdminConceptInput>(
    initial
      ? {
          slug: initial.slug,
          title: initial.title,
          shortDefinition: initial.shortDefinition,
          iconName: initial.iconName,
          order: initial.order,
        }
      : { slug: '', title: '', shortDefinition: '', iconName: null, order: 0 },
  );

  const save = useMutation({
    mutationFn: async () => {
      if (initial) await api.put<void>(`/api/admin/concepts/${initial.id}`, form);
      else await api.post<string>('/api/admin/concepts', form);
    },
    onSuccess: onSaved,
  });

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50" onClick={onClose}>
      <Card className="w-[560px] max-w-[95vw] p-6" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        <div className="text-lg font-bold mb-4">{initial ? 'Редактировать концепцию' : 'Новая концепция'}</div>
        <div className="grid gap-4">
          <div className="grid grid-cols-2 gap-3">
            <Field label="Slug" hint="risk, liquidity, coupon">
              <Input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} placeholder="risk" />
            </Field>
            <Field label="Порядок">
              <Input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} />
            </Field>
          </div>
          <Field label="Название">
            <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Риск" />
          </Field>
          <Field label="Иконка" hint="Material icon">
            <Input
              value={form.iconName ?? ''}
              onChange={(e) => setForm({ ...form, iconName: e.target.value || null })}
              placeholder="warning_amber"
            />
          </Field>
          <Field label="Короткое определение">
            <Textarea
              rows={3}
              value={form.shortDefinition}
              onChange={(e) => setForm({ ...form, shortDefinition: e.target.value })}
              placeholder="Неопределённость результата — диапазон возможных исходов..."
            />
          </Field>
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
