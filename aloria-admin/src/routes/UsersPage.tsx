import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Search } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminUserDetail, AdminUserListItem } from '../lib/types';
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, Spinner } from '../components/ui';

export function UsersPage() {
  const [search, setSearch] = useState('');
  const list = useQuery({
    queryKey: ['users', search],
    queryFn: () => api.get<AdminUserListItem[]>(`/api/admin/users${search ? `?search=${encodeURIComponent(search)}` : ''}`),
  });
  const [selected, setSelected] = useState<string | null>(null);

  return (
    <div>
      <PageHeader title="Пользователи" subtitle="Прогресс, попытки тестов, история начислений." />

      <div className="mb-4 flex gap-3 items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-(--color-fg-muted)" />
          <Input className="pl-10" placeholder="Поиск по AlorPortfolioId или нику" value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
      </div>

      {list.isLoading && <Spinner />}
      {list.data?.length === 0 && <EmptyState title="Пока никто не заходил" />}

      {list.data && list.data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">PortfolioId</th>
                <th className="px-4 py-3 font-semibold">Никнейм</th>
                <th className="px-4 py-3 font-semibold text-center">XP</th>
                <th className="px-4 py-3 font-semibold text-center">Lvl</th>
                <th className="px-4 py-3 font-semibold text-center">Стрик</th>
                <th className="px-4 py-3 font-semibold text-center">Уроков</th>
                <th className="px-4 py-3 font-semibold text-center">Тестов</th>
                <th className="px-4 py-3 font-semibold text-right">Бонус</th>
              </tr>
            </thead>
            <tbody>
              {list.data.map((u) => (
                <tr key={u.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50 cursor-pointer" onClick={() => setSelected(u.id)}>
                  <td className="px-4 py-3 font-mono text-xs">{u.alorPortfolioId}</td>
                  <td className="px-4 py-3">{u.displayName ?? <span className="text-(--color-fg-muted)">—</span>}</td>
                  <td className="px-4 py-3 text-center font-mono">{u.xp}</td>
                  <td className="px-4 py-3 text-center"><Badge tone="primary">{u.level}</Badge></td>
                  <td className="px-4 py-3 text-center font-mono">{u.streakDays}</td>
                  <td className="px-4 py-3 text-center font-mono">{u.lessonsCompleted}</td>
                  <td className="px-4 py-3 text-center font-mono">{u.quizzesPassed}</td>
                  <td className="px-4 py-3 text-right font-mono text-(--color-success) font-semibold">+{u.bonusBuyingPower} ₽</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {selected && <UserDetailDialog userId={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

function UserDetailDialog({ userId, onClose }: { userId: string; onClose: () => void }) {
  const qc = useQueryClient();
  const detail = useQuery({ queryKey: ['user', userId], queryFn: () => api.get<AdminUserDetail>(`/api/admin/users/${userId}`) });
  const [grantAmount, setGrantAmount] = useState('');
  const [grantReason, setGrantReason] = useState('');

  const grant = useMutation({
    mutationFn: () => api.post<string>(`/api/admin/users/${userId}/grants`, { amount: parseFloat(grantAmount), reason: grantReason || 'manual' }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['user', userId] });
      qc.invalidateQueries({ queryKey: ['users'] });
      setGrantAmount('');
      setGrantReason('');
    },
  });

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4 overflow-y-auto" onClick={onClose}>
      <Card className="w-[760px] max-w-full p-6 my-8" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        {detail.isLoading && <Spinner />}
        {detail.data && (
          <>
            <div className="flex items-start justify-between mb-4">
              <div>
                <div className="text-lg font-bold">{detail.data.user.displayName ?? detail.data.user.alorPortfolioId}</div>
                <div className="text-xs text-(--color-fg-muted) font-mono">{detail.data.user.alorPortfolioId}</div>
              </div>
              <Button variant="ghost" onClick={onClose}>✕</Button>
            </div>

            <div className="grid grid-cols-4 gap-3 mb-6">
              <StatBox label="XP" value={detail.data.user.xp} />
              <StatBox label="Уровень" value={detail.data.user.level} />
              <StatBox label="Стрик" value={detail.data.user.streakDays} />
              <StatBox label="Бонус ₽" value={detail.data.user.bonusBuyingPower} accent="success" />
            </div>

            <div className="grid grid-cols-2 gap-4 mb-6">
              <Card className="p-4">
                <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) font-semibold mb-2">Попытки тестов</div>
                {detail.data.attempts.length === 0 && <div className="text-sm text-(--color-fg-muted)">Пока нет</div>}
                <div className="space-y-1">
                  {detail.data.attempts.slice(0, 8).map((a) => (
                    <div key={a.id} className="flex items-center gap-2 text-sm">
                      {a.isPassed ? <Badge tone="success">✓</Badge> : <Badge tone="error">✗</Badge>}
                      <div className="flex-1 truncate">{a.quizTitle}</div>
                      <span className="text-xs text-(--color-fg-muted)">{new Date(a.attemptedAt).toLocaleDateString()}</span>
                    </div>
                  ))}
                </div>
              </Card>
              <Card className="p-4">
                <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) font-semibold mb-2">Открытые ачивки</div>
                {detail.data.achievements.length === 0 && <div className="text-sm text-(--color-fg-muted)">Пока нет</div>}
                <div className="space-y-1">
                  {detail.data.achievements.slice(0, 8).map((a) => (
                    <div key={a.achievementId} className="flex items-center gap-2 text-sm">
                      <Badge tone="primary">{a.code}</Badge>
                      <div className="flex-1 truncate">{a.title}</div>
                    </div>
                  ))}
                </div>
              </Card>
            </div>

            <Card className="p-4 mb-4">
              <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) font-semibold mb-2">История начислений</div>
              {detail.data.grants.length === 0 ? (
                <div className="text-sm text-(--color-fg-muted)">Не было</div>
              ) : (
                <table className="w-full text-sm">
                  <tbody>
                    {detail.data.grants.map((g) => (
                      <tr key={g.id} className="border-t border-(--color-border) first:border-t-0">
                        <td className="py-2 font-mono">+{g.amount} ₽</td>
                        <td className="py-2 text-(--color-fg-muted) text-xs">{g.reason}</td>
                        <td className="py-2 text-right">
                          {g.status === 'committed' && <Badge tone="success">committed</Badge>}
                          {g.status === 'pending' && <Badge tone="warning">pending</Badge>}
                          {g.status === 'failed' && <Badge tone="error">failed</Badge>}
                        </td>
                        <td className="py-2 text-right text-xs text-(--color-fg-muted)">{new Date(g.createdAt).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </Card>

            <Card className="p-4">
              <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) font-semibold mb-2">Ручное начисление</div>
              <div className="grid grid-cols-[140px_1fr_auto] gap-2 items-end">
                <Field label="Сумма ₽"><Input type="number" value={grantAmount} onChange={(e) => setGrantAmount(e.target.value)} placeholder="1000" /></Field>
                <Field label="Причина"><Input value={grantReason} onChange={(e) => setGrantReason(e.target.value)} placeholder="manual:test" /></Field>
                <Button variant="primary" onClick={() => grant.mutate()} disabled={grant.isPending || !grantAmount}>Начислить</Button>
              </div>
              {grant.error && <div className="text-sm text-(--color-error) mt-2">{(grant.error as Error).message}</div>}
            </Card>
          </>
        )}
      </Card>
    </div>
  );
}

function StatBox({ label, value, accent }: { label: string; value: number | string; accent?: 'success' | 'warning' }) {
  const color = accent === 'success' ? 'text-(--color-success)' : accent === 'warning' ? 'text-(--color-warning)' : 'text-(--color-fg)';
  return (
    <Card className="px-4 py-3">
      <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) font-semibold">{label}</div>
      <div className={`text-2xl font-bold mt-1 ${color}`}>{value}</div>
    </Card>
  );
}
