import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { AdminAuditEntry } from '../lib/types';
import { Badge, Card, EmptyState, PageHeader, Spinner } from '../components/ui';

export function AuditPage() {
  const list = useQuery({ queryKey: ['audit'], queryFn: () => api.get<AdminAuditEntry[]>('/api/admin/audit?take=200') });

  return (
    <div>
      <PageHeader title="Аудит" subtitle="Что происходило в админке последнее время." />

      {list.isLoading && <Spinner />}
      {list.data?.length === 0 && <EmptyState title="Лог пуст" />}

      {list.data && list.data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">Время</th>
                <th className="px-4 py-3 font-semibold">Кто</th>
                <th className="px-4 py-3 font-semibold">Действие</th>
                <th className="px-4 py-3 font-semibold">Сущность</th>
                <th className="px-4 py-3 font-semibold">Подробности</th>
              </tr>
            </thead>
            <tbody>
              {list.data.map((e) => (
                <tr key={e.id} className="border-t border-(--color-border)">
                  <td className="px-4 py-2.5 text-(--color-fg-muted) font-mono text-xs">{new Date(e.createdAt).toLocaleString()}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{e.actor}</td>
                  <td className="px-4 py-2.5">
                    {e.action === 'create' && <Badge tone="success">create</Badge>}
                    {e.action === 'update' && <Badge tone="primary">update</Badge>}
                    {e.action === 'delete' && <Badge tone="error">delete</Badge>}
                  </td>
                  <td className="px-4 py-2.5">
                    <span className="font-semibold">{e.entityType}</span>
                    {e.entityId && <span className="text-xs text-(--color-fg-muted) ml-2 font-mono">{e.entityId.slice(0, 8)}</span>}
                  </td>
                  <td className="px-4 py-2.5 text-(--color-fg-muted)">{e.details ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
    </div>
  );
}
