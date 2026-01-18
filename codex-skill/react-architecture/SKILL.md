---
name: react-architecture
description: React application architecture with bulletproof patterns
metadata:
  short-description: React architecture patterns
---

# React Architecture (Bulletproof React)

> **Source**: [alan2207/bulletproof-react](https://github.com/alan2207/bulletproof-react) (34k+ stars)
> **Auto-trigger**: `package.json` contains `react` but not `next`, or `.jsx`/`.tsx` files present

---

## 1. Project Structure

### 1.1 Feature-Based Architecture

```
src/
├── app/                    # App-level setup
│   ├── provider.tsx        # All providers wrapped
│   ├── router.tsx          # Route definitions
│   └── main.tsx            # Entry point
│
├── components/             # Shared components
│   ├── ui/                 # Primitives (Button, Input, Modal)
│   ├── layouts/            # Layout components
│   └── errors/             # Error boundaries
│
├── features/               # Feature modules
│   ├── auth/
│   │   ├── api/            # API calls
│   │   ├── components/     # Feature-specific components
│   │   ├── hooks/          # Feature-specific hooks
│   │   ├── stores/         # Feature state (Zustand)
│   │   ├── types/          # Feature types
│   │   └── index.ts        # Public API
│   ├── users/
│   └── dashboard/
│
├── hooks/                  # Shared hooks
├── lib/                    # Configured libraries
│   ├── api-client.ts       # Axios/fetch setup
│   ├── react-query.ts      # Query client
│   └── utils.ts            # Utility functions
│
├── stores/                 # Global state
├── types/                  # Shared types
└── config/                 # App configuration
```

### 1.2 Feature Module Structure

```
features/auth/
├── api/
│   ├── login.ts
│   ├── logout.ts
│   ├── register.ts
│   └── get-user.ts
├── components/
│   ├── login-form.tsx
│   ├── register-form.tsx
│   └── user-menu.tsx
├── hooks/
│   ├── use-auth.ts
│   └── use-user.ts
├── stores/
│   └── auth-store.ts
├── types/
│   └── index.ts
└── index.ts                # Public exports only
```

### 1.3 Barrel Exports (index.ts)

```typescript
// features/auth/index.ts
// Only export what other features need

export { LoginForm } from './components/login-form';
export { RegisterForm } from './components/register-form';
export { useAuth } from './hooks/use-auth';
export { useUser } from './hooks/use-user';
export type { User, LoginCredentials } from './types';

// Internal components stay private
```

---

## 2. Component Patterns

### 2.1 Component Structure

```typescript
// components/ui/button.tsx
import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 px-3',
        lg: 'h-11 px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  isLoading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, isLoading, children, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(buttonVariants({ variant, size, className }))}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading && <Spinner className="mr-2 h-4 w-4" />}
        {children}
      </button>
    );
  }
);

Button.displayName = 'Button';
```

### 2.2 Compound Components

```typescript
// components/ui/card.tsx
import { createContext, useContext, type ReactNode } from 'react';
import { cn } from '@/lib/utils';

const CardContext = createContext<{ variant: 'default' | 'bordered' }>({
  variant: 'default',
});

interface CardProps {
  children: ReactNode;
  variant?: 'default' | 'bordered';
  className?: string;
}

export function Card({ children, variant = 'default', className }: CardProps) {
  return (
    <CardContext.Provider value={{ variant }}>
      <div
        className={cn(
          'rounded-lg bg-card text-card-foreground shadow-sm',
          variant === 'bordered' && 'border',
          className
        )}
      >
        {children}
      </div>
    </CardContext.Provider>
  );
}

Card.Header = function CardHeader({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('flex flex-col space-y-1.5 p-6', className)}>
      {children}
    </div>
  );
};

Card.Title = function CardTitle({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <h3 className={cn('text-2xl font-semibold leading-none tracking-tight', className)}>
      {children}
    </h3>
  );
};

Card.Content = function CardContent({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={cn('p-6 pt-0', className)}>{children}</div>;
};

// Usage
<Card variant="bordered">
  <Card.Header>
    <Card.Title>Settings</Card.Title>
  </Card.Header>
  <Card.Content>
    <p>Your settings content here</p>
  </Card.Content>
</Card>
```

### 2.3 Render Props Pattern

```typescript
// components/data-table.tsx
interface DataTableProps<T> {
  data: T[];
  columns: ColumnDef<T>[];
  renderRow: (item: T, index: number) => ReactNode;
  renderEmpty?: () => ReactNode;
  isLoading?: boolean;
}

export function DataTable<T>({
  data,
  columns,
  renderRow,
  renderEmpty,
  isLoading,
}: DataTableProps<T>) {
  if (isLoading) {
    return <TableSkeleton columns={columns.length} />;
  }

  if (data.length === 0) {
    return renderEmpty?.() ?? <EmptyState />;
  }

  return (
    <table>
      <thead>
        <tr>
          {columns.map((col) => (
            <th key={col.id}>{col.header}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.map((item, index) => renderRow(item, index))}
      </tbody>
    </table>
  );
}
```

---

## 3. State Management

### 3.1 Server State (React Query)

```typescript
// lib/react-query.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 30, // 30 minutes (formerly cacheTime)
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

// features/users/api/get-users.ts
import { useQuery, queryOptions } from '@tanstack/react-query';
import { api } from '@/lib/api-client';
import type { User } from '../types';

export const getUsersQueryOptions = (params?: { page?: number }) => {
  return queryOptions({
    queryKey: ['users', params],
    queryFn: () => api.get<User[]>('/users', { params }),
  });
};

export const useUsers = (params?: { page?: number }) => {
  return useQuery(getUsersQueryOptions(params));
};

// features/users/api/create-user.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api-client';

export const useCreateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateUserDto) => api.post('/users', data),
    onSuccess: () => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
    // Optimistic update
    onMutate: async (newUser) => {
      await queryClient.cancelQueries({ queryKey: ['users'] });
      const previousUsers = queryClient.getQueryData(['users']);

      queryClient.setQueryData(['users'], (old: User[]) => [
        ...old,
        { ...newUser, id: 'temp-id' },
      ]);

      return { previousUsers };
    },
    onError: (err, newUser, context) => {
      queryClient.setQueryData(['users'], context?.previousUsers);
    },
  });
};
```

### 3.2 Client State (Zustand)

```typescript
// stores/ui-store.ts
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface UIState {
  sidebarOpen: boolean;
  theme: 'light' | 'dark' | 'system';
  toggleSidebar: () => void;
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
}

export const useUIStore = create<UIState>()(
  devtools(
    persist(
      (set) => ({
        sidebarOpen: true,
        theme: 'system',
        toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
        setTheme: (theme) => set({ theme }),
      }),
      { name: 'ui-storage' }
    )
  )
);

// features/auth/stores/auth-store.ts
interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  setAuth: (user: User, token: string) => void;
  clearAuth: () => void;
}

export const useAuthStore = create<AuthState>()(
  devtools((set) => ({
    user: null,
    token: null,
    isAuthenticated: false,
    setAuth: (user, token) => set({ user, token, isAuthenticated: true }),
    clearAuth: () => set({ user: null, token: null, isAuthenticated: false }),
  }))
);
```

### 3.3 State Selection (Avoid Re-renders)

```typescript
// BAD - Subscribes to entire store
const { sidebarOpen, theme, toggleSidebar } = useUIStore();

// GOOD - Subscribe only to what you need
const sidebarOpen = useUIStore((state) => state.sidebarOpen);
const toggleSidebar = useUIStore((state) => state.toggleSidebar);

// GOOD - Shallow comparison for multiple values
import { shallow } from 'zustand/shallow';

const { sidebarOpen, theme } = useUIStore(
  (state) => ({ sidebarOpen: state.sidebarOpen, theme: state.theme }),
  shallow
);
```

---

## 4. API Layer

### 4.1 API Client Setup

```typescript
// lib/api-client.ts
import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';
import { useAuthStore } from '@/features/auth/stores/auth-store';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - add auth token
api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor - handle errors
api.interceptors.response.use(
  (response) => response.data,
  (error: AxiosError<{ message: string }>) => {
    const message = error.response?.data?.message || 'An error occurred';

    if (error.response?.status === 401) {
      useAuthStore.getState().clearAuth();
      window.location.href = '/login';
    }

    return Promise.reject(new Error(message));
  }
);
```

### 4.2 Type-Safe API Functions

```typescript
// features/users/api/get-user.ts
import { api } from '@/lib/api-client';
import type { User } from '../types';

export const getUser = async (id: string): Promise<User> => {
  return api.get(`/users/${id}`);
};

// With Zod validation
import { z } from 'zod';

const userSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  name: z.string(),
  role: z.enum(['admin', 'user']),
  createdAt: z.string().datetime(),
});

export const getUserSafe = async (id: string): Promise<User> => {
  const response = await api.get(`/users/${id}`);
  return userSchema.parse(response); // Runtime validation
};
```

---

## 5. Error Handling

### 5.1 Error Boundary

```typescript
// components/errors/error-boundary.tsx
import { Component, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    // Send to error tracking service
  }

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback || (
          <div className="flex flex-col items-center justify-center min-h-[400px]">
            <h2 className="text-xl font-semibold mb-4">Something went wrong</h2>
            <p className="text-muted-foreground mb-4">
              {this.state.error?.message}
            </p>
            <Button onClick={() => window.location.reload()}>
              Refresh Page
            </Button>
          </div>
        )
      );
    }

    return this.props.children;
  }
}
```

### 5.2 Query Error Handling

```typescript
// components/errors/query-error.tsx
import { type UseQueryResult } from '@tanstack/react-query';
import { AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface QueryErrorProps {
  query: UseQueryResult<unknown, Error>;
  retry?: boolean;
}

export function QueryError({ query, retry = true }: QueryErrorProps) {
  if (!query.isError) return null;

  return (
    <div className="flex items-center gap-2 p-4 bg-destructive/10 rounded-lg">
      <AlertCircle className="h-5 w-5 text-destructive" />
      <span className="text-sm">{query.error.message}</span>
      {retry && (
        <Button
          variant="ghost"
          size="sm"
          onClick={() => query.refetch()}
          disabled={query.isFetching}
        >
          Retry
        </Button>
      )}
    </div>
  );
}
```

---

## 6. Performance Patterns

### 6.1 Memoization

```typescript
// Memoize expensive computations
const sortedUsers = useMemo(() => {
  return [...users].sort((a, b) => a.name.localeCompare(b.name));
}, [users]);

// Memoize callbacks passed to children
const handleClick = useCallback((id: string) => {
  setSelectedId(id);
}, []); // Empty deps if no dependencies

// Memoize components that receive objects/arrays
const MemoizedList = memo(function UserList({ users }: { users: User[] }) {
  return users.map((user) => <UserCard key={user.id} user={user} />);
});
```

### 6.2 Code Splitting

```typescript
// Lazy load routes
import { lazy, Suspense } from 'react';

const Dashboard = lazy(() => import('@/features/dashboard'));
const Settings = lazy(() => import('@/features/settings'));

function AppRouter() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}

// Lazy load heavy components
const HeavyChart = lazy(() => import('./heavy-chart'));

function Analytics() {
  return (
    <Suspense fallback={<ChartSkeleton />}>
      <HeavyChart data={data} />
    </Suspense>
  );
}
```

### 6.3 Virtualization

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
    overscan: 5,
  });

  return (
    <div ref={parentRef} className="h-[400px] overflow-auto">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <ItemRow item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## 7. Testing

### 7.1 Component Testing

```typescript
// features/auth/components/__tests__/login-form.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from '../login-form';
import { TestWrapper } from '@/test/utils';

describe('LoginForm', () => {
  it('submits with valid credentials', async () => {
    const onSuccess = vi.fn();
    const user = userEvent.setup();

    render(
      <TestWrapper>
        <LoginForm onSuccess={onSuccess} />
      </TestWrapper>
    );

    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/password/i), 'password123');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalled();
    });
  });

  it('shows validation errors', async () => {
    const user = userEvent.setup();

    render(
      <TestWrapper>
        <LoginForm onSuccess={() => {}} />
      </TestWrapper>
    );

    await user.click(screen.getByRole('button', { name: /sign in/i }));

    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
  });
});
```

### 7.2 Test Utilities

```typescript
// test/utils.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import type { ReactNode } from 'react';

export function TestWrapper({ children }: { children: ReactNode }) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>{children}</BrowserRouter>
    </QueryClientProvider>
  );
}

// Custom render with providers
import { render } from '@testing-library/react';

export function renderWithProviders(ui: ReactNode) {
  return render(<TestWrapper>{ui}</TestWrapper>);
}
```

---

## Quick Reference

### File Naming
- Components: `kebab-case.tsx` (e.g., `user-card.tsx`)
- Hooks: `use-kebab-case.ts` (e.g., `use-auth.ts`)
- Types: `index.ts` or `kebab-case.ts`
- Tests: `*.test.tsx` or `*.test.ts`

### Component Checklist
- [ ] Props interface defined
- [ ] Default props where sensible
- [ ] Proper TypeScript types
- [ ] Error handling
- [ ] Loading states
- [ ] Accessibility (ARIA)
- [ ] Responsive design

### State Decision Tree
```
Is it server data? → React Query
Is it URL state? → URL params/search
Is it form state? → React Hook Form
Is it global UI? → Zustand
Is it local? → useState/useReducer
```

### Anti-Patterns
- Prop drilling more than 2 levels
- Business logic in components
- Direct API calls in components
- Mutating state directly
- Missing error boundaries
- Missing loading states
