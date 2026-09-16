# macOS release artifacts (GitHub Releases)

Package **Paste.app** as a **.zip** and **.pkg** for users to download from the Releases page.

## 1. Fix `xcodebuild: command not found`

Install **full Xcode** from the App Store and point the CLI at it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

Open Xcode once and wait until “Installing additional components” finishes.  
If Xcode is not at `/Applications/Xcode.app`, use your actual path.

Verify:

```bash
xcodebuild -version
```

You should see the Xcode and build versions. **Command Line Tools alone are not enough** to build and sign the macOS app properly.

## 1b. Signing: why it must be Developer ID

The script **archives and exports with `method: developer-id`**, not a plain `xcodebuild build`.

CloudKit keeps two completely separate databases per container:

| Signing | CloudKit database |
|---------|-------------------|
| Apple Development profile | **Development** |
| Developer ID / App Store / TestFlight | **Production** |

A plain `xcodebuild build` with automatic signing picks the *Mac Team Provisioning Profile*
(development) and rewrites the `aps-environment` entitlement to `development` — even though
`PasteRelease.entitlements` asks for `production`. The released macOS app then syncs against the
Development database and **can never see records from the TestFlight/App Store iOS app**.

Prerequisites:

1. A **Developer ID Application** certificate for team `W8L8ZJ3N2P` in your keychain
   (Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application).
   The script refuses to build without it.
2. The CloudKit schema **deployed to Production**: <https://icloud.developer.apple.com> →
   container `iCloud.gxlself.paste-tool` → **Schema → Deploy Schema Changes**.
   `NSPersistentCloudKitContainer` creates record types automatically in Development only;
   Production never gets them until you deploy. Re-deploy after any Core Data model change.

After the build the script asserts the signed `aps-environment` is `production` and fails loudly
otherwise.

## 2. One-shot build (recommended)

From the repository root:

```bash
chmod +x scripts/build-macos-github-release.sh
./scripts/build-macos-github-release.sh
```

Outputs in **`dist/`**:

| File | Description |
|------|-------------|
| `Paste-<version>-macos.zip` | Unzip to get `Paste.app`; drag to **Applications** |
| `Paste-<version>-macos.pkg` | Double-click **Installer**; installs into **Applications** |

Upload the **zip** and/or **pkg** to GitHub → **Releases** → **Draft a new release** → attach binaries.

## 3. Xcode GUI (optional)

1. Scheme **Paste**, destination **My Mac**.
2. **Product → Archive**.
3. In Organizer: **Distribute App** → **Copy App** (or export), then zip manually if needed.

## 4. First launch for users

Without **notarization**, Gatekeeper may block the app. Mention in release notes:

- Drag **Paste** into **Applications** (zip) or use the pkg installer.
- First open: **Right-click Paste → Open** (avoid double-click the first time).

With an Apple Developer account, notarize via Xcode or `notarytool` after archive so users can open normally.

## 5. Command-line only (no script)

```bash
cd /path/to/paste
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath ./build/DerivedData build
```

Built app:

`build/DerivedData/Build/Products/Release/Paste.app`

Zip:

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/DerivedData/Build/Products/Release/Paste.app \
  dist/Paste-macos.zip
```

Pkg (installs to `/Applications`):

```bash
mkdir -p build/pkg_staging
ditto build/DerivedData/Build/Products/Release/Paste.app build/pkg_staging/Paste.app
pkgbuild --root build/pkg_staging \
  --identifier gxlself.paste-tool.macos.installer \
  --version 1.8.1 \
  --install-location /Applications \
  dist/Paste-macos.pkg
```

(Replace `1.8.1` with the marketing version you ship.)
