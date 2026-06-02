export type AdminSection = {
  id: string;
  slug: string;
  title: string;
  description: string;
  order: number;
  prerequisiteSectionId: string | null;
  lessonCount: number;
  createdAt: string;
  updatedAt: string;
  // r11 spiral
  kind: string;
  isOptional: boolean;
  iconName: string | null;
  tint: string | null;
  goal: string | null;
  targetMinutes: number | null;
  practiceCount: number;
};

export type AdminSectionInput = {
  slug: string;
  title: string;
  description: string;
  order: number;
  prerequisiteSectionId: string | null;
  kind: string | null;
  isOptional: boolean | null;
  iconName: string | null;
  tint: string | null;
  goal: string | null;
  targetMinutes: number | null;
};

export type AdminLessonListItem = {
  id: string;
  sectionId: string;
  slug: string;
  title: string;
  description: string;
  estimatedMinutes: number | null;
  order: number;
  version: number;
  hasQuiz: boolean;
  updatedAt: string;
  // r11 spiral
  isCapstone: boolean;
  roleHint: string | null;
  practiceRequirementCode: string | null;
  conceptCount: number;
};

export type AdminLesson = {
  id: string;
  sectionId: string;
  slug: string;
  title: string;
  description: string;
  bodyMd: string;
  imageUrl: string | null;
  estimatedMinutes: number | null;
  academicDefinition: string | null;
  order: number;
  version: number;
  quiz: AdminQuiz | null;
  // r11 spiral
  isCapstone: boolean;
  roleHint: string | null;
  practiceRequirementCode: string | null;
  group: string | null;
  recallPrompt: string | null;
  recallAnswer: string | null;
  practiceText: string | null;
  practiceSymbol: string | null;
  concepts: AdminLessonConcept[];
};

export type AdminLessonInput = {
  sectionId: string;
  slug: string;
  title: string;
  description: string;
  bodyMd: string;
  imageUrl: string | null;
  estimatedMinutes: number | null;
  academicDefinition: string | null;
  order: number;
  isCapstone: boolean | null;
  roleHint: string | null;
  practiceRequirementCode: string | null;
  group: string | null;
  recallPrompt: string | null;
  recallAnswer: string | null;
  practiceText: string | null;
  practiceSymbol: string | null;
};

export type AdminConcept = {
  id: string;
  slug: string;
  title: string;
  shortDefinition: string;
  iconName: string | null;
  order: number;
  lessonsCount: number;
  createdAt: string;
  updatedAt: string;
};

export type AdminConceptInput = {
  slug: string;
  title: string;
  shortDefinition: string;
  iconName: string | null;
  order: number;
};

export type AdminLessonConcept = {
  conceptSlug: string;
  conceptTitle: string;
  role: 'Introduce' | 'Deepen' | 'Apply';
  depth: number;
};

export type AdminLessonConceptsInput = {
  introduces: string[];
  deepens: string[];
  applies: string[];
};

export type AdminPracticeRequirement = {
  id: string;
  sectionId: string;
  code: string;
  title: string;
  description: string;
  kind: string;
  paramsJson: string;
  order: number;
  isOptional: boolean;
  rewardBuyingPower: number;
  conceptSlugsJson: string;
  archived: boolean;
  updatedAt: string;
};

export type AdminPracticeRequirementInput = {
  code: string;
  title: string;
  description: string;
  kind: string;
  paramsJson: string;
  order: number;
  isOptional: boolean;
  rewardBuyingPower: number;
  conceptSlugsJson: string;
};

export const PRACTICE_KINDS = [
  'OpenPosition',
  'HoldUntilEvent',
  'PlaceLimitOrder',
  'CancelOrder',
  'ClosePosition',
  'ReachBuyingPower',
  'Custom',
] as const;

export const CONCEPT_ROLE_LABELS: Record<AdminLessonConcept['role'], string> = {
  Introduce: 'вводит',
  Deepen: 'углубляет',
  Apply: 'применяет',
};

export type AdminQuiz = {
  id: string;
  lessonId: string | null;
  slug: string;
  title: string;
  description: string;
  rewardXp: number;
  rewardBuyingPower: number;
  questions: AdminQuizQuestion[];
};

export type AdminQuizInput = {
  lessonId: string | null;
  slug: string;
  title: string;
  description: string;
  rewardXp: number;
  rewardBuyingPower: number;
  questions: AdminQuizQuestionInput[];
};

export type AdminQuizQuestion = {
  id: string;
  text: string;
  allowsMultiple: boolean;
  order: number;
  options: AdminQuizOption[];
};

export type AdminQuizQuestionInput = {
  id?: string;
  text: string;
  allowsMultiple: boolean;
  order: number;
  options: AdminQuizOptionInput[];
};

export type AdminQuizOption = {
  id: string;
  text: string;
  isCorrect: boolean;
  explanation: string | null;
  order: number;
};

export type AdminQuizOptionInput = {
  id?: string;
  text: string;
  isCorrect: boolean;
  explanation: string | null;
  order: number;
};

export const ACHIEVEMENT_CONDITIONS = [
  { value: 1, label: 'Уроков пройдено', usesThreshold: true },
  { value: 2, label: 'Тестов сдано', usesThreshold: true },
  { value: 3, label: 'Дней серии', usesThreshold: true },
  { value: 4, label: 'Открыта первая позиция', usesThreshold: false },
  { value: 5, label: 'Набрано XP', usesThreshold: true },
] as const;

export type AdminAchievement = {
  id: string;
  code: string;
  title: string;
  description: string;
  iconName: string;
  condition: number;
  conditionThreshold: number;
  conditionArg: string | null;
  rewardXp: number;
  rewardBuyingPower: number;
  order: number;
  updatedAt: string;
};

export type AdminAchievementInput = Omit<AdminAchievement, 'id' | 'updatedAt'>;

export type AdminUserListItem = {
  id: string;
  alorPortfolioId: string;
  displayName: string | null;
  xp: number;
  level: number;
  streakDays: number;
  lessonsCompleted: number;
  quizzesPassed: number;
  bonusBuyingPower: number;
  createdAt: string;
};

export type AdminUserDetail = {
  user: AdminUserListItem;
  grants: { id: string; amount: number; reason: string; status: string; createdAt: string; committedAt: string | null }[];
  attempts: { id: string; quizId: string; quizTitle: string; isPassed: boolean; awardedXp: number; awardedBuyingPower: number; attemptedAt: string }[];
  achievements: { achievementId: string; code: string; title: string; unlockedAt: string }[];
};

export type AdminPushInput = {
  title: string;
  body: string;
  route: string | null;
};

/// Итог рассылки с бэка: устройств в цели, ушло, погашено мёртвых токенов.
export type PushDispatchOutcome = {
  targeted: number;
  sent: number;
  disabled: number;
};

export type AdminAuditEntry = {
  id: string;
  actor: string;
  action: string;
  entityType: string;
  entityId: string | null;
  details: string | null;
  createdAt: string;
};
