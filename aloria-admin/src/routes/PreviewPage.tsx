import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import MDEditor from '@uiw/react-md-editor';
import {
  ArrowLeft, Clock, Star, ChevronRight, BookOpen, Sparkles, Tag,
} from 'lucide-react';
import { api } from '../lib/api';
import type {
  AdminLesson,
  AdminLessonListItem,
  AdminPracticeRequirement,
  AdminSection,
} from '../lib/types';
import { Badge, Card, PageHeader, Spinner } from '../components/ui';

type Mode =
  | { kind: 'list' }
  | { kind: 'stage'; section: AdminSection }
  | { kind: 'lesson'; section: AdminSection; lessonId: string };

/// Просмотр курса «как в приложении»: главный экран со списком этапов,
/// далее экран этапа с дорожкой уроков и блоком практики, далее
/// чтение урока с бейджами концепций. Без редактирования.
export function PreviewPage() {
  const [mode, setMode] = useState<Mode>({ kind: 'list' });
  const sections = useQuery({
    queryKey: ['sections'],
    queryFn: () => api.get<AdminSection[]>('/api/admin/sections'),
  });

  return (
    <div>
      <PageHeader
        title="Превью курса"
        subtitle="Как ученик видит обучение в мобильном приложении. Только просмотр."
      />

      <div className="max-w-md mx-auto">
        <div className="rounded-3xl border border-(--color-border) bg-(--color-surface) overflow-hidden shadow-sm">
          {/* Имитация мобильного фрейма */}
          <div className="bg-(--color-bg) px-5 py-4 border-b border-(--color-border) flex items-center gap-2">
            {mode.kind !== 'list' && (
              <button
                className="size-8 grid place-items-center rounded-full hover:bg-(--color-border)"
                onClick={() => {
                  if (mode.kind === 'lesson') setMode({ kind: 'stage', section: mode.section });
                  else setMode({ kind: 'list' });
                }}
              >
                <ArrowLeft className="size-4" />
              </button>
            )}
            <div className="font-bold">
              {mode.kind === 'list' && 'Обучение'}
              {mode.kind === 'stage' && mode.section.title}
              {mode.kind === 'lesson' && mode.section.title}
            </div>
          </div>

          <div className="p-5 min-h-[480px]">
            {mode.kind === 'list' && (
              <StagesList
                sections={sections.data}
                isLoading={sections.isLoading}
                onOpen={(s) => setMode({ kind: 'stage', section: s })}
              />
            )}
            {mode.kind === 'stage' && (
              <StageView
                section={mode.section}
                onOpenLesson={(lessonId) => setMode({ kind: 'lesson', section: mode.section, lessonId })}
              />
            )}
            {mode.kind === 'lesson' && (
              <LessonView section={mode.section} lessonId={mode.lessonId} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function StagesList({
  sections, isLoading, onOpen,
}: {
  sections: AdminSection[] | undefined;
  isLoading: boolean;
  onOpen: (s: AdminSection) => void;
}) {
  if (isLoading) return <Spinner />;
  if (!sections) return null;
  return (
    <div className="space-y-3">
      {sections.map((s) => (
        <button
          key={s.id}
          onClick={() => onOpen(s)}
          className="w-full text-left rounded-2xl border border-(--color-border) p-4 hover:border-(--color-primary) hover:bg-(--color-primary-50)/40 transition"
        >
          <div className="flex items-start gap-3">
            <div className="size-9 rounded-xl bg-(--color-primary-50) grid place-items-center text-(--color-primary)">
              <BookOpen className="size-4" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="font-bold">{s.title}</span>
                {s.isOptional && <Badge tone="neutral">опционально</Badge>}
              </div>
              {s.goal && (
                <div className="text-xs text-(--color-fg-muted) mt-1 line-clamp-3">{s.goal}</div>
              )}
              <div className="flex items-center gap-3 mt-2 text-xs text-(--color-fg-muted)">
                {s.targetMinutes && (
                  <span className="inline-flex items-center gap-1">
                    <Clock className="size-3" /> ~{s.targetMinutes} мин
                  </span>
                )}
                <span>{s.lessonCount} уроков</span>
                {s.practiceCount > 0 && (
                  <span className="inline-flex items-center gap-1 text-(--color-warning)">
                    <Star className="size-3" /> капстоун ×{s.practiceCount}
                  </span>
                )}
              </div>
            </div>
            <ChevronRight className="size-4 text-(--color-fg-muted) shrink-0 mt-1" />
          </div>
        </button>
      ))}
    </div>
  );
}

function StageView({
  section, onOpenLesson,
}: {
  section: AdminSection;
  onOpenLesson: (lessonId: string) => void;
}) {
  const lessons = useQuery({
    queryKey: ['admin-lessons', section.id],
    queryFn: () => api.get<AdminLessonListItem[]>(`/api/admin/lessons?sectionId=${section.id}`),
  });
  const practice = useQuery({
    queryKey: ['practice', section.id],
    queryFn: () =>
      api.get<AdminPracticeRequirement[]>(`/api/admin/sections/${section.id}/practice`),
  });

  return (
    <div className="space-y-4">
      <div className="rounded-xl bg-(--color-bg) p-3 border border-(--color-border)">
        <div className="text-xs text-(--color-fg-muted)">{section.description}</div>
        {section.goal && (
          <div className="text-sm mt-2 leading-snug">{section.goal}</div>
        )}
        <div className="flex items-center gap-3 mt-2 text-xs text-(--color-fg-muted)">
          {section.targetMinutes && (
            <span className="inline-flex items-center gap-1">
              <Clock className="size-3" /> ~{section.targetMinutes} мин
            </span>
          )}
        </div>
      </div>

      {lessons.isLoading && <Spinner />}
      {lessons.data && (
        <div className="space-y-1.5">
          {lessons.data.map((l, i) => (
            <button
              key={l.id}
              onClick={() => onOpenLesson(l.id)}
              className="w-full text-left rounded-xl border border-(--color-border) p-3 hover:border-(--color-primary) hover:bg-(--color-primary-50)/40 transition flex items-start gap-3"
            >
              <div className={`size-8 rounded-full grid place-items-center text-xs font-bold border border-(--color-border) ${l.isCapstone ? 'bg-(--color-warning-50) text-(--color-warning)' : 'bg-(--color-bg) text-(--color-fg-muted)'}`}>
                {l.isCapstone ? <Star className="size-3.5" /> : i + 1}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-sm">{l.title}</div>
                {l.description && (
                  <div className="text-xs text-(--color-fg-muted) line-clamp-2 mt-0.5">{l.description}</div>
                )}
                <div className="flex items-center gap-2 mt-1 text-[10px] text-(--color-fg-muted)">
                  {l.estimatedMinutes && <span>~{l.estimatedMinutes} мин</span>}
                  {l.hasQuiz && <Badge tone="neutral">тест</Badge>}
                  {l.conceptCount > 0 && (
                    <span className="inline-flex items-center gap-1">
                      <Sparkles className="size-3" /> {l.conceptCount}
                    </span>
                  )}
                </div>
              </div>
              <ChevronRight className="size-4 text-(--color-fg-muted) shrink-0 mt-2" />
            </button>
          ))}
        </div>
      )}

      {practice.data && practice.data.filter((p) => !p.archived).length > 0 && (
        <div className="rounded-xl border border-(--color-warning)/40 bg-(--color-warning-50)/30 p-3">
          <div className="text-sm font-bold flex items-center gap-2 mb-2">
            <Star className="size-4 text-(--color-warning)" /> Закрепить на рынке
          </div>
          <div className="space-y-2">
            {practice.data.filter((p) => !p.archived).map((p) => (
              <div key={p.id} className="text-xs">
                <div className="font-semibold">
                  {p.title}
                  {p.isOptional && <span className="ml-1 text-(--color-fg-muted)">(опц.)</span>}
                </div>
                {p.description && <div className="text-(--color-fg-muted) mt-0.5">{p.description}</div>}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function LessonView({ section, lessonId }: { section: AdminSection; lessonId: string }) {
  const lesson = useQuery({
    queryKey: ['preview-lesson', lessonId],
    queryFn: () => api.get<AdminLesson>(`/api/admin/lessons/${lessonId}`),
  });

  if (lesson.isLoading) return <Spinner />;
  if (!lesson.data) return <div className="text-(--color-error)">Не удалось загрузить</div>;

  const d = lesson.data;
  const introduces = d.concepts.filter((c) => c.role === 'Introduce');
  const deepens = d.concepts.filter((c) => c.role === 'Deepen');
  const applies = d.concepts.filter((c) => c.role === 'Apply');

  return (
    <div className="space-y-4">
      {d.isCapstone && (
        <Badge tone="warning">
          <Star className="size-3 inline mr-1" /> Капстоун этапа
        </Badge>
      )}

      <div>
        <div className="text-xs text-(--color-fg-muted) mb-1">{section.title}</div>
        <h1 className="text-2xl font-bold leading-tight">{d.title}</h1>
        {d.description && <p className="text-sm text-(--color-fg-muted) mt-2">{d.description}</p>}
      </div>

      {d.imageUrl && (
        <img src={d.imageUrl} className="rounded-xl border border-(--color-border) w-full" />
      )}

      {(deepens.length > 0 || applies.length > 0) && (
        <Card className="p-3">
          <div className="text-xs text-(--color-fg-muted) mb-2 inline-flex items-center gap-1">
            <Tag className="size-3" /> Возвращаемся к концепциям
          </div>
          <div className="flex flex-wrap gap-1.5">
            {deepens.map((c) => (
              <Badge key={c.conceptSlug + 'd'} tone="primary">
                {c.conceptTitle}
                <span className="ml-1 text-[10px] opacity-70">углубление</span>
              </Badge>
            ))}
            {applies.map((c) => (
              <Badge key={c.conceptSlug + 'a'} tone="primary">
                {c.conceptTitle}
                <span className="ml-1 text-[10px] opacity-70">практика</span>
              </Badge>
            ))}
          </div>
        </Card>
      )}

      {d.academicDefinition && (
        <div className="text-xs italic border-l-2 border-(--color-primary) pl-3 text-(--color-fg-muted)">
          {d.academicDefinition}
        </div>
      )}

      <article className="prose prose-sm max-w-none">
        <div data-color-mode="light">
          <MDEditor.Markdown source={d.bodyMd} />
        </div>
      </article>

      {introduces.length > 0 && (
        <Card className="p-3 bg-(--color-bg)">
          <div className="text-xs text-(--color-fg-muted) mb-2 inline-flex items-center gap-1">
            <Sparkles className="size-3" /> В этом уроке вводятся концепции
          </div>
          <div className="flex flex-wrap gap-1.5">
            {introduces.map((c) => (
              <Badge key={c.conceptSlug} tone="neutral">{c.conceptTitle}</Badge>
            ))}
          </div>
        </Card>
      )}

      {d.recallPrompt && (
        <Card className="p-3 border-(--color-primary)/40">
          <div className="text-xs font-bold mb-1.5 inline-flex items-center gap-1">
            <Sparkles className="size-3 text-(--color-primary)" /> Самопроверка
          </div>
          <div className="text-sm">{d.recallPrompt}</div>
          {d.recallAnswer && (
            <details className="mt-2">
              <summary className="text-xs text-(--color-primary) cursor-pointer">показать эталон ответа</summary>
              <div className="text-sm text-(--color-fg-muted) mt-1">{d.recallAnswer}</div>
            </details>
          )}
        </Card>
      )}

      {d.practiceText && (
        <Card className="p-3 border-(--color-warning)/40 bg-(--color-warning-50)/30">
          <div className="text-xs font-bold mb-1.5 inline-flex items-center gap-1">
            <Star className="size-3 text-(--color-warning)" /> Попробуй на симуляторе
          </div>
          <div className="text-sm">{d.practiceText}</div>
          {d.practiceSymbol && (
            <div className="text-xs text-(--color-fg-muted) mt-1">Инструмент: {d.practiceSymbol}</div>
          )}
        </Card>
      )}
    </div>
  );
}

// Чтобы TS не считал импорт неиспользуемым

