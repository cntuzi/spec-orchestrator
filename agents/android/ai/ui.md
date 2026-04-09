# Android UI Development Conventions

> UI implementation standards for {PROJECT_NAME} Android.

---

## 1. Compose-First Approach

All new screens and components must use Jetpack Compose unless modifying an existing XML-based screen where migration is out of scope.

### Composable Structure
```
@Composable
fun FeatureScreen(
    modifier: Modifier = Modifier,      // always first optional param
    viewModel: FeatureViewModel = hiltViewModel(),
    onNavigate: (Route) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    // ...
}
```

### State Management
- ViewModel exposes `StateFlow<UiState>` (sealed interface).
- Composables collect via `collectAsStateWithLifecycle()`.
- Side effects in `LaunchedEffect` / `SideEffect` -- never in composition body.

---

## 2. Material Design 3 Alignment

- Use `MaterialTheme.colorScheme`, `MaterialTheme.typography`, `MaterialTheme.shapes`.
- Do not hardcode colors or text styles. Always reference theme tokens.
- Support dynamic color (Material You) where feasible.
- Custom theme extensions for app-specific tokens (e.g., `AppColors.chatBubbleSent`).

### Color Usage
| Token | Usage |
|-------|-------|
| `primary` | Primary actions, FAB, key UI |
| `surface` | Card/sheet backgrounds |
| `onSurface` | Body text |
| `error` | Error states, destructive actions |
| `outline` | Borders, dividers |

### Typography
- Headlines: `MaterialTheme.typography.headlineSmall` / `headlineMedium`.
- Body: `MaterialTheme.typography.bodyMedium` / `bodyLarge`.
- Labels: `MaterialTheme.typography.labelSmall` / `labelMedium`.

---

## 3. Figma Resource Integration

### Download Protocol
When a task references Figma designs:

1. **Read** `figma-index.md` to locate the relevant page and node IDs.
2. **Export** assets at the required density:
   - Icons: export as SVG, convert to vector drawable.
   - Photos/illustrations: export as PNG at 3x, convert to WebP.
   - Place in `drawable-xxxhdpi/` (raster) or `drawable/` (vector).
3. **Name** following the asset naming convention in `android.md`.

### Density Mapping
| Figma Scale | Android Bucket | DPI |
|-------------|---------------|-----|
| 1x | mdpi | 160 |
| 1.5x | hdpi | 240 |
| 2x | xhdpi | 320 |
| 3x | xxhdpi | 480 |
| 4x | xxxhdpi | 640 |

For production, provide at minimum **xxhdpi** and **xxxhdpi**.

---

## 4. Six-Dimension Design Analysis

Before implementing any UI task, analyze the design across six dimensions.

### 4.1 Layout Structure
- Identify root container type (Column, Row, Box, LazyColumn, Scaffold).
- Map visual hierarchy to composable tree.
- Note scrolling behavior (LazyColumn vs Column+verticalScroll).
- Identify shared vs screen-specific components.

### 4.2 Component Inventory
- List every distinct UI component visible in the design.
- Map to existing Material 3 components or custom composables.
- For custom components: define input parameters, state, and events.
- Estimate reusability -- extract to `ui/components/` if used in 2+ screens.

### 4.3 Spacing and Dimensions
- Record all padding, margin, gap values in dp.
- Identify repeating spacing patterns (4dp grid, 8dp grid, 16dp grid).
- Note fixed vs flexible dimensions.
- Capture corner radius, elevation, and border values.

### 4.4 Color and Typography
- Map every color in the design to a Material 3 theme token.
- If no token fits, define a custom token with rationale.
- Map text styles to `MaterialTheme.typography` slots.
- Note opacity values and alpha usage.

### 4.5 Interaction and Motion
- Identify tap targets and their feedback (ripple, scale, color change).
- Note transitions between states (loading, empty, error, content).
- Identify scroll behaviors (collapsing toolbar, sticky headers, parallax).
- Note animation requirements (enter/exit, shared element).

### 4.6 Adaptive and Accessibility
- Identify layout changes for different screen sizes (phone vs tablet).
- Note minimum touch target sizes (48dp per Material guidelines).
- Verify contrast ratios for text and icons.
- Plan content descriptions for non-text elements.
- Consider RTL layout implications.

---

## 5. Compose vs XML Decision Guide

| Signal | Decision | Rationale |
|--------|----------|-----------|
| New screen | Compose | Default for all greenfield work |
| New component on Compose screen | Compose | Consistency |
| Bug fix in XML screen | XML | Minimize blast radius |
| Feature addition to XML screen (< 30% change) | XML | Not worth migration overhead |
| Feature addition to XML screen (> 50% change) | Compose migration | Good opportunity to modernize |
| RecyclerView with complex view types | LazyColumn (Compose) | Simpler, less boilerplate |
| Map / Camera / WebView | AndroidView wrapper | Native views in Compose |

---

## 6. Navigation

- Use Compose Navigation (`NavHost` + `NavController`).
- Define routes as a sealed class or enum.
- Deep link support via `navDeepLink`.
- Pass arguments via type-safe route parameters, not bundles.

---

## 7. Image Loading

- Use Coil (`AsyncImage` composable) for network images in Compose.
- Use Glide for XML-based screens.
- Always provide placeholder and error drawables.
- Set `crossfade(true)` for smoother loading transitions.
- Cache strategy: disk + memory (Coil defaults).

---

## 8. Testing UI

### Unit Tests (ViewModel)
- Test state transitions for every `UiState` variant.
- Use `Turbine` for Flow testing.
- Mock repository layer.

### UI Tests (Compose)
- Use `composeTestRule` with semantic matchers.
- Test critical user flows (happy path + error path).
- Tag composables with `testTag` for reliable selection.
- Screenshot tests with Paparazzi for visual regression.

---

## 9. Performance Checklist

- [ ] No unnecessary recompositions (use `key {}`, `remember`, `derivedStateOf`).
- [ ] Large lists use `LazyColumn` / `LazyRow` with `key` parameter.
- [ ] Images sized appropriately (no loading 4000px image into 48dp icon).
- [ ] Heavy computation in ViewModel, not in composable.
- [ ] Animations use `animateXxxAsState` (not manual frame loops).
