# Guidestoop (native)

Calm, markdown-native task manager for iOS. Tasks are YAML-frontmatter `.md` files in a user-owned iCloud Drive folder.

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

Run the **GuidestoopIOS** scheme on a simulator or device. On first launch, pick the default `Guidestoop/` folder or choose a custom iCloud folder.

## Tests

```bash
swift test --package-path Packages/GuidestoopCore    # 29 unit tests
swift test --package-path Packages/GuidestoopStorage # integration round-trip
```

## Manual QA checklist

- [ ] Onboarding: default folder + custom folder picker
- [ ] Quick-add creates `.md` file in iCloud folder
- [ ] Edit task in app → file updated on disk
- [ ] Edit file in Files app → app re-syncs within ~1s
- [ ] Conflict: edit same task on two devices → banner → resolve
- [ ] Trash: delete → restore → permanent delete; 30-day retention
- [ ] Offline: edit with airplane mode → outbox indicator → sync on reconnect
- [ ] List tabs, search, and tag filters
- [ ] Kanban drag changes status
- [ ] Day view shows scheduled + focus tasks
- [ ] Settings: manual sync, appearance, change folder

## Docs

- [Design spec](docs/superpowers/specs/2026-06-20-guidestoop-native-swift-design.md)
- [Implementation plan](docs/superpowers/plans/2026-06-20-guidestoop-native-swift.md)

## Phase 2 (not yet implemented)

- GitHub as alternative storage provider
- Supabase OAuth when GitHub connects
