# Vue 3 Modern Patterns

> **Sources**: 
> - [vueuse/vueuse](https://github.com/vueuse/vueuse) (22k+ stars)
> - [antfu/vitesse](https://github.com/antfu/vitesse) (9k+ stars)
> - [vuejs/pinia](https://github.com/vuejs/pinia) (14k+ stars)
> 
> **Auto-trigger**: `.vue` files, `vite.config.ts` with Vue, `nuxt.config.ts`

---

## 1. Project Structure (Vitesse-Style)

```
src/
├── components/              # Shared components
│   ├── ui/                  # Base UI components
│   └── common/              # Common components
│
├── composables/             # Shared composables
│   ├── useAuth.ts
│   └── useDarkMode.ts
│
├── layouts/                 # Layout components
│   ├── default.vue
│   └── auth.vue
│
├── pages/                   # File-based routing
│   ├── index.vue            # /
│   ├── about.vue            # /about
│   └── users/
│       ├── index.vue        # /users
│       └── [id].vue         # /users/:id
│
├── stores/                  # Pinia stores
│   ├── user.ts
│   └── app.ts
│
├── types/                   # TypeScript types
│   └── index.ts
│
├── utils/                   # Utility functions
│   └── format.ts
│
├── App.vue
└── main.ts
```

---

## 2. Component Patterns

### 2.1 Script Setup (Standard)

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import type { User } from '@/types';

// Props
interface Props {
  userId: string;
  showDetails?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  showDetails: false,
});

// Emits
interface Emits {
  (e: 'select', user: User): void;
  (e: 'delete', id: string): void;
}

const emit = defineEmits<Emits>();

// State
const user = ref<User | null>(null);
const isLoading = ref(true);

// Computed
const fullName = computed(() => {
  return user.value ? `${user.value.firstName} ${user.value.lastName}` : '';
});

// Methods
async function loadUser() {
  isLoading.value = true;
  try {
    user.value = await fetchUser(props.userId);
  } finally {
    isLoading.value = false;
  }
}

function handleSelect() {
  if (user.value) {
    emit('select', user.value);
  }
}

// Lifecycle
onMounted(() => {
  loadUser();
});

// Expose to parent (if needed)
defineExpose({
  refresh: loadUser,
});
</script>

<template>
  <div v-if="isLoading">Loading...</div>
  <div v-else-if="user">
    <h2>{{ fullName }}</h2>
    <p v-if="showDetails">{{ user.email }}</p>
    <button @click="handleSelect">Select</button>
  </div>
</template>
```

### 2.2 Slots & Scoped Slots

```vue
<!-- BaseCard.vue -->
<script setup lang="ts">
interface Props {
  title?: string;
}

defineProps<Props>();
</script>

<template>
  <div class="card">
    <header v-if="$slots.header || title">
      <slot name="header">
        <h3>{{ title }}</h3>
      </slot>
    </header>
    
    <main>
      <slot />
    </main>
    
    <footer v-if="$slots.footer">
      <slot name="footer" />
    </footer>
  </div>
</template>

<!-- DataList.vue with scoped slots -->
<script setup lang="ts" generic="T">
interface Props {
  items: T[];
  loading?: boolean;
}

defineProps<Props>();
</script>

<template>
  <div v-if="loading">Loading...</div>
  <ul v-else-if="items.length">
    <li v-for="(item, index) in items" :key="index">
      <slot name="item" :item="item" :index="index">
        {{ item }}
      </slot>
    </li>
  </ul>
  <slot v-else name="empty">
    <p>No items found</p>
  </slot>
</template>

<!-- Usage -->
<DataList :items="users">
  <template #item="{ item: user }">
    <UserCard :user="user" />
  </template>
  <template #empty>
    <EmptyState message="No users found" />
  </template>
</DataList>
```

### 2.3 v-model Pattern

```vue
<!-- SearchInput.vue -->
<script setup lang="ts">
const model = defineModel<string>({ default: '' });

// With validation/transform
const model = defineModel<string>({
  get(value) {
    return value?.trim() ?? '';
  },
  set(value) {
    return value.toLowerCase();
  },
});
</script>

<template>
  <input v-model="model" type="text" placeholder="Search..." />
</template>

<!-- Multiple v-models -->
<script setup lang="ts">
const firstName = defineModel<string>('firstName');
const lastName = defineModel<string>('lastName');
</script>

<!-- Usage -->
<NameInput v-model:firstName="first" v-model:lastName="last" />
```

---

## 3. Composables (VueUse Patterns)

### 3.1 Basic Composable

```typescript
// composables/useCounter.ts
import { ref, computed } from 'vue';

export function useCounter(initial = 0) {
  const count = ref(initial);

  const doubled = computed(() => count.value * 2);

  function increment() {
    count.value++;
  }

  function decrement() {
    count.value--;
  }

  function reset() {
    count.value = initial;
  }

  return {
    count,
    doubled,
    increment,
    decrement,
    reset,
  };
}
```

### 3.2 Async Composable

```typescript
// composables/useFetch.ts
import { ref, shallowRef, watchEffect, toValue, type MaybeRefOrGetter } from 'vue';

interface UseFetchOptions {
  immediate?: boolean;
  refetch?: boolean;
}

export function useFetch<T>(
  url: MaybeRefOrGetter<string>,
  options: UseFetchOptions = {}
) {
  const { immediate = true, refetch = true } = options;

  const data = shallowRef<T | null>(null);
  const error = shallowRef<Error | null>(null);
  const isLoading = ref(false);

  async function execute() {
    isLoading.value = true;
    error.value = null;

    try {
      const response = await fetch(toValue(url));
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      data.value = await response.json();
    } catch (e) {
      error.value = e as Error;
    } finally {
      isLoading.value = false;
    }
  }

  if (refetch) {
    watchEffect(() => {
      toValue(url); // Track reactive URL
      execute();
    });
  } else if (immediate) {
    execute();
  }

  return {
    data,
    error,
    isLoading,
    execute,
  };
}

// Usage
const { data: users, isLoading } = useFetch<User[]>('/api/users');

// With reactive URL
const userId = ref('123');
const { data: user } = useFetch(() => `/api/users/${userId.value}`);
```

### 3.3 Composable with Cleanup

```typescript
// composables/useEventListener.ts
import { onMounted, onUnmounted, toValue, type MaybeRefOrGetter } from 'vue';

export function useEventListener<K extends keyof WindowEventMap>(
  target: MaybeRefOrGetter<EventTarget | null>,
  event: K,
  callback: (event: WindowEventMap[K]) => void
) {
  let cleanup: (() => void) | undefined;

  function register() {
    cleanup?.();
    const el = toValue(target);
    if (!el) return;

    el.addEventListener(event, callback as EventListener);
    cleanup = () => el.removeEventListener(event, callback as EventListener);
  }

  onMounted(register);
  onUnmounted(() => cleanup?.());

  return { register };
}

// Usage
useEventListener(window, 'resize', (e) => {
  console.log('Window resized');
});
```

### 3.4 VueUse Common Patterns

```typescript
import {
  useDark,
  useToggle,
  useLocalStorage,
  useMediaQuery,
  useDebounceFn,
  useThrottleFn,
  onClickOutside,
  useIntersectionObserver,
} from '@vueuse/core';

// Dark mode
const isDark = useDark();
const toggleDark = useToggle(isDark);

// Local storage with reactive sync
const token = useLocalStorage<string | null>('auth-token', null);

// Media queries
const isLargeScreen = useMediaQuery('(min-width: 1024px)');

// Debounced function
const debouncedSearch = useDebounceFn((query: string) => {
  searchUsers(query);
}, 300);

// Click outside
const target = ref<HTMLElement | null>(null);
onClickOutside(target, () => {
  isOpen.value = false;
});

// Intersection observer
const { stop } = useIntersectionObserver(
  target,
  ([{ isIntersecting }]) => {
    if (isIntersecting) {
      loadMore();
    }
  }
);
```

---

## 4. Pinia State Management

### 4.1 Setup Store (Recommended)

```typescript
// stores/user.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { User } from '@/types';

export const useUserStore = defineStore('user', () => {
  // State
  const user = ref<User | null>(null);
  const token = ref<string | null>(null);

  // Getters
  const isAuthenticated = computed(() => !!token.value);
  const fullName = computed(() =>
    user.value ? `${user.value.firstName} ${user.value.lastName}` : ''
  );

  // Actions
  async function login(email: string, password: string) {
    const response = await authApi.login(email, password);
    token.value = response.token;
    user.value = response.user;
  }

  async function logout() {
    await authApi.logout();
    token.value = null;
    user.value = null;
  }

  async function fetchUser() {
    if (!token.value) return;
    user.value = await userApi.getProfile();
  }

  return {
    // State
    user,
    token,
    // Getters
    isAuthenticated,
    fullName,
    // Actions
    login,
    logout,
    fetchUser,
  };
});
```

### 4.2 Store with Persistence

```typescript
// stores/settings.ts
import { defineStore } from 'pinia';
import { ref, watch } from 'vue';

export const useSettingsStore = defineStore('settings', () => {
  const theme = ref<'light' | 'dark' | 'system'>('system');
  const locale = ref('en');
  const sidebarOpen = ref(true);

  // Hydrate from localStorage
  function hydrate() {
    const saved = localStorage.getItem('settings');
    if (saved) {
      const parsed = JSON.parse(saved);
      theme.value = parsed.theme ?? 'system';
      locale.value = parsed.locale ?? 'en';
      sidebarOpen.value = parsed.sidebarOpen ?? true;
    }
  }

  // Persist to localStorage
  watch(
    [theme, locale, sidebarOpen],
    () => {
      localStorage.setItem(
        'settings',
        JSON.stringify({
          theme: theme.value,
          locale: locale.value,
          sidebarOpen: sidebarOpen.value,
        })
      );
    },
    { deep: true }
  );

  return {
    theme,
    locale,
    sidebarOpen,
    hydrate,
  };
});

// Or use pinia-plugin-persistedstate
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate';

const pinia = createPinia();
pinia.use(piniaPluginPersistedstate);
```

### 4.3 Store Composition

```typescript
// stores/cart.ts
import { useUserStore } from './user';
import { useProductStore } from './product';

export const useCartStore = defineStore('cart', () => {
  const userStore = useUserStore();
  const productStore = useProductStore();

  const items = ref<CartItem[]>([]);

  const total = computed(() =>
    items.value.reduce((sum, item) => {
      const product = productStore.getById(item.productId);
      return sum + (product?.price ?? 0) * item.quantity;
    }, 0)
  );

  async function checkout() {
    if (!userStore.isAuthenticated) {
      throw new Error('Must be logged in');
    }
    await orderApi.create({
      userId: userStore.user!.id,
      items: items.value,
    });
    items.value = [];
  }

  return { items, total, checkout };
});
```

---

## 5. Performance Patterns

### 5.1 Shallow Refs for Large Data

```typescript
import { shallowRef, triggerRef } from 'vue';

// For large arrays/objects that don't need deep reactivity
const users = shallowRef<User[]>([]);

// Must manually trigger updates
function addUser(user: User) {
  users.value.push(user);
  triggerRef(users); // Trigger update
}

// Or replace the entire array
function setUsers(newUsers: User[]) {
  users.value = newUsers; // Automatically triggers
}
```

### 5.2 Computed with Getter/Setter

```typescript
const firstName = ref('John');
const lastName = ref('Doe');

const fullName = computed({
  get() {
    return `${firstName.value} ${lastName.value}`;
  },
  set(value: string) {
    const [first, ...rest] = value.split(' ');
    firstName.value = first;
    lastName.value = rest.join(' ');
  },
});

fullName.value = 'Jane Smith'; // Updates both refs
```

### 5.3 Lazy Components

```typescript
import { defineAsyncComponent } from 'vue';

const HeavyChart = defineAsyncComponent(() =>
  import('@/components/HeavyChart.vue')
);

// With loading/error states
const HeavyChart = defineAsyncComponent({
  loader: () => import('@/components/HeavyChart.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorDisplay,
  delay: 200,
  timeout: 10000,
});
```

### 5.4 Virtual Lists

```vue
<script setup lang="ts">
import { useVirtualList } from '@vueuse/core';

const items = ref(Array.from({ length: 10000 }, (_, i) => ({
  id: i,
  name: `Item ${i}`,
})));

const { list, containerProps, wrapperProps } = useVirtualList(items, {
  itemHeight: 50,
  overscan: 10,
});
</script>

<template>
  <div v-bind="containerProps" class="h-[400px] overflow-auto">
    <div v-bind="wrapperProps">
      <div v-for="{ data, index } in list" :key="index" class="h-[50px]">
        {{ data.name }}
      </div>
    </div>
  </div>
</template>
```

---

## 6. TypeScript Patterns

### 6.1 Component Props/Emits

```typescript
// Complex props with defaults
interface Props {
  modelValue: string;
  items: Item[];
  disabled?: boolean;
  size?: 'sm' | 'md' | 'lg';
  validate?: (value: string) => boolean;
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  size: 'md',
  validate: () => true,
});

// Typed emits
interface Emits {
  (e: 'update:modelValue', value: string): void;
  (e: 'select', item: Item): void;
  (e: 'validate', result: { valid: boolean; errors: string[] }): void;
}

const emit = defineEmits<Emits>();
```

### 6.2 Generic Components

```vue
<script setup lang="ts" generic="T extends { id: string | number }">
interface Props {
  items: T[];
  selected?: T;
}

interface Emits {
  (e: 'select', item: T): void;
}

defineProps<Props>();
defineEmits<Emits>();
</script>

<template>
  <ul>
    <li
      v-for="item in items"
      :key="item.id"
      :class="{ selected: item.id === selected?.id }"
      @click="$emit('select', item)"
    >
      <slot :item="item">{{ item }}</slot>
    </li>
  </ul>
</template>
```

### 6.3 Typed Provide/Inject

```typescript
// types/injection.ts
import type { InjectionKey } from 'vue';

export interface ThemeContext {
  theme: Ref<'light' | 'dark'>;
  toggleTheme: () => void;
}

export const ThemeKey: InjectionKey<ThemeContext> = Symbol('theme');

// Parent component
import { ThemeKey } from '@/types/injection';

const theme = ref<'light' | 'dark'>('light');
const toggleTheme = () => {
  theme.value = theme.value === 'light' ? 'dark' : 'light';
};

provide(ThemeKey, { theme, toggleTheme });

// Child component
const themeContext = inject(ThemeKey);
if (!themeContext) {
  throw new Error('ThemeKey not provided');
}
const { theme, toggleTheme } = themeContext;
```

---

## Quick Reference

### Script Setup Imports
```typescript
import {
  ref,           // Reactive primitive
  reactive,      // Reactive object
  computed,      // Derived value
  watch,         // Watch changes
  watchEffect,   // Auto-track dependencies
  onMounted,     // Lifecycle
  onUnmounted,
  toRef,         // Single prop to ref
  toRefs,        // All props to refs
  toValue,       // Unwrap ref/getter
  shallowRef,    // Shallow reactivity
} from 'vue';
```

### Reactivity Rules
- Use `ref` for primitives
- Use `reactive` for objects (or `ref` for both)
- Use `shallowRef` for large data
- Use `computed` for derived state
- Don't destructure reactive objects (use `toRefs`)

### Composable Conventions
- Name: `use{Feature}`
- Return object with state and methods
- Handle cleanup with `onUnmounted`
- Accept `MaybeRefOrGetter` for flexibility

### Pinia Conventions
- Store name: `use{Domain}Store`
- One store per domain
- Use setup stores for better TypeScript
- Actions can be async
