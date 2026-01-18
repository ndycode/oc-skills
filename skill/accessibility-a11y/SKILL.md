# Accessibility (a11y) Best Practices

> **Source**: WCAG 2.2 Guidelines
> **Auto-trigger**: UI components, forms, interactive elements

---

## 1. WCAG 2.2 Principles (POUR)

| Principle | Meaning |
|-----------|---------|
| **Perceivable** | Users can perceive content (alt text, captions) |
| **Operable** | Users can interact (keyboard, timing) |
| **Understandable** | Content is clear (labels, errors) |
| **Robust** | Works with assistive tech (semantic HTML) |

---

## 2. Semantic HTML

### 2.1 Landmarks

```html
<header>         <!-- Banner landmark -->
  <nav>          <!-- Navigation landmark -->
</header>

<main>           <!-- Main landmark (one per page) -->
  <article>      <!-- Self-contained content -->
  <section>      <!-- Thematic grouping -->
  <aside>        <!-- Complementary content -->
</main>

<footer>         <!-- Contentinfo landmark -->
```

### 2.2 Headings Hierarchy

```html
<!-- GOOD - Logical hierarchy -->
<h1>Page Title</h1>
  <h2>Section</h2>
    <h3>Subsection</h3>
  <h2>Another Section</h2>

<!-- BAD - Skipping levels -->
<h1>Page Title</h1>
  <h4>Subsection</h4>  <!-- Skipped h2, h3 -->
```

### 2.3 Lists

```html
<!-- Navigation -->
<nav aria-label="Main">
  <ul>
    <li><a href="/">Home</a></li>
    <li><a href="/about">About</a></li>
  </ul>
</nav>

<!-- Breadcrumbs -->
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Home</a></li>
    <li><a href="/products">Products</a></li>
    <li aria-current="page">Widget</li>
  </ol>
</nav>
```

---

## 3. Interactive Elements

### 3.1 Buttons vs Links

```tsx
// Button - performs an action
<button onClick={handleSubmit}>Submit</button>

// Link - navigates to a new page/location
<a href="/dashboard">Go to Dashboard</a>

// BAD - div as button
<div onClick={handleClick}>Click me</div>

// If you must use div (rare), add these:
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleClick();
    }
  }}
>
  Click me
</div>
```

### 3.2 Focus Management

```tsx
// Visible focus styles
button:focus-visible {
  outline: 2px solid var(--focus-color);
  outline-offset: 2px;
}

// Focus trap for modals
function Modal({ isOpen, onClose, children }) {
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isOpen) return;

    const focusableElements = modalRef.current?.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstElement = focusableElements?.[0] as HTMLElement;
    const lastElement = focusableElements?.[focusableElements.length - 1] as HTMLElement;

    firstElement?.focus();

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Tab') {
        if (e.shiftKey && document.activeElement === firstElement) {
          e.preventDefault();
          lastElement?.focus();
        } else if (!e.shiftKey && document.activeElement === lastElement) {
          e.preventDefault();
          firstElement?.focus();
        }
      }
      if (e.key === 'Escape') {
        onClose();
      }
    }

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div role="dialog" aria-modal="true" ref={modalRef}>
      {children}
    </div>
  );
}
```

### 3.3 Skip Links

```tsx
// First element in body
<a href="#main-content" className="skip-link">
  Skip to main content
</a>

// Styles
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  padding: 8px;
  z-index: 100;
}

.skip-link:focus {
  top: 0;
}

// Target
<main id="main-content" tabIndex={-1}>
```

---

## 4. Forms

### 4.1 Labels

```tsx
// Explicit label (preferred)
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// Implicit label
<label>
  Email
  <input type="email" />
</label>

// Hidden label (for icon buttons)
<label htmlFor="search" className="sr-only">Search</label>
<input id="search" type="search" placeholder="Search..." />
```

### 4.2 Error Messages

```tsx
<div>
  <label htmlFor="email">Email</label>
  <input
    id="email"
    type="email"
    aria-invalid={!!errors.email}
    aria-describedby={errors.email ? 'email-error' : undefined}
  />
  {errors.email && (
    <span id="email-error" role="alert">
      {errors.email}
    </span>
  )}
</div>
```

### 4.3 Required Fields

```tsx
<label htmlFor="name">
  Name
  <span aria-hidden="true">*</span>
  <span className="sr-only">(required)</span>
</label>
<input id="name" required aria-required="true" />
```

### 4.4 Form Groups

```tsx
<fieldset>
  <legend>Shipping Address</legend>
  
  <label htmlFor="street">Street</label>
  <input id="street" />
  
  <label htmlFor="city">City</label>
  <input id="city" />
</fieldset>
```

---

## 5. ARIA Patterns

### 5.1 Common ARIA Attributes

```tsx
// Labeling
aria-label="Close menu"              // Invisible label
aria-labelledby="heading-id"         // Reference visible label
aria-describedby="help-text-id"      // Additional description

// State
aria-expanded="false"                // Expandable content
aria-selected="true"                 // Selected item
aria-checked="true"                  // Checkbox/radio
aria-pressed="true"                  // Toggle button
aria-disabled="true"                 // Disabled (with visual)
aria-hidden="true"                   // Hide from AT
aria-current="page"                  // Current item

// Live regions
aria-live="polite"                   // Announce when convenient
aria-live="assertive"                // Announce immediately
aria-atomic="true"                   // Announce entire region
```

### 5.2 Dropdown Menu

```tsx
function Dropdown() {
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const menuRef = useRef<HTMLUListElement>(null);

  const handleKeyDown = (e: KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setActiveIndex((i) => Math.min(i + 1, items.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIndex((i) => Math.max(i - 1, 0));
        break;
      case 'Enter':
      case ' ':
        e.preventDefault();
        selectItem(activeIndex);
        break;
      case 'Escape':
        setIsOpen(false);
        break;
    }
  };

  return (
    <div>
      <button
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        onClick={() => setIsOpen(!isOpen)}
      >
        Select option
      </button>
      
      {isOpen && (
        <ul
          role="listbox"
          ref={menuRef}
          onKeyDown={handleKeyDown}
          tabIndex={-1}
        >
          {items.map((item, index) => (
            <li
              key={item.id}
              role="option"
              aria-selected={index === activeIndex}
              onClick={() => selectItem(index)}
            >
              {item.label}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

### 5.3 Tabs

```tsx
function Tabs({ tabs }) {
  const [activeTab, setActiveTab] = useState(0);

  return (
    <div>
      <div role="tablist" aria-label="Content tabs">
        {tabs.map((tab, index) => (
          <button
            key={tab.id}
            role="tab"
            id={`tab-${tab.id}`}
            aria-selected={index === activeTab}
            aria-controls={`panel-${tab.id}`}
            tabIndex={index === activeTab ? 0 : -1}
            onClick={() => setActiveTab(index)}
            onKeyDown={(e) => {
              if (e.key === 'ArrowRight') {
                setActiveTab((i) => (i + 1) % tabs.length);
              } else if (e.key === 'ArrowLeft') {
                setActiveTab((i) => (i - 1 + tabs.length) % tabs.length);
              }
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>
      
      {tabs.map((tab, index) => (
        <div
          key={tab.id}
          role="tabpanel"
          id={`panel-${tab.id}`}
          aria-labelledby={`tab-${tab.id}`}
          hidden={index !== activeTab}
          tabIndex={0}
        >
          {tab.content}
        </div>
      ))}
    </div>
  );
}
```

### 5.4 Live Regions

```tsx
// Announce dynamic content changes
function Notification({ message }) {
  return (
    <div
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      {message}
    </div>
  );
}

// Urgent announcements
function Alert({ error }) {
  return (
    <div
      role="alert"
      aria-live="assertive"
    >
      {error}
    </div>
  );
}
```

---

## 6. Images & Media

### 6.1 Alt Text

```tsx
// Informative image
<img src="/chart.png" alt="Sales increased 25% in Q4 2024" />

// Decorative image
<img src="/decoration.png" alt="" role="presentation" />

// Complex image
<figure>
  <img src="/diagram.png" alt="System architecture diagram" aria-describedby="diagram-desc" />
  <figcaption id="diagram-desc">
    The system consists of three main components: API Gateway, 
    Application Server, and Database Cluster...
  </figcaption>
</figure>

// Icon with text
<button>
  <svg aria-hidden="true">...</svg>
  Save Document
</button>

// Icon only
<button aria-label="Save document">
  <svg aria-hidden="true">...</svg>
</button>
```

### 6.2 Video & Audio

```html
<video controls>
  <source src="video.mp4" type="video/mp4" />
  <track kind="captions" src="captions.vtt" srclang="en" label="English" />
  <track kind="descriptions" src="descriptions.vtt" srclang="en" label="Descriptions" />
</video>
```

---

## 7. Color & Contrast

### 7.1 Contrast Ratios

| Element | WCAG AA | WCAG AAA |
|---------|---------|----------|
| Normal text | 4.5:1 | 7:1 |
| Large text (18px+ bold, 24px+) | 3:1 | 4.5:1 |
| UI components | 3:1 | 3:1 |

### 7.2 Don't Rely on Color Alone

```tsx
// BAD - Only color indicates error
<input style={{ borderColor: 'red' }} />

// GOOD - Color + icon + text
<div>
  <input aria-invalid="true" aria-describedby="error" className="border-red-500" />
  <span id="error" className="text-red-500">
    <ErrorIcon aria-hidden="true" />
    Invalid email address
  </span>
</div>
```

---

## 8. Testing

### 8.1 Automated Testing

```tsx
// jest-axe
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

test('component has no accessibility violations', async () => {
  const { container } = render(<MyComponent />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

### 8.2 Manual Testing Checklist

- [ ] Navigate with keyboard only
- [ ] Use screen reader (NVDA, VoiceOver)
- [ ] Zoom to 200% - content still usable
- [ ] Check color contrast
- [ ] Test focus visibility
- [ ] Verify form error handling

---

## 9. Utility Classes

```css
/* Screen reader only */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* Not screen reader only - visible when focused */
.not-sr-only {
  position: static;
  width: auto;
  height: auto;
  padding: 0;
  margin: 0;
  overflow: visible;
  clip: auto;
  white-space: normal;
}

/* Focus visible */
.focus-visible:focus-visible {
  outline: 2px solid var(--focus-ring);
  outline-offset: 2px;
}
```

---

## Quick Reference

### Keyboard Navigation

| Key | Action |
|-----|--------|
| Tab | Move to next focusable element |
| Shift+Tab | Move to previous element |
| Enter | Activate button/link |
| Space | Activate button, toggle checkbox |
| Arrow keys | Navigate within components |
| Escape | Close modal/dropdown |

### ARIA Roles

| Role | Use For |
|------|---------|
| `button` | Clickable action |
| `link` | Navigation |
| `dialog` | Modal |
| `alert` | Important message |
| `status` | Live update |
| `tablist/tab/tabpanel` | Tabs |
| `listbox/option` | Dropdown |
| `menu/menuitem` | Menu |

### Checklist

- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] Color contrast meets WCAG AA
- [ ] Keyboard navigation works
- [ ] Focus is visible
- [ ] Skip links exist
- [ ] Headings are hierarchical
- [ ] ARIA used correctly
- [ ] Live regions for updates
- [ ] No keyboard traps
