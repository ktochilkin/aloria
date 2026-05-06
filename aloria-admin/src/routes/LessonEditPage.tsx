import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import MDEditor from '@uiw/react-md-editor';
import { ArrowLeft, ImagePlus, Save, Trash2 } from 'lucide-react';
import { api, uploadFile } from '../lib/api';
import type { AdminLesson, AdminLessonInput, AdminSection } from '../lib/types';
import { Button, Card, Field, Input, PageHeader, Select, Spinner, Textarea } from '../components/ui';

export function LessonEditPage() {
  const { id } = useParams();
  const isNew = id === 'new';
  const nav = useNavigate();
  const qc = useQueryClient();

  const sections = useQuery({ queryKey: ['sections'], queryFn: () => api.get<AdminSection[]>('/api/admin/sections') });
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
  });

  useEffect(() => {
    if (existing.data) {
      setForm({
        sectionId: existing.data.sectionId,
        slug: existing.data.slug,
        title: existing.data.title,
        description: existing.data.description,
        bodyMd: existing.data.bodyMd,
        imageUrl: existing.data.imageUrl,
        estimatedMinutes: existing.data.estimatedMinutes,
        academicDefinition: existing.data.academicDefinition,
        order: existing.data.order,
      });
    }
    if (isNew && sections.data && sections.data.length > 0 && !form.sectionId) {
      setForm((f) => ({ ...f, sectionId: sections.data[0].id }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [existing.data, sections.data, isNew]);

  const save = useMutation({
    mutationFn: async () => {
      if (isNew) await api.post<string>('/api/admin/lessons', form);
      else await api.put<void>(`/api/admin/lessons/${id}`, form);
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

      <div className="grid grid-cols-[1fr_320px] gap-6">
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
              <Field label="Раздел">
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

          <Card className="p-4">
            <Field label="Академическое определение">
              <Textarea
                rows={4}
                value={form.academicDefinition ?? ''}
                onChange={(e) => setForm({ ...form, academicDefinition: e.target.value || null })}
                placeholder="Точная формулировка, которую можно показать справочно"
              />
            </Field>
          </Card>
        </div>
      </div>

      {save.error && <div className="text-sm text-(--color-error) mt-4">{(save.error as Error).message}</div>}
    </div>
  );
}
