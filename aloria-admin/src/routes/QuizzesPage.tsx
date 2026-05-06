import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminQuiz, AdminQuizInput, AdminQuizQuestionInput } from '../lib/types';
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, Spinner, Textarea } from '../components/ui';

type QuizListItem = {
  id: string;
  lessonId: string | null;
  slug: string;
  title: string;
  description: string;
  rewardXp: number;
  rewardBuyingPower: number;
  questionCount: number;
  updatedAt: string;
};

export function QuizzesPage() {
  const qc = useQueryClient();
  const list = useQuery({ queryKey: ['quizzes'], queryFn: () => api.get<QuizListItem[]>('/api/admin/quizzes') });
  const [editing, setEditing] = useState<string | 'new' | null>(null);

  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/api/admin/quizzes/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['quizzes'] }),
  });

  return (
    <div>
      <PageHeader
        title="Тесты"
        subtitle="За правильное прохождение теста начисляются XP и виртуальные рубли."
        actions={
          <Button variant="primary" onClick={() => setEditing('new')}>
            <Plus className="size-4" /> Новый тест
          </Button>
        }
      />

      {list.isLoading && <Spinner />}
      {list.data?.length === 0 && <EmptyState title="Тестов нет" />}

      {list.data && list.data.length > 0 && (
        <Card>
          <table className="w-full text-sm">
            <thead className="bg-(--color-bg) text-xs uppercase tracking-wider text-(--color-fg-muted)">
              <tr className="text-left">
                <th className="px-4 py-3 font-semibold">Slug</th>
                <th className="px-4 py-3 font-semibold">Название</th>
                <th className="px-4 py-3 font-semibold text-center">Вопросов</th>
                <th className="px-4 py-3 font-semibold text-center">XP</th>
                <th className="px-4 py-3 font-semibold text-center">Бонус ₽</th>
                <th className="px-4 py-3 font-semibold text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {list.data.map((q) => (
                <tr key={q.id} className="border-t border-(--color-border) hover:bg-(--color-bg)/50">
                  <td className="px-4 py-3 font-mono text-xs">{q.slug}</td>
                  <td className="px-4 py-3 font-semibold">{q.title}</td>
                  <td className="px-4 py-3 text-center"><Badge tone="primary">{q.questionCount}</Badge></td>
                  <td className="px-4 py-3 text-center font-mono">{q.rewardXp}</td>
                  <td className="px-4 py-3 text-center font-mono">{q.rewardBuyingPower}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 justify-end">
                      <Button variant="ghost" onClick={() => setEditing(q.id)}><Pencil className="size-4" /></Button>
                      <Button variant="ghost" onClick={() => { if (confirm(`Удалить тест "${q.title}"?`)) remove.mutate(q.id); }}>
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

      {editing && <QuizEditorDialog quizId={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); qc.invalidateQueries({ queryKey: ['quizzes'] }); }} />}
    </div>
  );
}

function QuizEditorDialog({ quizId, onClose, onSaved }: { quizId: string | null; onClose: () => void; onSaved: () => void }) {
  const existing = useQuery({
    queryKey: ['quiz', quizId],
    queryFn: () => api.get<AdminQuiz>(`/api/admin/quizzes/${quizId}`),
    enabled: quizId !== null,
  });

  const [form, setForm] = useState<AdminQuizInput>({
    lessonId: null,
    slug: '',
    title: '',
    description: '',
    rewardXp: 25,
    rewardBuyingPower: 0,
    questions: [],
  });

  const [loaded, setLoaded] = useState(false);
  if (existing.data && !loaded) {
    setForm({
      lessonId: existing.data.lessonId,
      slug: existing.data.slug,
      title: existing.data.title,
      description: existing.data.description,
      rewardXp: existing.data.rewardXp,
      rewardBuyingPower: existing.data.rewardBuyingPower,
      questions: existing.data.questions.map((q) => ({
        id: q.id,
        text: q.text,
        allowsMultiple: q.allowsMultiple,
        order: q.order,
        options: q.options.map((o) => ({ id: o.id, text: o.text, isCorrect: o.isCorrect, explanation: o.explanation, order: o.order })),
      })),
    });
    setLoaded(true);
  }

  const save = useMutation({
    mutationFn: async () => {
      if (quizId) await api.put<void>(`/api/admin/quizzes/${quizId}`, form);
      else await api.post<string>('/api/admin/quizzes', form);
    },
    onSuccess: onSaved,
  });

  const addQuestion = () => setForm({ ...form, questions: [...form.questions, { text: '', allowsMultiple: false, order: form.questions.length, options: [{ text: '', isCorrect: true, explanation: null, order: 0 }, { text: '', isCorrect: false, explanation: null, order: 1 }] }] });
  const removeQuestion = (i: number) => setForm({ ...form, questions: form.questions.filter((_, idx) => idx !== i) });
  const updateQuestion = (i: number, patch: Partial<AdminQuizQuestionInput>) => setForm({ ...form, questions: form.questions.map((q, idx) => (idx === i ? { ...q, ...patch } : q)) });

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4 overflow-y-auto" onClick={onClose}>
      <Card className="w-[820px] max-w-full p-6 my-8 max-h-[92vh] flex flex-col" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
        <div className="text-lg font-bold mb-4">{quizId ? 'Редактировать тест' : 'Новый тест'}</div>

        <div className="grid grid-cols-2 gap-4 mb-4">
          <Field label="Slug"><Input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} /></Field>
          <Field label="Название"><Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></Field>
          <Field label="Описание"><Textarea rows={2} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Field>
          <div className="grid grid-cols-2 gap-2">
            <Field label="XP"><Input type="number" value={form.rewardXp} onChange={(e) => setForm({ ...form, rewardXp: parseInt(e.target.value) || 0 })} /></Field>
            <Field label="Бонус ₽"><Input type="number" value={form.rewardBuyingPower} onChange={(e) => setForm({ ...form, rewardBuyingPower: parseFloat(e.target.value) || 0 })} /></Field>
          </div>
        </div>

        <div className="border-t border-(--color-border) pt-4 flex-1 overflow-y-auto space-y-4">
          {form.questions.map((q, qi) => (
            <Card key={qi} className="p-4 space-y-3 bg-(--color-bg)">
              <div className="flex items-start gap-3">
                <div className="text-xs uppercase tracking-wider text-(--color-fg-muted) pt-2 font-mono">#{qi + 1}</div>
                <div className="flex-1 space-y-2">
                  <Textarea rows={2} placeholder="Текст вопроса" value={q.text} onChange={(e) => updateQuestion(qi, { text: e.target.value })} />
                  <label className="text-xs text-(--color-fg-muted) flex items-center gap-2">
                    <input type="checkbox" checked={q.allowsMultiple} onChange={(e) => updateQuestion(qi, { allowsMultiple: e.target.checked })} />
                    Несколько правильных ответов
                  </label>
                  <div className="space-y-1.5">
                    {q.options.map((o, oi) => (
                      <div key={oi} className="flex items-start gap-2">
                        <input
                          type="checkbox"
                          checked={o.isCorrect}
                          onChange={(e) => updateQuestion(qi, {
                            options: q.options.map((opt, idx) => idx === oi ? { ...opt, isCorrect: e.target.checked } : (q.allowsMultiple ? opt : { ...opt, isCorrect: false }))
                          })}
                          className="mt-2.5"
                        />
                        <Input value={o.text} placeholder={`Вариант ${oi + 1}`} onChange={(e) => updateQuestion(qi, { options: q.options.map((opt, idx) => idx === oi ? { ...opt, text: e.target.value } : opt) })} />
                        <Button variant="ghost" onClick={() => updateQuestion(qi, { options: q.options.filter((_, idx) => idx !== oi) })}>
                          <Trash2 className="size-4 text-(--color-error)" />
                        </Button>
                      </div>
                    ))}
                    <Button variant="ghost" onClick={() => updateQuestion(qi, { options: [...q.options, { text: '', isCorrect: false, explanation: null, order: q.options.length }] })}>
                      <Plus className="size-4" /> Вариант
                    </Button>
                  </div>
                  <Textarea rows={2} placeholder="Объяснение правильного ответа" value={q.options.find((o) => o.isCorrect)?.explanation ?? ''} onChange={(e) => updateQuestion(qi, { options: q.options.map((opt) => opt.isCorrect ? { ...opt, explanation: e.target.value || null } : opt) })} />
                </div>
                <Button variant="ghost" onClick={() => removeQuestion(qi)}><Trash2 className="size-4 text-(--color-error)" /></Button>
              </div>
            </Card>
          ))}
          <Button variant="secondary" onClick={addQuestion}><Plus className="size-4" /> Добавить вопрос</Button>
        </div>

        <div className="flex justify-end gap-2 mt-4 pt-4 border-t border-(--color-border)">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button variant="primary" onClick={() => save.mutate()} disabled={save.isPending}>
            {save.isPending ? 'Сохраняю…' : 'Сохранить'}
          </Button>
        </div>
        {save.error && <div className="text-sm text-(--color-error) mt-2">{(save.error as Error).message}</div>}
      </Card>
    </div>
  );
}
