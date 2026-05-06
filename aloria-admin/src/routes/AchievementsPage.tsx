import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { api } from '../lib/api';
import { ACHIEVEMENT_CONDITIONS, type AdminAchievement, type AdminAchievementInput } from '../lib/types';
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, Select, Spinner, Textarea } from '../components/ui';

export function AchievementsPage() {
  const qc = useQueryClient();
  const list = useQuery({ queryKey: ['achievements'], queryFn: () => api.get<AdminAchievement[]>('/api/admin/achievements') });
  const [editing, setEditing] = useState<AdminAchievement | 'new' | null>(null);

  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/api/admin/achievements/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['achievements'] }),
  });

  return (
    <div>
      <PageHeader
        title="Ачивки"
        subtitle="Условия проверяются на сервере при каждом значимом событии."
        actions={<Button variant="primary" onClick={() => setEditing('new')}><Plus className="size-4" /> Новая ачивка</Button>}
      />

      {list.isLoading && <Spinner />}
      {list.data?.length === 0 && <EmptyState title="Ачивок нет" />}

      {list.data && list.data.length > 0 && (
        <div className="grid grid-cols-2 gap-4">
          {list.data.map((a) => {
            const cond = ACHIEVEMENT_CONDITIONS.find((c) => c.value === a.condition);
            return (
              <Card key={a.id} className="p-4 flex gap-3">
                <div className="size-12 grid place-items-center bg-(--color-primary-50) rounded-xl text-(--color-primary)">
                  <span className="material-icons text-2xl">{a.iconName.replace(/_/g, ' ').slice(0, 2).toUpperCase()}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold">{a.title}</div>
                  <div className="text-xs text-(--color-fg-muted) mt-0.5">{a.description}</div>
                  <div className="flex items-center gap-2 mt-2 flex-wrap">
                    <Badge tone="primary">{cond?.label ?? `cond ${a.condition}`}{cond?.usesThreshold ? ` ≥ ${a.conditionThreshold}` : ''}</Badge>
                    {a.rewardXp > 0 && <Badge tone="success">+{a.rewardXp} XP</Badge>}
                    {a.rewardBuyingPower > 0 && <Badge tone="warning">+{a.rewardBuyingPower} ₽</Badge>}
                  </div>
                </div>
                <div className="flex flex-col gap-1">
                  <Button variant="ghost" onClick={() => setEditing(a)}><Pencil className="size-4" /></Button>
                  <Button variant="ghost" onClick={() => { if (confirm(`Удалить "${a.title}"?`)) remove.mutate(a.id); }}>
                    <Trash2 className="size-4 text-(--color-error)" />
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {editing && (
        <AchievementEditor
          initial={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); qc.invalidateQueries({ queryKey: ['achievements'] }); }}
        />
      )}
    </div>
  );
}

function AchievementEditor({ initial, onClose, onSaved }: { initial: AdminAchievement | null; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState<AdminAchievementInput>(
    initial
      ? { code: initial.code, title: initial.title, description: initial.description, iconName: initial.iconName, condition: initial.condition, conditionThreshold: initial.conditionThreshold, conditionArg: initial.conditionArg, rewardXp: initial.rewardXp, rewardBuyingPower: initial.rewardBuyingPower, order: initial.order }
      : { code: '', title: '', description: '', iconName: 'emoji_events', condition: 1, conditionThreshold: 1, conditionArg: null, rewardXp: 25, rewardBuyingPower: 0, order: 0 }
  );

  const save = useMutation({
    mutationFn: async () => {
      if (initial) await api.put<void>(`/api/admin/achievements/${initial.id}`, form);
      else await api.post<string>('/api/admin/achievements', form);
    },
    onSuccess: onSaved,
  });

  const cond = ACHIEVEMENT_CONDITIONS.find((c) => c.value === form.condition);

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <Card className="w-[600px] max-w-full p-6" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        <div className="text-lg font-bold mb-4">{initial ? 'Редактировать ачивку' : 'Новая ачивка'}</div>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Код" hint="snake_case, для аналитики"><Input value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} /></Field>
          <Field label="Иконка (Material Icon)" hint="emoji_events, school, fact_check…"><Input value={form.iconName} onChange={(e) => setForm({ ...form, iconName: e.target.value })} /></Field>
          <Field label="Заголовок"><Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></Field>
          <Field label="Порядок"><Input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} /></Field>
          <div className="col-span-2"><Field label="Описание"><Textarea rows={2} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Field></div>
          <Field label="Условие">
            <Select value={form.condition} onChange={(e) => setForm({ ...form, condition: parseInt(e.target.value) })}>
              {ACHIEVEMENT_CONDITIONS.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
            </Select>
          </Field>
          {cond?.usesThreshold && (
            <Field label="Порог">
              <Input type="number" value={form.conditionThreshold} onChange={(e) => setForm({ ...form, conditionThreshold: parseInt(e.target.value) || 0 })} />
            </Field>
          )}
          <Field label="Награда XP"><Input type="number" value={form.rewardXp} onChange={(e) => setForm({ ...form, rewardXp: parseInt(e.target.value) || 0 })} /></Field>
          <Field label="Бонус покупательной способности (₽)"><Input type="number" value={form.rewardBuyingPower} onChange={(e) => setForm({ ...form, rewardBuyingPower: parseFloat(e.target.value) || 0 })} /></Field>
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
