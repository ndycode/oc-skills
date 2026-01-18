---
name: forms-validation
description: Form handling with React Hook Form and Zod validation
metadata:
  short-description: Forms and validation
---

# Forms & Validation

> **Sources**: [react-hook-form/react-hook-form](https://github.com/react-hook-form/react-hook-form) (42k⭐), [colinhacks/zod](https://github.com/colinhacks/zod) (35k⭐)
> **Auto-trigger**: Files containing `useForm`, `react-hook-form`, `zod`, `z.object`, `zodResolver`, form elements with validation

---

## Setup

```bash
npm install react-hook-form zod @hookform/resolvers
```

---

## Basic Form with Zod

### Schema Definition
```typescript
// schemas/auth.ts
import { z } from 'zod';

export const loginSchema = z.object({
  email: z
    .string()
    .min(1, 'Email is required')
    .email('Invalid email address'),
  password: z
    .string()
    .min(1, 'Password is required')
    .min(8, 'Password must be at least 8 characters'),
  rememberMe: z.boolean().default(false),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const registerSchema = z
  .object({
    name: z
      .string()
      .min(1, 'Name is required')
      .min(2, 'Name must be at least 2 characters')
      .max(50, 'Name must be less than 50 characters'),
    email: z.string().min(1, 'Email is required').email('Invalid email'),
    password: z
      .string()
      .min(1, 'Password is required')
      .min(8, 'Password must be at least 8 characters')
      .regex(
        /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
        'Password must contain uppercase, lowercase, and number'
      ),
    confirmPassword: z.string().min(1, 'Please confirm your password'),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });

export type RegisterInput = z.infer<typeof registerSchema>;
```

### Form Component
```typescript
// components/LoginForm.tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { loginSchema, type LoginInput } from '@/schemas/auth';

export function LoginForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginInput>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
      rememberMe: false,
    },
  });

  const onSubmit = async (data: LoginInput) => {
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        throw new Error('Login failed');
      }

      // Redirect or update state
    } catch (error) {
      console.error('Login error:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <div>
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          {...register('email')}
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined}
        />
        {errors.email && (
          <span id="email-error" role="alert">
            {errors.email.message}
          </span>
        )}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          {...register('password')}
          aria-invalid={!!errors.password}
        />
        {errors.password && (
          <span role="alert">{errors.password.message}</span>
        )}
      </div>

      <div>
        <label>
          <input type="checkbox" {...register('rememberMe')} />
          Remember me
        </label>
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Signing in...' : 'Sign In'}
      </button>
    </form>
  );
}
```

---

## Advanced Zod Schemas

### Complex Validations
```typescript
// schemas/profile.ts
import { z } from 'zod';

// Phone number with international format
const phoneSchema = z
  .string()
  .regex(/^\+?[1-9]\d{1,14}$/, 'Invalid phone number');

// URL validation
const urlSchema = z
  .string()
  .url('Invalid URL')
  .refine(
    (url) => url.startsWith('https://'),
    'URL must use HTTPS'
  );

// Date validation
const dateOfBirthSchema = z
  .string()
  .refine((date) => !isNaN(Date.parse(date)), 'Invalid date')
  .refine((date) => {
    const age = Math.floor(
      (Date.now() - new Date(date).getTime()) / (365.25 * 24 * 60 * 60 * 1000)
    );
    return age >= 18;
  }, 'Must be at least 18 years old');

// File validation
const fileSchema = z
  .instanceof(File)
  .refine((file) => file.size <= 5 * 1024 * 1024, 'File must be less than 5MB')
  .refine(
    (file) => ['image/jpeg', 'image/png', 'image/webp'].includes(file.type),
    'Only JPEG, PNG, and WebP images are allowed'
  );

// Conditional validation
const profileSchema = z
  .object({
    accountType: z.enum(['personal', 'business']),
    name: z.string().min(1, 'Name is required'),
    // Business fields
    companyName: z.string().optional(),
    taxId: z.string().optional(),
  })
  .refine(
    (data) => {
      if (data.accountType === 'business') {
        return !!data.companyName && !!data.taxId;
      }
      return true;
    },
    {
      message: 'Company name and Tax ID are required for business accounts',
      path: ['companyName'],
    }
  );

// Array validation
const tagsSchema = z
  .array(z.string().min(1).max(20))
  .min(1, 'At least one tag is required')
  .max(5, 'Maximum 5 tags allowed');

// Object with dynamic keys
const settingsSchema = z.record(z.string(), z.boolean());

export const fullProfileSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  phone: phoneSchema.optional(),
  website: urlSchema.optional(),
  dateOfBirth: dateOfBirthSchema,
  avatar: fileSchema.optional(),
  tags: tagsSchema,
  settings: settingsSchema,
});
```

### Transform & Preprocess
```typescript
// schemas/transforms.ts
import { z } from 'zod';

// Trim whitespace
const trimmedString = z.string().trim();

// Transform to lowercase
const emailSchema = z
  .string()
  .email()
  .transform((email) => email.toLowerCase());

// Coerce to number (for form inputs that come as strings)
const priceSchema = z.coerce
  .number()
  .positive('Price must be positive')
  .multipleOf(0.01, 'Price can have at most 2 decimal places');

// Parse JSON string
const jsonSchema = z
  .string()
  .transform((str, ctx) => {
    try {
      return JSON.parse(str);
    } catch {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Invalid JSON',
      });
      return z.NEVER;
    }
  });

// Default values
const optionsSchema = z.object({
  notifications: z.boolean().default(true),
  theme: z.enum(['light', 'dark', 'system']).default('system'),
  language: z.string().default('en'),
});

// Preprocess: clean input before validation
const usernameSchema = z.preprocess(
  (val) => (typeof val === 'string' ? val.trim().toLowerCase() : val),
  z.string().min(3).max(20).regex(/^[a-z0-9_]+$/)
);
```

---

## Multi-Step Forms

```typescript
// components/MultiStepForm.tsx
'use client';

import { useState } from 'react';
import { useForm, FormProvider } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

// Step schemas
const step1Schema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
  email: z.string().email(),
});

const step2Schema = z.object({
  address: z.string().min(1, 'Address is required'),
  city: z.string().min(1, 'City is required'),
  zipCode: z.string().regex(/^\d{5}(-\d{4})?$/, 'Invalid ZIP code'),
});

const step3Schema = z.object({
  cardNumber: z.string().regex(/^\d{16}$/, 'Invalid card number'),
  expiryDate: z.string().regex(/^\d{2}\/\d{2}$/, 'Use MM/YY format'),
  cvv: z.string().regex(/^\d{3,4}$/, 'Invalid CVV'),
});

// Combined schema
const fullSchema = step1Schema.merge(step2Schema).merge(step3Schema);
type FormData = z.infer<typeof fullSchema>;

const stepSchemas = [step1Schema, step2Schema, step3Schema];
const stepFields: (keyof FormData)[][] = [
  ['firstName', 'lastName', 'email'],
  ['address', 'city', 'zipCode'],
  ['cardNumber', 'expiryDate', 'cvv'],
];

export function MultiStepForm() {
  const [step, setStep] = useState(0);

  const methods = useForm<FormData>({
    resolver: zodResolver(fullSchema),
    mode: 'onChange',
    defaultValues: {
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      city: '',
      zipCode: '',
      cardNumber: '',
      expiryDate: '',
      cvv: '',
    },
  });

  const {
    handleSubmit,
    trigger,
    formState: { errors, isSubmitting },
  } = methods;

  const nextStep = async () => {
    // Validate only current step fields
    const fieldsToValidate = stepFields[step];
    const isValid = await trigger(fieldsToValidate);

    if (isValid) {
      setStep((prev) => Math.min(prev + 1, stepSchemas.length - 1));
    }
  };

  const prevStep = () => {
    setStep((prev) => Math.max(prev - 1, 0));
  };

  const onSubmit = async (data: FormData) => {
    console.log('Form submitted:', data);
    // Process payment
  };

  return (
    <FormProvider {...methods}>
      <form onSubmit={handleSubmit(onSubmit)}>
        {/* Progress indicator */}
        <div className="steps">
          {['Personal', 'Address', 'Payment'].map((label, i) => (
            <div
              key={label}
              className={`step ${i === step ? 'active' : ''} ${i < step ? 'completed' : ''}`}
            >
              {label}
            </div>
          ))}
        </div>

        {/* Step content */}
        {step === 0 && <Step1 />}
        {step === 1 && <Step2 />}
        {step === 2 && <Step3 />}

        {/* Navigation */}
        <div className="navigation">
          {step > 0 && (
            <button type="button" onClick={prevStep}>
              Back
            </button>
          )}
          {step < stepSchemas.length - 1 ? (
            <button type="button" onClick={nextStep}>
              Next
            </button>
          ) : (
            <button type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Processing...' : 'Submit'}
            </button>
          )}
        </div>
      </form>
    </FormProvider>
  );
}

// Step components use useFormContext
function Step1() {
  const { register, formState: { errors } } = useFormContext<FormData>();

  return (
    <div>
      <input {...register('firstName')} placeholder="First Name" />
      {errors.firstName && <span>{errors.firstName.message}</span>}

      <input {...register('lastName')} placeholder="Last Name" />
      {errors.lastName && <span>{errors.lastName.message}</span>}

      <input {...register('email')} placeholder="Email" type="email" />
      {errors.email && <span>{errors.email.message}</span>}
    </div>
  );
}
```

---

## File Uploads

```typescript
// components/FileUpload.tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCallback, useState } from 'react';

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

const uploadSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  files: z
    .custom<FileList>()
    .refine((files) => files?.length > 0, 'At least one file is required')
    .refine(
      (files) => Array.from(files).every((file) => file.size <= MAX_FILE_SIZE),
      'Each file must be less than 5MB'
    )
    .refine(
      (files) =>
        Array.from(files).every((file) =>
          ACCEPTED_IMAGE_TYPES.includes(file.type)
        ),
      'Only JPEG, PNG, and WebP images are allowed'
    ),
});

type UploadInput = z.infer<typeof uploadSchema>;

export function FileUploadForm() {
  const [previews, setPreviews] = useState<string[]>([]);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setValue,
    watch,
  } = useForm<UploadInput>({
    resolver: zodResolver(uploadSchema),
  });

  const handleFileChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = e.target.files;
      if (!files) return;

      // Create previews
      const urls = Array.from(files).map((file) => URL.createObjectURL(file));
      setPreviews(urls);
    },
    []
  );

  const onSubmit = async (data: UploadInput) => {
    const formData = new FormData();
    formData.append('title', data.title);
    Array.from(data.files).forEach((file) => {
      formData.append('files', file);
    });

    const response = await fetch('/api/upload', {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error('Upload failed');
    }

    // Cleanup previews
    previews.forEach(URL.revokeObjectURL);
    setPreviews([]);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="title">Title</label>
        <input id="title" {...register('title')} />
        {errors.title && <span>{errors.title.message}</span>}
      </div>

      <div>
        <label htmlFor="files">Images</label>
        <input
          id="files"
          type="file"
          multiple
          accept={ACCEPTED_IMAGE_TYPES.join(',')}
          {...register('files', { onChange: handleFileChange })}
        />
        {errors.files && <span>{errors.files.message}</span>}
      </div>

      {/* Preview grid */}
      {previews.length > 0 && (
        <div className="preview-grid">
          {previews.map((url, i) => (
            <img key={i} src={url} alt={`Preview ${i + 1}`} />
          ))}
        </div>
      )}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Uploading...' : 'Upload'}
      </button>
    </form>
  );
}
```

---

## Dynamic Fields (Arrays)

```typescript
// components/DynamicForm.tsx
'use client';

import { useForm, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const teamMemberSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email'),
  role: z.enum(['admin', 'member', 'viewer']),
});

const teamSchema = z.object({
  teamName: z.string().min(1, 'Team name is required'),
  members: z
    .array(teamMemberSchema)
    .min(1, 'At least one member is required')
    .max(10, 'Maximum 10 members allowed'),
});

type TeamInput = z.infer<typeof teamSchema>;

export function TeamForm() {
  const {
    register,
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<TeamInput>({
    resolver: zodResolver(teamSchema),
    defaultValues: {
      teamName: '',
      members: [{ name: '', email: '', role: 'member' }],
    },
  });

  const { fields, append, remove, move } = useFieldArray({
    control,
    name: 'members',
  });

  const onSubmit = (data: TeamInput) => {
    console.log('Team data:', data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label>Team Name</label>
        <input {...register('teamName')} />
        {errors.teamName && <span>{errors.teamName.message}</span>}
      </div>

      <div>
        <h3>Members</h3>
        {errors.members?.root && (
          <span>{errors.members.root.message}</span>
        )}

        {fields.map((field, index) => (
          <div key={field.id} className="member-row">
            <input
              {...register(`members.${index}.name`)}
              placeholder="Name"
            />
            {errors.members?.[index]?.name && (
              <span>{errors.members[index]?.name?.message}</span>
            )}

            <input
              {...register(`members.${index}.email`)}
              placeholder="Email"
              type="email"
            />
            {errors.members?.[index]?.email && (
              <span>{errors.members[index]?.email?.message}</span>
            )}

            <select {...register(`members.${index}.role`)}>
              <option value="admin">Admin</option>
              <option value="member">Member</option>
              <option value="viewer">Viewer</option>
            </select>

            <button
              type="button"
              onClick={() => remove(index)}
              disabled={fields.length === 1}
            >
              Remove
            </button>

            {index > 0 && (
              <button type="button" onClick={() => move(index, index - 1)}>
                ↑
              </button>
            )}
            {index < fields.length - 1 && (
              <button type="button" onClick={() => move(index, index + 1)}>
                ↓
              </button>
            )}
          </div>
        ))}

        <button
          type="button"
          onClick={() => append({ name: '', email: '', role: 'member' })}
          disabled={fields.length >= 10}
        >
          Add Member
        </button>
      </div>

      <button type="submit">Save Team</button>
    </form>
  );
}
```

---

## Server-Side Validation

```typescript
// app/api/contact/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

const contactSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  message: z.string().min(10).max(1000),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    // Validate with Zod
    const result = contactSchema.safeParse(body);

    if (!result.success) {
      // Return field-level errors
      const fieldErrors = result.error.flatten().fieldErrors;
      return NextResponse.json(
        { errors: fieldErrors },
        { status: 400 }
      );
    }

    // Process validated data
    const { name, email, message } = result.data;

    // ... send email, save to DB, etc.

    return NextResponse.json({ success: true });
  } catch (error) {
    return NextResponse.json(
      { error: 'Invalid request' },
      { status: 400 }
    );
  }
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Validate only on client
const onSubmit = (data) => {
  // Trusting client data without server validation!
  await db.user.create({ data });
};

// ✅ CORRECT: Always validate on server too
const result = schema.safeParse(data);
if (!result.success) return { error: result.error };

// ❌ NEVER: Use any/unknown without validation
const data = await req.json() as UserInput; // No runtime validation!

// ✅ CORRECT: Parse and validate
const data = userSchema.parse(await req.json());

// ❌ NEVER: Suppress errors with try-catch
try {
  schema.parse(data);
} catch {
  // Silently ignore validation errors
}

// ✅ CORRECT: Handle errors explicitly
const result = schema.safeParse(data);
if (!result.success) {
  return { errors: result.error.flatten() };
}

// ❌ NEVER: Mutate form state directly
form.values.email = 'new@email.com';

// ✅ CORRECT: Use setValue
setValue('email', 'new@email.com');
```

---

## Quick Reference

### React Hook Form Methods
| Method | Purpose |
|--------|---------|
| `register` | Connect input to form |
| `handleSubmit` | Wrap submit handler |
| `setValue` | Programmatically set value |
| `getValues` | Get current values |
| `reset` | Reset form to defaults |
| `trigger` | Trigger validation |
| `watch` | Subscribe to value changes |
| `setError` | Set custom error |
| `clearErrors` | Clear errors |

### Zod Methods
| Method | Purpose |
|--------|---------|
| `.parse()` | Validate, throw on error |
| `.safeParse()` | Validate, return result object |
| `.refine()` | Custom validation |
| `.transform()` | Transform after validation |
| `.default()` | Set default value |
| `.optional()` | Make optional |
| `.nullable()` | Allow null |
| `.coerce` | Coerce to type |

### Form States
| State | Meaning |
|-------|---------|
| `isSubmitting` | Form is being submitted |
| `isValid` | All fields valid |
| `isDirty` | Any field changed |
| `isLoading` | Async validation in progress |
| `errors` | Validation errors object |

### Checklist
- [ ] Zod schema for every form
- [ ] Server-side validation mirrors client
- [ ] Error messages are user-friendly
- [ ] Accessible: labels, aria-invalid, aria-describedby
- [ ] Loading states during submission
- [ ] File size/type validation
- [ ] noValidate on form (use Zod, not browser)
