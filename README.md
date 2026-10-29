# CopyShelf

CopyShelf is a local clipboard history app for macOS. It saves plain text on your Mac, lets you search and pin entries, and can copy or paste a selection back into the previously focused app.

- Capture starts paused and requires your consent. You can pause capture and exclude apps from the menu bar.
- Open history with Control–Command–Shift–V; the shortcut can be changed in the menu.
- Automatic paste requires Accessibility access. Copy Selected is available as a fallback.
- Text stays in an app-owned local database. There are no accounts, sync, analytics, or network services.
- File URLs are ignored; image and file history are not supported.

Requires macOS 14 or later. The app is an early personal project; live behavior can vary across apps and macOS versions.

## Build and run

Install Xcode and its command-line tools, then:

```sh
xcodebuild test -project CopyShelf.xcodeproj -scheme CopyShelfCore -derivedDataPath build/DerivedData
ALLOW_ADHOC_SIGN=1 ./scripts/build.sh Release
open build/DerivedData/Build/Products/Release/CopyShelf.app
```

The ad-hoc build is suitable for local evaluation. macOS permission grants may not persist across ad-hoc rebuilds. For a stable local identity, review and run `./scripts/create-signing-cert.sh` once, then `./scripts/build.sh Release`. The certificate script modifies the login keychain and trust settings and may request your password. Do not use its `--force` option unless you deliberately want to replace the identity and invalidate existing grants. `./scripts/install.sh` installs the signed release to `/Applications/CopyShelf.app`; review it before running it. It does not grant Accessibility access.

XcodeGen is optional; the generated Xcode project is included. Run `xcodegen generate` after changing `project.yml` or adding source files.

## Privacy and storage

CopyShelf stores its database in `~/Library/Application Support/CopyShelf/CopyShelf.store`. Text history is retained locally; by default up to 200 unpinned entries are kept, while pinned entries are exempt. Clear History removes text entries including pins. SQLite files, free space, system snapshots, and backups can retain deleted data, so clearing is not secure erasure.

If upgrading from an earlier development version, the app keeps its compatible database schema and may retain a `pre-v2-backup.store` alongside the database. Earlier image or file-reference records are preserved but hidden and are not removed by Clear History. Rolling back an app bundle alone does not roll back the database.

## License

[MIT](LICENSE).
