import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import MDEditor from '@uiw/react-md-editor';
import { ArrowLeft, ImagePlus, Save, Trash2, Star } from 'lucide-react';
import { api, uploadFile } from '../lib/api';
import type {
  AdminConcept,
  AdminLesson,
  AdminLessonInput,
  AdminLessonConceptsInput,
  AdminSection,
} from '../lib/types';
import { Badge, Button, Card, Field, Input, PageHeader, Select, Spinner, Textarea } from '../components/ui';

export function LessonEditPage() {
  const { id } = useParams();
  const isNew = id === 'new';
  const nav = useNavigate();
  const qc = useQueryClient();

  const sections = useQuery({ queryKey: ['sections'], queryFn: () => api.get<AdminSection[]>('/api/admin/sections') });
  const concepts = useQuery({ queryKey: ['concepts'], queryFn: () => api.get<AdminConcept[]>('/api/admin/concepts') });
  const existing = useQuery({
    queryKey: ['lesson', id],
    queryFn: () => api.get<AdminLesson>(`/api/admin/lessons/${id}`),
    enabled: !isNew,
  });

  const [form, setForm] = useState<AdminLessonInput>({
    sectionId: '',
    slug: '',
    title: '',
    description: '',
    bodyMd: '# Заголовок\n\nТело урока…',
    imageUrl: null,
    estimatedMinutes: null,
    academicDefinition: null,
    order: 0,
    isCapstone: false,
    roleHint: null,
    practiceRequirementCode: null,
    group: null,
    recallPrompt: null,
    recallAnswer: null,
    practiceText: null,
    practiceSymbol: null,
  });

  const [conceptForm, setConceptForm] = useState<AdminLessonConceptsInput>({
    introduces: [], deepens: [], applies: [],
  });

  useEffect(() => {
    if (existing.data) {
      const d = existing.data;
      setForm({
        sectionId: d.sectionId,
        slug: d.slug,
        title: d.title,
        description: d.description,
        bodyMd: d.bodyMd,
        imageUrl: d.imageUrl,
        estimatedMinutes: d.estimatedMinutes,
        academicDefinition: d.academicDefinition,
        order: d.order,
        isCapstone: d.isCapstone,
        roleHint: d.roleHint,
        practiceRequirementCode: d.practiceRequirementCode,
        group: d.group,
        recallPrompt: d.recallPrompt,
        recallAnswer: d.recallAnswer,
        practiceText: d.practiceText,
        practiceSymbol: d.practiceSymbol,
      });
      setConceptForm({
        introduces: d.concepts.filter((c) => c.role === 'Introduce').map((c) => c.conceptSlug),
        deepens: d.concepts.filter((c) => c.role === 'Deepen').map((c) => c.conceptSlug),
        applies: d.concepts.filter((c) => c.role === 'Apply').map((c) => c.conceptSlug),
      });
    }
    if (isNew && sections.data && sections.data.length > 0 && !form.sectionId) {
      setForm((f) => ({ ...f, sectionId: sections.data[0].id }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [existing.data, sections.data, isNew]);

  const save = useMutation({
    mutationFn: async () => {
      let lessonId = id;
      if (isNew) {
        lessonId = await api.post<string>('/api/admin/lessons', form);
      } else {
        await api.put<void>(`/api/admin/lessons/${id}`, form);
      }
      // Сохраняем связи с концепциями.
      if (lessonId) {
        await api.put<void>(`/api/admin/lessons/${lessonId}/concepts`, conceptForm);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['lessons'] });
      qc.invalidateQueries({ queryKey: ['lesson', id] });
      nav('/lessons');
    },
  });

  const remove = useMutation({
    mutationFn: () => api.del(`/api/admin/lessons/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['lessons'] });
      nav('/lessons');
    },
  });

  if (!isNew && existing.isLoading) return <Spinner />;
  if (!isNew && existing.isError) return <div className="text-(--color-error)">Не удалось загрузить урок</div>;

  return (
    <div>
      <PageHeader
        title={isNew ? 'Новый урок' : form.title || 'Урок'}
        subtitle={isNew ? 'Заполни поля и тело — потом можно добавить тест' : `slug: ${form.slug}`}
        actions={
          <>
            <Button variant="ghost" onClick={() => nav('/lessons')}>
              <ArrowLeft className="size-4" /> К списку
            </Button>
            {!isNew && (
              <Button variant="ghost" onClick={() => { if (confirm('Удалить урок?')) remove.mutate(); }}>
                <Trash2 className="size-4 text-(--color-error)" />
              </Button>
            )}
            <Button variant="primary" onClick={() => save.mutate()} disabled={save.isPending}>
              <Save className="size-4" /> {save.isPending ? 'Сохраняю…' : 'Сохранить'}
            </Button>
          </>
        }
      />

      <div className="grid grid-cols-[1fr_340px] gap-6">
        <Card className="p-4">
          <div data-color-mode="light">
            <MDEditor
              value={form.bodyMd}
              onChange={(v) => setForm({ ...form, bodyMd: v ?? '' })}
              height={680}
              preview="live"
            />
          </div>
        </Card>

        <div className="space-y-4">
          <Card className="p-4">
            <div className="space-y-3">
              <Field label="Этап">
                <Select value={form.sectionId} onChange={(e) => setForm({ ...form, sectionId: e.target.value })}>
                  <option value="">— выбрать —</option>
                  {sections.data?.map((s) => <option key={s.id} value={s.id}>{s.title}</option>)}
                </Select>
              </Field>
              <Field label="Slug" hint="orders, what-is-stock">
                <Input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} />
              </Field>
              <Field label="Название">
                <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
              </Field>
              <Field label="Описание">
                <Textarea rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
              </Field>
              <div className="grid grid-cols-2 gap-2">
                <Field label="Порядок">
                  <Input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} />
                </Field>
                <Field label="Минут">
                  <Input
                    type="number"
                    value={form.estimatedMinutes ?? ''}
                    onChange={(e) => setForm({ ...form, estimatedMinutes: e.target.value ? parseInt(e.target.value) : null })}
                  />
                </Field>
              </div>
              <Field label="Глава" hint="Опционально: группа уроков внутри этапа">
                <Input
                  value={form.group ?? ''}
                  onChange={(e) => setForm({ ...form, group: e.target.value || null })}
                  placeholder="Облигации"
                />
              </Field>
            </div>
          </Card>

          <Card className="p-4">
            <div className="text-sm font-semibold mb-3 flex items-center gap-2">
              <Star className="size-4 text-(--color-warning)" /> Спиральный курс
            </div>
            <div className="space-y-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.isCapstone ?? false}
                  onChange={(e) => setForm({ ...form, isCapstone: e.target.checked })}
                  className="size-4"
                />
                <span className="text-sm">Капстоун этапа</span>
              </label>
              <Field label="Роль" hint="introduce / deepen / apply — подсказка UI">
                <Select
                  value={form.roleHint ?? ''}
                  onChange={(e) => setForm({ ...form, roleHint: e.target.value || null })}
                >
                  <option value="">— не указано —</option>
                  <option value="introduce">introduce</option>
                  <option value="deepen">deepen</option>
                  <option value="apply">apply</option>
                </Select>
              </Field>
              <Field label="Код требования практики" hint="Из practice.json этапа">
                <Input
                  value={form.practiceRequirementCode ?? ''}
                  onChange={(e) => setForm({ ...form, practiceRequirementCode: e.target.value || null })}
                  placeholder="buy-bond"
                />
              </Field>
            </div>
          </Card>

          <Card className="p-4">
            <div className="text-sm font-semibold mb-3">Концепции</div>
            <div className="space-y-3">
              <ConceptPicker
                label="Вводит"
                value={conceptForm.introduces}
                onChange={(v) => setConceptForm({ ...conceptForm, introduces: v })}
                options={concepts.data ?? []}
              />
              <ConceptPicker
                label="Углубляет"
                value={conceptForm.deepens}
                onChange={(v) => setConceptForm({ ...conceptForm, deepens: v })}
                options={concepts.data ?? []}
              />
              <ConceptPicker
                label="Применяет"
                value={conceptForm.applies}
                onChange={(v) => setConceptForm({ ...conceptForm, applies: v })}
                options={concepts.data ?? []}
              />
            </div>
          </Card>

          <Card className="p-4">
            <Field label="Картинка обложки">
              {form.imageUrl ? (
                <div className="relative">
                  <img src={form.imageUrl} className="rounded-lg border border-(--color-border) w-full" />
                  <button
                    onClick={() => setForm({ ...form, imageUrl: null })}
                    className="absolute top-2 right-2 size-7 grid place-items-center bg-black/60 rounded-md text-white text-xs"
                  >
                    ✕
                  </button>
                </div>
              ) : (
                <label className="flex flex-col items-center justify-center gap-2 h-28 border-2 border-dashed border-(--color-border) rounded-lg cursor-pointer hover:border-(--color-primary) hover:bg-(--color-primary-50)">
                  <ImagePlus className="size-5 text-(--color-fg-muted)" />
                  <span className="text-xs text-(--color-fg-muted)">Загрузить</span>
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={async (e) => {
                      const f = e.target.files?.[0];
                      if (!f) return;
                      const r = await uploadFile(f);
                      setForm((curr) => ({ ...curr, imageUrl: r.url }));
                    }}
                  />
                </label>
              )}
            </Field>
          </Card>

          <Card className="p-4 space-y-3">
            <Field label="Академическое определение">
              <Textarea
                rows={3}
                value={form.academicDefinition ?? ''}
                onChange={(e) => setForm({ ...form, academicDefinition: e.target.value || null })}
                placeholder="Точная формулировка для справки"
              />
            </Field>
            <Field label="Recall: вопрос" hint="Карточка самопроверки в конце урока">
              <Textarea
                rows={2}
                value={form.recallPrompt ?? ''}
                onChange={(e) => setForm({ ...form, recallPrompt: e.target.value || null })}
              />
            </Field>
            <Field label="Recall: эталон ответа">
              <Textarea
                rows={2}
                value={form.recallAnswer ?? ''}
                onChange={(e) => setForm({ ...form, recallAnswer: e.target.value || null })}
              />
            </Field>
            <Field label="Практика: текст задания">
              <Textarea
                rows={2}
                value={form.practiceText ?? ''}
                onChange={(e) => setForm({ ...form, practiceText: e.target.value || null })}
              />
            </Field>
            <Field label="Практика: символ инструмента" hint="Опционально, deep-link на рынок">
              <Input
                value={form.practiceSymbol ?? ''}
                onChange={(e) => setForm({ ...form, practiceSymbol: e.target.value || null })}
                placeholder="SBER"
              />
            </Field>
          </Card>
        </div>
      </div>

      {save.error && <div className="text-sm text-(--color-error) mt-4">{(save.error as Error).message}</div>}
    </div>
  );
}

function ConceptPicker({
  label, value, onChange, options,
}: {
  label: string;
  value: string[];
  onChange: (v: string[]) => void;
  options: AdminConcept[];
}) {
  const set = new Set(value);
  const available = options.filter((o) => !set.has(o.slug));
  return (
    <div>
      <div className="text-xs text-(--color-fg-muted) mb-1.5">{label}</div>
      <div className="flex flex-wrap gap-1.5 mb-2">
        {value.length === 0 && <span className="text-xs text-(--color-fg-muted) italic">пусто</span>}
        {value.map((slug) => {
          const c = options.find((o) => o.slug === slug);
          return (
            <Badge key={slug} tone="primary">
              {c?.title ?? slug}
              <button
                className="ml-1 opacity-60 hover:opacity-100"
                onClick={() => onChange(value.filter((s) => s !== slug))}
                title="Убрать"
              >
                ✕
              </button>
            </Badge>
          );
        })}
      </div>
      <Select
        value=""
        onChange={(e) => {
          if (e.target.value) onChange([...value, e.target.value]);
        }}
      >
        <option value="">+ Добавить концепцию</option>
        {available.map((c) => (
          <option key={c.id} value={c.slug}>{c.title} ({c.slug})</option>
        ))}
      </Select>
    </div>
  );
}
