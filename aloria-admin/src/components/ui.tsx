import { clsx } from 'clsx';
import type { ButtonHTMLAttributes, HTMLAttributes, InputHTMLAttributes, ReactNode, TextareaHTMLAttributes, SelectHTMLAttributes } from 'react';

export function Card({ className, children, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...props}
      className={clsx('bg-(--color-surface) border border-(--color-border) rounded-2xl shadow-(--shadow-card)', className)}
    >
      {children}
    </div>
  );
}

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant };

export function Button({ variant = 'secondary', className, children, ...props }: ButtonProps) {
  const styles: Record<ButtonVariant, string> = {
    primary: 'bg-(--color-primary) text-white hover:opacity-90 shadow-sm',
    secondary: 'bg-(--color-surface) text-(--color-fg) border border-(--color-border) hover:bg-(--color-bg)',
    ghost: 'text-(--color-fg-muted) hover:bg-(--color-bg)',
    danger: 'bg-(--color-error) text-white hover:opacity-90',
  };
  return (
    <button
      className={clsx(
        'inline-flex items-center gap-1.5 px-3 h-9 rounded-lg text-sm font-semibold transition-all disabled:opacity-50 disabled:cursor-not-allowed',
        styles[variant],
        className
      )}
      {...props}
    >
      {children}
    </button>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={clsx(
        'h-10 px-3 w-full rounded-lg border border-(--color-border) bg-(--color-surface) text-sm',
        'focus:outline-none focus:border-(--color-primary) focus:ring-2 focus:ring-(--color-primary-100)',
        props.className
      )}
    />
  );
}

export function Textarea(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      {...props}
      className={clsx(
        'px-3 py-2 w-full rounded-lg border border-(--color-border) bg-(--color-surface) text-sm',
        'focus:outline-none focus:border-(--color-primary) focus:ring-2 focus:ring-(--color-primary-100)',
        props.className
      )}
    />
  );
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className={clsx(
        'h-10 px-3 w-full rounded-lg border border-(--color-border) bg-(--color-surface) text-sm',
        'focus:outline-none focus:border-(--color-primary) focus:ring-2 focus:ring-(--color-primary-100)',
        props.className
      )}
    />
  );
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-xs font-semibold uppercase tracking-wider text-(--color-fg-muted)">{label}</span>
      {children}
      {hint && <span className="text-xs text-(--color-fg-muted)">{hint}</span>}
    </label>
  );
}

export function Badge({ children, tone = 'neutral' }: { children: ReactNode; tone?: 'neutral' | 'success' | 'warning' | 'error' | 'primary' }) {
  const tones = {
    neutral: 'bg-(--color-bg) text-(--color-fg-muted) border-(--color-border)',
    success: 'bg-[rgba(55,179,138,0.12)] text-(--color-success) border-[rgba(55,179,138,0.32)]',
    warning: 'bg-[rgba(245,194,77,0.16)] text-[#9a7a17] border-[rgba(245,194,77,0.4)]',
    error: 'bg-[rgba(241,107,130,0.12)] text-(--color-error) border-[rgba(241,107,130,0.32)]',
    primary: 'bg-(--color-primary-50) text-(--color-primary) border-[rgba(93,140,255,0.32)]',
  } as const;
  return (
    <span className={clsx('inline-flex items-center px-2 h-6 rounded-md border text-[11px] font-semibold uppercase tracking-wider', tones[tone])}>
      {children}
    </span>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="flex items-end justify-between gap-4 mb-6">
      <div>
        <h1 className="text-2xl font-bold text-(--color-fg)">{title}</h1>
        {subtitle && <p className="text-sm text-(--color-fg-muted) mt-0.5">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <Card className="p-12 text-center">
      <div className="text-base font-semibold text-(--color-fg)">{title}</div>
      {hint && <div className="text-sm text-(--color-fg-muted) mt-1">{hint}</div>}
    </Card>
  );
}

export function Spinner() {
  return (
    <div className="flex justify-center py-12">
      <div className="h-6 w-6 rounded-full border-2 border-(--color-primary) border-t-transparent animate-spin" />
    </div>
  );
}
