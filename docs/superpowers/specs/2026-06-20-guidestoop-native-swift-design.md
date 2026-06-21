# Guidestoop Native Swift App — Design Spec

**Date:** 2026-06-20  
**Status:** Approved  
**Repo:** `guidestoop-app` (native app)  
**Reference:** `karmatosed/guidestoop` (TypeScript monorepo — task-core, web, Supabase)

---

## Summary

Guidestoop is a calm, markdown-native personal task hub. Tasks are real `.md` files the user owns — not rows in a hosted database. The native Swift app is a UI + sync layer over those files.

**v1:** iOS app with iCloud Drive storage (user-picked folder, sensible default).  
**Phase 2:** GitHub as an alternative storage provider (user picks iCloud *or* GitHub, not both).  
**Future:** macOS target sharing the same core packages.

Markdown is the **persistence format**, not the UI paradigm. Users interact through normal task views (list, kanban, day timeline, forms). The app reads/writes `.md` files under the hood; users can edit files externally in Obsidian or any editor.

---

## Product Philosophy (Non-Negotiable)

1. **Markdown is source of truth** — no task without a `{uuid}.md` file.
2. **User-owned storage** — task bodies never live on Guidestoop servers.
3. **Calm Technology** — low urgency, no notification spam, graceful failure.
4. **Cache is disposable** — local DB is for speed; rebuild from files anytime.
5. **Human-readable always** — user can quit and edit files in any editor.

---

## Decisions

| Topic | Decision |
|---|---|
| Storage format | YAML frontmatter + markdown body (same schema as web) |
| v1 provider | iCloud Drive — user picks folder, default `Guidestoop/` |
| Phase 2 provider | GitHub (alternative, not simultaneous with iCloud) |
| Auth v1 | None — iCloud folder is identity |
| Auth phase 2 | Supabase OAuth when GitHub connects |
| Platform v1 | iOS (iPhone + iPad adaptive layouts) |
| Platform future | macOS — new target, same packages |
| Feature scope v1 | Full web parity |
| Architecture | Shared Swift Package + thin platform shell (Approach A) |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  SwiftUI (iOS v1 → macOS later)           │
│  List · Kanban · Day · Detail · Settings  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  LocalStore (SwiftData)                     │
│  tasks · projects · deletedTasks · outbox   │
│  Disposable cache — rebuild from files      │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  SyncEngine                                 │
│  Flush outbox → scan folder → merge → push  │
│  Same rules as task-core markdown adapter   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  StorageAdapter protocol                    │
│  ┌─────────────┐  ┌──────────────┐          │
│  │ ICloudAdapter│  │ GitHubAdapter│ (ph.2)  │
│  │ v1           │  │              │          │
│  └─────────────┘  └──────────────┘          │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  User's iCloud Drive folder                 │
│  /tasks/*.md  /projects/*.md                │
│  /tasks/deleted/*.md  /_meta/guidestoop.json│
└─────────────────────────────────────────────┘
```

**Data flow:** User edits in UI → write local cache + outbox entry → sync engine writes `.md` file → iCloud propagates → file change detected → re-parse → merge → update cache.

**External edits** (Obsidian, Files app): directory watcher / `NSFilePresenter` detects change → parse → merge with local. If remote `updated` > local and content differs → write `{uuid}.conflict.{timestamp}.md`, never silently overwrite.

**No Guidestoop server in v1.** Settings stored locally. `guidestoop.json` in the folder holds schema version and future sync cursors.

---

## Project Structure

```
guidestoop-app/
├── Packages/
│   ├── GuidestoopCore/           # Pure Swift, no UI imports
│   │   ├── Models/               # Task, Project, DeletedTask, TaskStatus
│   │   ├── Markdown/             # Parse + serialize (YAML frontmatter + body)
│   │   ├── Merge/                # Conflict detection, conflict filename generation
│   │   ├── Schedule/             # "Today", date-only scheduled, timeline sort
│   │   ├── Trash/                # 30-day retention helpers
│   │   └── Sync/                 # SyncEngine, OutboxStore, merge orchestration
│   └── GuidestoopStorage/
│       ├── StorageAdapter.swift  # Protocol: list, read, write, delete, sync
│       ├── ICloudAdapter.swift   # v1
│       └── GitHubAdapter.swift   # phase 2 (stub in v1)
├── Apps/
│   └── GuidestoopIOS/            # SwiftUI app target
│       ├── Views/                # List, Kanban, Day, Detail, Settings
│       ├── Data/                 # SwiftData LocalStore models + queries
│       └── Onboarding/           # Folder picker flow
└── GuidestoopCoreTests/          # Port of task-core test cases
```

macOS later = new `GuidestoopMac` target importing the same packages.

---

## Cloud Folder Layout

User-picked iCloud Drive folder (default: `iCloud Drive/Guidestoop/`):

```
Guidestoop/
├── tasks/
│   ├── {uuid}.md                    # active tasks
│   ├── {uuid}.conflict.{ts}.md      # conflict copies
│   └── deleted/
│       └── {uuid}.md                # trashed (deletedAt in frontmatter)
├── projects/
│   └── {slug}.md
└── _meta/
    └── guidestoop.json              # schema version, sync cursors
```

Paths use leading slash convention internally: `/tasks/...`, `/projects/...`.

---

## Task File Format

```markdown
---
id: "550e8400-e29b-41d4-a716-446655440000"
title: "Task title"
status: inbox          # inbox | blocked | focus | scheduled | done
scheduled: null        # ISO datetime OR date-only YYYY-MM-DD
duration: null         # minutes (number)
project: null          # project name string
tags: []               # string array
created: "2026-05-23T08:00:00.000Z"
updated: "2026-05-23T10:30:00.000Z"
---
Freeform markdown body (notes, checklists, etc.)
```

Deleted tasks add `deletedAt: "<ISO>"` and live in `/tasks/deleted/{uuid}.md`. Trash retention: 30 days, auto-purge on sync.

### Project File Format

```markdown
---
id: proj-{slug}
name: "Project name"
color: "#4A90D9"       # optional
created: "<ISO>"
updated: "<ISO>"
---
Optional description markdown.
```

### Core Types (Swift)

```swift
enum TaskStatus: String, Codable {
    case inbox, blocked, focus, scheduled, done
}

struct Task: Codable, Identifiable {
    var id: String           // UUID
    var title: String
    var status: TaskStatus
    var scheduled: String?   // ISO or YYYY-MM-DD
    var duration: Int?       // minutes
    var project: String?
    var tags: [String]
    var created: String      // ISO8601
    var updated: String
    var body: String
}

struct DeletedTask: Codable {
    // Task fields + deletedAt: String
}

struct Project: Codable, Identifiable {
    var id: String           // proj-{slug}
    var name: String
    var color: String?
    var created, updated: String
    var body: String
}
```

Reference implementation: `packages/task-core/src/schema.ts`

---

## iCloud Storage & Onboarding

### First Launch Flow

1. Welcome screen: "Your tasks live as markdown files in iCloud Drive."
2. Offer default: create and use `iCloud Drive/Guidestoop/` with subfolders (`tasks/`, `projects/`, `tasks/deleted/`, `_meta/`).
3. "Choose a different folder" opens `UIDocumentPickerViewController` scoped to iCloud.
4. Store a **security-scoped bookmark** in Keychain for persistent folder access.
5. Initial sync: scan folder → parse all `.md` files → populate SwiftData cache.

### ICloudAdapter Responsibilities

- Resolve folder URL from bookmark (or create default).
- List/read/write/delete files via `NSFileCoordinator`.
- Watch directory for external changes (`NSFilePresenter`).
- Create subfolder structure on first use.
- Read/write `_meta/guidestoop.json`.

### Manual Sync

Settings exposes manual sync button + "last synced" timestamp. Sync triggers incremental folder scan + outbox flush. Offline outbox indicator when pending ops exist.

---

## Sync Performance & Incremental Sync

The UI reads from SwiftData cache, not the folder. Sync runs in the background and should scale to thousands of tasks without blocking the app.

### Strategy

1. **Metadata-first listing** — enumerate paths + filesystem modification dates without reading file contents.
2. **Selective reads** — read and parse a `.md` file only when:
   - it is new (not in local cache),
   - filesystem `modifiedAt` is newer than the last-seen entry in the manifest, or
   - it is targeted by a pending outbox operation.
3. **File manifest in `guidestoop.json`** — disposable cache of last-seen `updated` + `modifiedAt` per path (rebuild anytime from files).
4. **Unchanged files** — keep the local SwiftData copy (including body); do not re-read from disk.
5. **Deletion reconciliation** — compare remote path listing vs cache; remote deletions propagate unless local still has pending changes to push.
6. **Trash folder** — can be synced less frequently (on Trash tab open or manual sync).

### `guidestoop.json` manifest (extended)

```json
{
  "schemaVersion": 1,
  "lastSyncedAt": "2026-06-21T10:00:00.000Z",
  "files": {
    "/tasks/{uuid}.md": {
      "updated": "2026-06-20T12:00:00.000Z",
      "modifiedAt": "2026-06-20T12:00:00.000Z",
      "size": 412
    }
  }
}
```

Dropbox uses API cursors for deltas; iCloud has no delta API, so the manifest substitutes for cursor-based incremental sync.

### Scaling expectations

| Task count | Expected sync (typical, few changes) |
|---|---|
| ~100 | <100ms metadata + changed reads |
| ~1,000 | ~200ms metadata + O(changes) reads |
| ~5,000+ | Consider folder sharding (future); manifest keeps daily sync fast |

### Future optimizations (if needed)

- Frontmatter-only parse during sync (body loaded on detail open)
- `/tasks/{aa}/{uuid}.md` sharding for 5k+ tasks
- `NSFilePresenter` single-file incremental updates (implemented in v1 via `ICloudFolderWatcher`)

---

## Sync Engine

Port logic from `packages/task-core/src/storage/markdown-storage-adapter.ts`.

### Sync Cycle

1. Flush outbox (pending save / delete / restore / purge ops → write files).
2. List folder **metadata** (path + modification date, no content reads).
3. Read and parse only changed or new `.md` files (compare manifest + mod dates).
4. Merge local cache vs. remote by `updated` timestamp.
5. On conflict → write `{uuid}.conflict.{timestamp}.md`, surface banner in UI.
6. Sync deleted folder separately; remove active copies for trashed IDs.
7. Auto-purge trash older than 30 days.
8. Update manifest in `guidestoop.json`; replace local cache with merged result.

### Outbox Pattern

UI writes to SwiftData immediately. Queue file write in outbox. If iCloud unreachable, ops accumulate and flush on next sync.

Outbox operations: `save` | `delete` | `restore` | `purge`

### Merge Rule (Critical)

If remote `updated` > local and content differs → write conflict copy `{id}.conflict.{timestamp}.md`. Never silently overwrite.

---

## Local Cache (SwiftData)

Mirror web app's Dexie schema:

| Table | Purpose | Indexes |
|---|---|---|
| `tasks` | Active tasks | id, status, updated, scheduled |
| `projects` | Projects | id |
| `deletedTasks` | Trash | id, deletedAt |
| `outbox` | Offline queue | op, taskId |

Cache is disposable. Full rebuild from folder scan anytime.

---

## UI & Feature Parity (v1)

Normal task app UI. Markdown is storage, not presentation.

| View | Behavior |
|---|---|
| **List** | Tabs: All, Inbox, Blocked, Today, Done, Trash. Checkbox to mark done. Search (title, body, project, tags). Tag filter chips. |
| **Kanban** | Columns: inbox → blocked → focus → scheduled → done. Drag to change status. Quick-add per column. |
| **Day** | Timeline for selected day. Scheduled + focus tasks. Quick-add for that day. |
| **Task detail** | Form tab (title, status, schedule, duration, project, tags, body) + raw markdown tab. Sheet on iPhone; trailing column layout iPad-ready. |
| **Settings** | Folder location, manual sync, last synced, conflict file list, dark mode (system + override). Storage shows "iCloud Drive"; "Switch to GitHub" disabled until phase 2. |
| **Conflicts** | Banner when `.conflict.*.md` files exist. Tap to review and pick a winner. |

### Design Language

- Calm, dark-first, minimal chrome
- Lowercase "g" mark
- Typography-led; dashed quick-add inputs; soft buttons
- No red badges, streaks, or urgency patterns
- Reference: web `apps/web/src/styles/global.css`

---

## Auth & Phase 2 (GitHub)

### v1

No sign-in. Persistence via iCloud folder + local cache + Keychain bookmarks.

### Phase 2

- Add Supabase Auth (Google/GitHub OAuth) — same project as web (`yfwmlgpswclmeywrtjco`).
- Call existing edge functions: `supabase/functions/github-oauth`.
- `GitHubAdapter` implements `StorageAdapter` protocol.
- User picks **one** provider in settings: iCloud **or** GitHub.
- Switching providers = migration/export flow, not simultaneous sync.
- Do not embed Dropbox/GitHub secrets in the app.

---

## Testing

Port or reimplement tests from task-core:

| Test file | Covers |
|---|---|
| `markdown.test.ts` | Round-trip fidelity: `parse(serialize(task)) === task` |
| `merge.test.ts` | Conflict detection, conflict filename generation |
| `schedule.test.ts` | "Today", date-only scheduled, timeline sorting |
| `trash.test.ts` | 30-day retention, days-until-purge |
| `github-storage.test.ts` | Sync + delete behavior (reference for SyncEngine) |

Additional native tests:

- Integration: write task → read file from disk → parse → assert fields match.
- Manual checklist: onboarding, external edit in Files app, conflict scenario, offline outbox flush.

---

## Explicitly NOT in v1

- Hosted task database
- Push notifications
- Auto-apply AI edits without user confirm
- Team boards / multi-user tasks
- Dependencies / priority graphs
- MCP / agents UI
- Dropbox storage (web-only; not needed for native v1)
- Supabase sign-in (deferred to phase 2)

---

## Key Reference Files (TypeScript Monorepo)

| Area | Path |
|---|---|
| Task schema | `packages/task-core/src/schema.ts` |
| Markdown I/O | `packages/task-core/src/markdown.ts` |
| Sync engine | `packages/task-core/src/storage/markdown-storage-adapter.ts` |
| Dropbox client | `packages/task-core/src/storage/dropbox-client.ts` |
| GitHub client | `packages/task-core/src/storage/github-client.ts` |
| Web persist | `apps/web/src/lib/persist-task.ts` |
| Web sync hook | `apps/web/src/hooks/useSync.ts` |
| Web UI shell | `apps/web/src/components/AppShell.tsx` |
| Task filters | `apps/web/src/lib/task-filters.ts` |
| Original design | `docs/superpowers/specs/2026-05-23-guidestoop-design.md` |
| Agent invariants | `AGENTS.md` |

---

## macOS Readiness

Build decisions that pay off when macOS target is added:

- `GuidestoopCore` and `GuidestoopStorage` packages have zero SwiftUI imports.
- `StorageAdapter` protocol is platform-agnostic.
- iPad layouts use split-view patterns compatible with macOS column navigation.
- Security-scoped bookmarks work on macOS with the same API.
- `GuidestoopMac` target imports packages and adds platform-specific chrome (menu bar, window management).
