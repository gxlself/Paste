# iOS distribution (companion to macOS)

The iOS app (**Paste-iOS**) and **Paste-Keyboard** extension work with the Mac app when **iCloud sync** is enabled on both (same Apple ID). See [SETUP.md](../SETUP.md) for signing and App Group setup.

## Why it’s not like macOS

Apple does **not** allow arbitrary users to install an `.ipa` downloaded from the web (unlike macOS). Valid options:

| Method | Who can install | Best for |
|--------|-----------------|----------|
| **App Store** | Anyone | Public release |
| **TestFlight** | Up to 10,000 external testers (90-day builds) | Beta / early access |
| **Ad Hoc** | Only devices whose **UDID** you register (max 100/year) | A few trusted devices |

So **GitHub Releases + .ipa for “everyone” is not viable** unless you use TestFlight or the App Store.

---

## Prerequisites

- **Paid Apple Developer Program** ($99/year) — required for TestFlight and App Store distribution to real devices.
- **Paste-iOS** and **Paste-Keyboard** use the same **Team** and **App Group** (`group.gxlself.paste-tool`); confirm in **Signing & Capabilities** (see [SETUP.md](../SETUP.md)).

---

## Build & upload (TestFlight or App Store)

1. In Xcode, select scheme **Paste-iOS**.
2. Destination: **Any iOS Device (arm64)** (not a simulator).
3. **Product → Archive**.
4. In **Organizer**, select the archive → **Distribute App**.
5. Choose **App Store Connect** → follow the wizard (upload).

Then in [App Store Connect](https://appstoreconnect.apple.com):

- **TestFlight**: After processing, add internal/external testers and share the public link or send invites. This repo’s public link (when enabled in App Store Connect): **https://testflight.apple.com/join/2UKC5P27**
- **App Store**: Create the app listing, submit for review, release.

The archive includes the embedded **Paste-Keyboard** extension if **Embed Foundation Extensions** is set correctly (see SETUP.md).

---

## Command-line archive (optional)

Replace team/signing as needed; often easier to use Xcode Archive first.

```bash
xcodebuild archive \
  -project Paste.xcodeproj \
  -scheme "Paste-iOS" \
  -configuration Release \
  -archivePath build/Paste-iOS.xcarchive \
  -destination 'generic/platform=iOS'
```

Export for App Store Connect (needs an **ExportOptions.plist** with `method: app-store`):

```bash
xcodebuild -exportArchive \
  -archivePath build/Paste-iOS.xcarchive \
  -exportPath build/ios-export \
  -exportOptionsPlist ExportOptions.plist
```

Upload the resulting `.ipa` with **Transporter** or `xcrun altool` / **notarytool** flow as documented by Apple.

---

## Remind users (keyboard)

After install, users must enable the keyboard and **Allow Full Access** for the extension to read shared history — see [SETUP.md §4](../SETUP.md).

---

## Summary

- **Let many people try the iOS companion:** use **TestFlight** (or ship on the **App Store**).
- **Do not expect** a single `.ipa` on GitHub to work for random downloaders; use Apple’s channels instead.
