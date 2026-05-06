import { BrowserRouter, Navigate, Route, Routes } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Layout } from './components/Layout';
import { SectionsPage } from './routes/SectionsPage';
import { LessonsPage } from './routes/LessonsPage';
import { LessonEditPage } from './routes/LessonEditPage';
import { QuizzesPage } from './routes/QuizzesPage';
import { AchievementsPage } from './routes/AchievementsPage';
import { UsersPage } from './routes/UsersPage';
import { AuditPage } from './routes/AuditPage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 5_000, refetchOnWindowFocus: false },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<Navigate to="/sections" replace />} />
            <Route path="/sections" element={<SectionsPage />} />
            <Route path="/lessons" element={<LessonsPage />} />
            <Route path="/lessons/:id" element={<LessonEditPage />} />
            <Route path="/quizzes" element={<QuizzesPage />} />
            <Route path="/achievements" element={<AchievementsPage />} />
            <Route path="/users" element={<UsersPage />} />
            <Route path="/audit" element={<AuditPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
