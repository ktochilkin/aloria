import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Pencil } from 'lucide-react';
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
        title="Разделы обучения"
        subtitle="Каждый раздел содержит набор уроков. Порядок задаёт навигацию."
        actions={
          <Button variant="primary" onClick={() => setEditing('new')}>
            <Plus className="size-4" /> Новый раздел
          </Button>
        }
      />

      {isLoading && <Spinner />}
      {data && data.length === 0 && <EmptyState title="Разделов ещё нет" hint="Создай первый — и он появится в списке." />}
      {data && data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">Порядок</th>
                <th className="px-4 py-3 font-semibold">Slug</th>
                <th className="px-4 py-3 font-semibold">Название</th>
                <th className="px-4 py-3 font-semibold text-center">Уроков</th>
                <th className="px-4 py-3 font-semibold text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {data.map((s) => (
                <tr key={s.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50">
                  <td className="px-4 py-3 text-(--color-fg-muted) font-mono">{s.order}</td>
                  <td className="px-4 py-3 font-mono text-xs">{s.slug}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold">{s.title}</div>
                    {s.description && <div className="text-xs text-(--color-fg-muted) mt-0.5 line-clamp-1">{s.description}</div>}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <Badge tone="primary">{s.lessonCount}</Badge>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 justify-end">
                      <Button variant="ghost" onClick={() => setEditing(s)}>
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        onClick={() => {
                          if (confirm(`Удалить раздел "${s.title}"? Уроки внутри тоже удалятся.`)) remove.mutate(s.id);
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
      ? { slug: initial.slug, title: initial.title, description: initial.description, order: initial.order, prerequisiteSectionId: initial.prerequisiteSectionId }
      : { slug: '', title: '', description: '', order: 0, prerequisiteSectionId: null }
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
      <Card className="w-[560px] max-w-[95vw] p-6" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        <div className="text-lg font-bold mb-4">{initial ? 'Редактировать раздел' : 'Новый раздел'}</div>
        <div className="grid gap-4">
          <Field label="Slug" hint="Короткое имя в URL: orders, basics-trading">
            <Input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} placeholder="basics-orders" />
          </Field>
          <Field label="Название">
            <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Что такое заявки" />
          </Field>
          <Field label="Описание">
            <Textarea rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </Field>
          <Field label="Порядок отображения">
            <Input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} />
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
