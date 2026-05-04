---
name: pscan
description: 프로젝트 스캔. Analyze project source code, architecture, and structure to generate a comprehensive context document (.claude/projectology.md). Use when entering a new project, needing full project understanding, or when asked to "프로젝트 스캔", "analyze this project", "understand this codebase", "generate project context", "scan this project", or "pscan". Supports smart mode (auto-detect) and forced regeneration.
argument-hint: "[generate]"
---

# Projectology — Project Context Intelligence

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


Analyze source code, architecture, and structural patterns to produce a compact understanding document. Loading this document in future conversations provides instant, complete project context.

**This document complements CLAUDE.md.** CLAUDE.md = "how to work with me" (instructions). Projectology = "what this project is" (understanding). They must not overlap.

## Commands

| Command | Behavior |
|---------|----------|
| `/projectology` | Smart: generate if missing, update if stale, confirm if fresh |
| `/projectology generate` | Force full analysis and regeneration |

## Phase 1: Assess

Check current state and decide action.

1. Run in parallel:
   - Check if `.claude/projectology.md` exists (Read tool)
   - Get current git hash: `git rev-parse HEAD`

2. **If file missing or `generate` argument:** → Phase 2 (Full Analysis)

3. **If file exists and no `generate` flag:**
   - Extract `git-hash` from document frontmatter
   - Count changes: `git diff --stat <saved-hash> HEAD | tail -1`
   - **0 changes** → Read document into context. Tell user: "Projectology loaded (generated {date}, current)." Done.
   - **< 30 files changed** → Phase 3 (Incremental Update)
   - **≥ 30 files changed** → Phase 2 (Full Analysis)

## Phase 2: Full Analysis

Launch an **Explore agent** (thoroughness: "very thorough") with the analysis mission below. The agent returns raw structured findings — synthesis happens in Phase 4.

### Agent Mission

```
Analyze this project comprehensively. Report findings in these exact sections:

1. IDENTITY
   - What this project does (1-2 sentences, be specific)
   - Primary language, framework, and build system
   - Target platform/audience

2. STRUCTURE
   - Top-level directories with purpose of each (skip node_modules, build outputs, .git)
   - File distribution: approximate count by type (source, test, config, asset)
   - Key config files and what each configures

3. ARCHITECTURE
   - Architectural pattern (MVC, MVVM, Clean, layered, hexagonal, etc.) — commit to one
   - Major layers/modules and their boundaries
   - Data flow direction (e.g., View → ViewModel → Repository → API)
   - Key abstractions: protocols, interfaces, base classes that define the system's skeleton

4. MODULES (for each major module/directory)
   - Responsibility (1 sentence, opinionated)
   - Entry point files (not exhaustive file lists)
   - Upstream dependencies (what it uses)
   - Downstream dependents (what uses it)

5. FILE MAP
   For EVERY source file (read first 30-50 lines of each to verify):
   - File path (relative to project root)
   - One-line description of what it does (specific and opinionated, not generic)
   Group by directory. Include source files, test files, scripts, and resource directories.
   For test files, group by feature area with brief descriptions.
   For scripts, state each script's purpose.

6. KEY FLOWS (3-5 most important)
   - Name the flow (e.g., "User creates a new workspace")
   - Trace through modules: A → B → C with what happens at each step

7. DATA MODELS
   - Core entities and their relationships (not every model — the important ones)
   - Storage mechanism (CoreData, SQLite, API-only, filesystem, etc.)
   - Key transformations (e.g., DTO → Domain Model → View Model)

8. INFRASTRUCTURE
   - Build: exact command(s)
   - Test: exact command(s) and test strategy (unit, integration, UI, snapshot)
   - Deploy: mechanism or commands
   - CI/CD: if present, what system and key steps

9. CONVENTIONS
   - File naming pattern (e.g., PascalCase for types, kebab-case for configs)
   - Code organization patterns within files
   - Recurring design patterns (DI, observers, builders, etc.)
   - Error handling approach
```

### Analysis Strategy for the Agent

Prioritize reading order for maximum insight per token:

1. **Config files first** — they reveal the most: package.json, Cargo.toml, Package.swift, go.mod, pyproject.toml, build.gradle, Makefile, etc.
2. **Entry points** — main.swift, index.ts, App.tsx, main.go, etc.
3. **Key interfaces/protocols** — these define the architecture's skeleton
4. **Directory structure** — glob patterns to understand file distribution
5. **Every source file** — read first 30-50 lines to determine purpose. File map must be accurate, not guessed from filenames.
6. **Test structure** — group by feature, note what each file covers
7. **Scripts** — read each to determine purpose

Do NOT read: generated files, lock files, vendored dependencies, asset binaries.

### Framework-Specific Signals

Detect project type and adjust focus:

| Signal File | Type | Extra Focus |
|-------------|------|-------------|
| .xcodeproj, Package.swift | Swift/Apple | Targets, SwiftUI vs UIKit, app lifecycle, extensions |
| package.json | Node.js/TS | Scripts, workspaces, bundler, SSR/CSR |
| Cargo.toml | Rust | Workspace members, features, unsafe, async runtime |
| go.mod | Go | cmd/ vs internal/ vs pkg/, interface patterns |
| pyproject.toml | Python | Package structure, async, type coverage, ML frameworks |
| docker-compose.yml | Multi-service | Service topology, networking, shared volumes |
| Podfile, .xcworkspace | iOS with deps | Pod integration, bridging headers |
| Makefile, CMakeLists.txt | Native/C++ | Build targets, platform support |

## Phase 3: Incremental Update

For small changes (< 30 files since last generation):

1. Read existing `.claude/projectology.md`
2. Get changed files: `git diff --name-only <saved-hash> HEAD`
3. Determine which document sections are affected:
   - New top-level directories → update Structure & Modules
   - Changed config files → update Stack & Infrastructure
   - New/removed source directories → update Modules
   - Model changes → update Data Models
4. Launch Explore agent to analyze ONLY changed areas
5. Merge new findings into existing document sections
6. Proceed to Phase 4 with merged content

## Phase 4: Synthesis

Write the document following this template. Every section is required. Be opinionated, not exhaustive.

````markdown
---
project: {name}
generated: {YYYY-MM-DD}
git-hash: {full 40-char sha}
---

# {Project Name}

{1-2 sentences: what it does, who it's for, what platform. Be specific.}

## Stack

{Language} · {Framework} · {Build System} · {Key Deps (max 5, only the important ones)}

## Architecture

{2-4 sentences: pattern name, layers, data flow direction, key boundaries.}

{Optional: ASCII diagram ONLY if 3+ distinct layers and non-obvious flow.}
{Keep diagrams under 8 lines. Example:}
{  View → ViewModel → Repository → API  }
{                  ↕                      }
{              LocalCache                 }

## Modules

### {ModuleName}
{1-sentence responsibility.}
Key: `{path/to/entry.ext}`, `{path/to/other.ext}`
Uses: {OtherModule}, {AnotherModule}

{Repeat for 4-10 major modules. Order by dependency — foundations first.}

## File Map

{Every source file grouped by directory. One line per file: path — role.}
{Read each file to verify — do not guess from filename alone.}
{For test files, group by feature area. For scripts, state purpose.}

### {Directory/}
- `FileName.ext` — {one-line role, specific and opinionated}

{Repeat for all directories containing source, test, script, or config files.}
{Skip: build outputs, vendored deps, lock files, binary assets.}

## Key Flows

1. **{Flow Name}**: {ModuleA} → {ModuleB} → {ModuleC} — {what happens in one line}

{3-5 flows. Most important user-facing journeys.}

## Data Models

{Core entities and relationships in compact prose or simple list.}
{Storage: mechanism.}

## Build & Deploy

- Build: `{command}`
- Test: `{command}`
- Deploy: `{command or description}`

## Conventions

- {Convention 1: be specific, e.g., "ViewModels use @Published properties, never direct UI references"}
- {Convention 2}
- {Convention 3}
{3-6 conventions. Only non-obvious ones — skip universal best practices.}
````

### Synthesis Rules

1. **Opinionated, not hedging.** Say "uses MVVM" not "appears to use MVVM."
2. **Paths over prose.** `Key: \`src/auth/AuthService.ts\`` > "the auth service file."
3. **Relationships over inventory.** "ViewModel observes Repository via Combine" > listing both files.
4. **No code snippets.** Describe patterns; code changes, descriptions endure.
5. **No implementation details** that change with every commit. Focus on structural truths.
6. **Token targets** (file map included):
   - Small project (< 50 source files): ~3,000 tokens
   - Medium (50–200 files): ~6,000 tokens
   - Large (200+ files): ~10,000 tokens
7. **ASCII diagrams** only when they genuinely clarify. Most projects don't need one.

## Phase 5: Save & Confirm

1. Write document to `.claude/projectology.md`
2. Report to user:
   - What was analyzed (file count, module count)
   - Document token size (approximate)
   - Suggest adding `.claude/projectology.md` to `.gitignore` if not already there (it's derived, always regeneratable)
