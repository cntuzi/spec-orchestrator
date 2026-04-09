# iOS Coding Conventions

> Tool-agnostic iOS project constraints. All AI tools (Codex CLI, Claude Code, Cursor, Copilot, etc.) must follow these rules when modifying iOS code.

## Project Overview

- Workspace: `{WORKSPACE}.xcworkspace`
- Language: Swift 5
- Architecture: {ARCHITECTURE_DESCRIPTION} (e.g., modular CocoaPods + MVVM)
- UI Framework: {UI_FRAMEWORK} (e.g., UIKit + SnapKit)
- Networking: {NETWORKING_LAYER} (e.g., URLSession-based / Moya + RxSwift / Alamofire)

## Code Style (mandatory)

- Indentation: 4 spaces; line length: <= 120 characters
- Optionals: prefer `guard let` / `if let`; never force-unwrap with `!`
- Naming: `lowerCamelCase` for variables and methods, `UpperCamelCase` for types
- One top-level type per file
- Mirror folder structure in Xcode groups
- Braces on the same line as declarations

## i18n Rules (mandatory)

- No hardcoded user-facing strings in source files
- All strings must go through the project's localization system (e.g., `NSLocalizedString`, `.xcstrings`, or custom wrapper)
- Format specifiers must match across all languages (`%@` for strings, `%d` for integers, `%f` for floats)
- When adding new UI text, add the corresponding i18n key simultaneously

## Layout Rules (mandatory)

- Use constraint-based layout exclusively; no raw frame assignments
- Spacing and sizing: use design tokens (project constants) instead of magic numbers
- Standard spacing reference: page margin 16pt / component gap 12pt / element gap 8pt / touch target >= 44pt
- If the project uses a style DSL (e.g., SnapKit), use it consistently; do not mix approaches

## Asset Rules (mandatory: no SVG)

- `*.xcassets` must not contain SVG files; only PNG @2x/@3x allowed
- `Contents.json` must not include `"preserves-vector-representation": true`
- Do not use `qlmanage -t` (QuickLook thumbnail) as a production SVG-to-PNG pipeline
- Export PNG directly from Figma or design tools at 2x and 3x scales
- Verify asset dimensions before committing: `sips -g pixelWidth -g pixelHeight <png>`

## Build Verification (mandatory)

- After every module or phase of changes, run the project build command:
  ```bash
  # Replace with your project's build command
  ./scripts/build.sh
  # or
  xcodebuild -workspace {WORKSPACE}.xcworkspace -scheme {SCHEME} -configuration Debug build
  ```
- Expected output: `BUILD SUCCEEDED`
- Build loop: modify -> build -> fix errors -> build again (never accumulate errors)
- Keep change scope minimal; do not refactor unrelated code incidentally
- Incremental migration: <= 15 files and <= 1500 lines per batch

## Worktree Environment

External paths (specs, api-doc) are resolved via `.context-resolved.yaml`.
If missing, run `bash {specs_repo}/scripts/resolve-context.sh` to auto-detect paths.
Legacy `specs` symlink still works as fallback.
