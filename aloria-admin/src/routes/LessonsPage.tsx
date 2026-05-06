import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminLessonListItem, AdminSection } from '../lib/types';
import { Badge, Button, Card, EmptyState, PageHeader, Spinner } from '../components/ui';

export function LessonsPage() {
  const qc = useQueryClient();
  const lessons = useQuery({ queryKey: ['lessons'], queryFn: () => api.get<AdminLessonListItem[]>('/api/admin/lessons') });
  const sections = useQuery({ queryKey: ['sections'], queryFn: () => api.get<AdminSection[]>('/api/admin/sections') });

  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/api/admin/lessons/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['lessons'] }),
  });

  const sectionMap = new Map(sections.data?.map((s) => [s.id, s]) ?? []);
  const grouped = new Map<string, AdminLessonListItem[]>();
  for (const l of lessons.data ?? []) {
    const arr = grouped.get(l.sectionId) ?? [];
    arr.push(l);
    grouped.set(l.sectionId, arr);
  }

  return (
    <div>
      <PageHeader
        title="Уроки"
        subtitle="Markdown-тексты, картинки и привязанные тесты."
        actions={
          <Link to="/lessons/new">
            <Button variant="primary"><Plus className="size-4" /> Новый урок</Button>
          </Link>
        }
      />

      {(lessons.isLoading || sections.isLoading) && <Spinner />}
      {lessons.data && lessons.data.length === 0 && <EmptyState title="Уроков ещё нет" />}

      <div className="space-y-6">
        {Array.from(grouped.entries()).map(([sectionId, items]) => {
          const section = sectionMap.get(sectionId);
          return (
            <Card key={sectionId}>
              <div className="px-5 py-4 border-b border-(--color-border) flex items-center justify-between">
                <div>
                  <div className="text-sm uppercase tracking-wider text-(--color-fg-muted) font-semibold">{section?.slug}</div>
                  <div className="font-bold">{section?.title ?? '—'}</div>
                </div>
                <Badge tone="primary">{items.length} уроков</Badge>
              </div>
              <table className="w-full text-sm">
                <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
                  <tr className="text-left">
                    <th className="px-4 py-2 font-semibold">№</th>
                    <th className="px-4 py-2 font-semibold">Slug</th>
                    <th className="px-4 py-2 font-semibold">Название</th>
                    <th className="px-4 py-2 font-semibold text-center">Время</th>
                    <th className="px-4 py-2 font-semibold text-center">v</th>
                    <th className="px-4 py-2 font-semibold text-center">Тест</th>
                    <th className="px-4 py-2 font-semibold text-right">Действия</th>
                  </tr>
                </thead>
                <tbody>
                  {items.sort((a, b) => a.order - b.order).map((l) => (
                    <tr key={l.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50">
                      <td className="px-4 py-3 text-(--color-fg-muted) font-mono">{l.order}</td>
                      <td className="px-4 py-3 font-mono text-xs">{l.slug}</td>
                      <td className="px-4 py-3">
                        <div className="font-semibold">{l.title}</div>
                        {l.description && <div className="text-xs text-(--color-fg-muted) line-clamp-1 mt-0.5">{l.description}</div>}
                      </td>
                      <td className="px-4 py-3 text-center text-(--color-fg-muted)">{l.estimatedMinutes ? `${l.estimatedMinutes} мин` : '—'}</td>
                      <td className="px-4 py-3 text-center text-(--color-fg-muted) font-mono">{l.version}</td>
                      <td className="px-4 py-3 text-center">{l.hasQuiz ? <Badge tone="success">есть</Badge> : <span className="text-(--color-fg-muted)">—</span>}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1 justify-end">
                          <Link to={`/lessons/${l.id}`}>
                            <Button variant="ghost"><Pencil className="size-4" /></Button>
                          </Link>
                          <Button
                            variant="ghost"
                            onClick={() => {
                              if (confirm(`Удалить урок "${l.title}"?`)) remove.mutate(l.id);
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
          );
        })}
      </div>
    </div>
  );
}
