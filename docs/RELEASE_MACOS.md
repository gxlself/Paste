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
