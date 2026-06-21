# Guidestoop (native)

Calm, markdown-native task manager for iOS. Tasks are YAML-frontmatter `.md` files in a user-owned iCloud Drive folder.

**v1.0** — iOS app with iCloud Drive sync, Now/List/Day views, and offline outbox.

## Requirements

- Xcode 16+ (iOS 17 SDK)
- iCloud Drive enabled on device/simulator for sync testing

## Project layout

```
Guidestoop.xcworkspace          # Open this in Xcode
Apps/GuidestoopIOS/             # iOS app shell
Packages/GuidestoopCore/        # Models, markdown, sync engine
Packages/GuidestoopStorage/     # iCloud adapter, folder watching
docs/superpowers/               # Design spec and implementation plan
```

## Build & run

```bash
# Open workspace
open Guidestoop.xcworkspace

# Or build from CLI
xcodebuild -workspace Guidestoop.xcworkspace -scheme GuidestoopIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

On first launch the app auto-creates `iCloud Drive/Guidestoop/` (with retry while iCloud initializes). You can also pick a custom folder during onboarding.

## Tests

```bash
swift test --package-path Packages/GuidestoopCore     # 31 unit tests
swift test --package-path Packages/GuidestoopStorage  # integration round-trip
```

## v1 features

- **Now** — daily focus view with energy level (low/medium/high) and configurable task limits
- **List** — all tasks with inbox/today/done/trash filters, search, and tags
- **Day** — timeline for scheduled and focus tasks
- **Task detail** — form + markdown preview; high priority flag
- **iCloud sync** — markdown files, conflict resolution, external edit detection, offline outbox
- **Settings** — folder location, manual sync, appearance (light/dark/system), energy limits

## Manual QA checklist

- [ ] First launch auto-configures iCloud `Guidestoop/` folder
- [ ] Add task from Now tab → `.md` file in iCloud
- [ ] Edit task in app → file updated on disk
- [ ] Edit file in Files app → app re-syncs
- [ ] Conflict: edit same task on two devices → banner → resolve
- [ ] Trash: delete → restore → permanent delete; 30-day retention
- [ ] Offline: edit with airplane mode → outbox indicator → sync on reconnect
- [ ] Energy picker limits tasks shown on Now tab
- [ ] High priority sorts to top; toggle in detail or swipe on Now

## Docs

- [Design spec](docs/superpowers/specs/2026-06-20-guidestoop-native-swift-design.md)
- [Implementation plan](docs/superpowers/plans/2026-06-20-guidestoop-native-swift.md)

## Phase 2 (not yet implemented)

- Kanban view
- GitHub as alternative storage provider
- Supabase OAuth when GitHub connects
