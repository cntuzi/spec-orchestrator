# Android Development Conventions

> Coding standards and project constraints for {PROJECT_NAME} Android.

---

## 1. Project Overview

- **Language**: Kotlin (100%). No new Java files unless wrapping legacy interop.
- **UI toolkit**: Jetpack Compose (preferred) + View/XML (legacy screens only).
- **Architecture**: MVVM + Clean Architecture layers (presentation / domain / data).
- **Networking**: Retrofit + OkHttp + kotlinx.serialization (or Moshi).
- **Async**: Kotlin Coroutines + Flow. No RxJava in new code.
- **DI**: Hilt (Dagger under the hood).
- **Min SDK**: 26 (Android 8.0).
- **Target SDK**: latest stable.

---

## 2. Code Style

### Formatting
- **Indentation**: 4 spaces, no tabs.
- **Line length**: 120 characters max.
- **Braces**: same-line opening brace.
- **Trailing commas**: always in multi-line parameter lists and when expressions.

### Naming
| Element | Convention | Example |
|---------|-----------|---------|
| Class / Interface | PascalCase | `ChatViewModel`, `UserRepository` |
| Function / Property | camelCase | `fetchMessages()`, `isLoading` |
| Constant (top-level / companion) | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Resource file | snake_case | `ic_send_message.xml` |
| Package | lowercase, dot-separated | `com.example.feature.chat` |
| Compose composable | PascalCase (noun) | `ChatBubble()`, `ProfileHeader()` |

### Nullability
- Prefer non-null types. Use `?` only when the domain genuinely allows null.
- Never use `!!` in production code. Use `requireNotNull()` with a message or safe-call chains.
- ViewModel exposed state must be non-null; use sealed classes or default values.

### Kotlin Idioms
- Use `data class` for plain models.
- Use `sealed class` / `sealed interface` for UI state and navigation events.
- Prefer `when` over if-else chains for more than 2 branches.
- Extension functions over utility classes.

---

## 3. Architecture Layers

```
presentation/          ViewModel + Compose UI + navigation
    |
domain/                Use cases + domain models + repository interfaces
    |
data/                  Repository implementations + API services + local DB
```

- **ViewModel** exposes `StateFlow<UiState>` and accepts `Intent` / action functions.
- **UseCase** is a single-responsibility class with `operator fun invoke()`.
- **Repository** abstracts data sources behind an interface; implementation in `data/`.

---

## 4. Internationalization (i18n)

### File locations
- `app/src/main/res/values/strings.xml` -- default language (Chinese)
- `app/src/main/res/values-ja/strings.xml` -- Japanese
- `app/src/main/res/values-en/strings.xml` -- English

### Rules
- **No hardcoded user-visible strings**. Debug logs and internal tags are exempt.
- New strings must be added to ALL language files simultaneously.
- Format specifiers (`%s`, `%d`, `%1$s`) must match across all locales.
- Use `plurals` for quantity strings.
- String keys: `snake_case`, prefixed by feature module (e.g., `chat_send_button`).

---

## 5. Layout and UI Rules

### Compose (preferred for all new screens)
- Material 3 theming via `MaterialTheme`.
- Use `Modifier` as the first optional parameter of every composable.
- Extract reusable composables into the `ui/components/` package.
- Preview every composable with `@Preview` (light + dark, small + large font).
- State hoisting: composables are stateless; ViewModel owns state.

### XML (legacy only)
- ConstraintLayout for complex layouts; LinearLayout / FrameLayout for simple cases.
- No nested weights (performance).
- Use `tools:` attributes for design-time preview data.

### Decision guide: Compose vs XML
| Scenario | Choice |
|----------|--------|
| New screen | Compose |
| New component in existing Compose screen | Compose |
| Small fix in existing XML screen | XML (keep consistency) |
| Major refactor of XML screen | Migrate to Compose |

---

## 6. Asset Rules

### Drawables
- **Vector drawables** (`.xml`) for icons and simple graphics. Max 200dp intrinsic size.
- **WebP** for photos and complex images. No PNG unless transparency requires it and WebP cannot handle it.
- Never commit raw SVG files. Convert to vector drawable via Android Studio or `vd-tool`.

### Density buckets
- Vector drawables: single file in `drawable/`.
- Raster images: provide `drawable-xxhdpi/` at minimum. `drawable-xxxhdpi/` for key assets.
- Night mode variants in `drawable-night/` when needed.

### Naming convention
| Type | Pattern | Example |
|------|---------|---------|
| Icon | `ic_{description}` | `ic_arrow_back.xml` |
| Background | `bg_{description}` | `bg_chat_bubble.xml` |
| Illustration | `img_{description}` | `img_empty_state.webp` |
| Selector | `sel_{description}` | `sel_button_primary.xml` |

---

## 7. Build Verification

### Commands
```bash
# Debug build (primary verification)
./gradlew assembleDebug

# Full check (lint + compile)
./gradlew assembleDebug lintDebug

# Run unit tests
./gradlew testDebugUnitTest

# Run instrumented tests
./gradlew connectedDebugAndroidTest
```

### Verification loop
After every code change:
1. `./gradlew assembleDebug` -- must see `BUILD SUCCESSFUL`.
2. Fix errors immediately. Do not accumulate.
3. Run relevant unit tests before marking task complete.

---

## 8. Dependencies

- Add dependencies in version catalog (`libs.versions.toml`) or `buildSrc`.
- Never hardcode version strings in `build.gradle.kts`.
- Review transitive dependencies before adding new libraries.
- Keep `gradle.lockfile` or version catalog in sync after changes.

---

## 9. Git Conventions

- **Commit format**: `type(scope): subject` (e.g., `feat(chat): add message reactions`).
- **Types**: feat, fix, refactor, style, test, docs, chore, perf.
- **Subject**: imperative mood, no period, under 72 characters.
- **Body** (optional): explain why, not what. Wrap at 72 columns.
- Reference tasks: `Refs T01` or `Closes T01`.
