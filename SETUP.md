# Project Setup Guide

This guide covers the one-time Xcode configuration steps required before you can build and run the iOS targets. The macOS target (`Paste`) works out of the box with no additional setup.

---

## Prerequisites

- macOS 13.0 Ventura or later
- Xcode 15.0 or later
- An Apple Developer account (free account is sufficient for simulator; paid account required for device deployment)

---

## 1. Signing & Capabilities

Because the iOS app and its keyboard extension share an App Group, you must configure signing in Xcode before the first build.

### Paste-iOS target

1. Open `Paste.xcodeproj` in Xcode.
2. In the Project Navigator, select the project file (blue icon at the top).
3. In the TARGETS list, select **Paste-iOS**.
4. Click the **Signing & Capabilities** tab.
5. Set **Team** to your Apple Developer team.
6. Verify that **App Groups** shows `group.gxlself.paste-tool`.
   - If the capability is missing: click **+ Capability** → **App Groups** → add `group.gxlself.paste-tool`.

### Paste-Keyboard target

1. In the TARGETS list, select **Paste-Keyboard**.
2. Click the **Signing & Capabilities** tab.
3. Set **Team** to the same team as Paste-iOS.
4. Verify that **App Groups** shows `group.gxlself.paste-tool`.
   - If missing: click **+ Capability** → **App Groups** → add `group.gxlself.paste-tool`.

---

## 2. Embed Foundation Extensions

1. Select the **Paste-iOS** target.
2. Click the **Build Phases** tab.
3. Expand **Embed Foundation Extensions**.
4. Confirm that `Paste-Keyboard.appex` is listed.
   - If missing: click `+` → select `Paste-Keyboard`.

---

## 3. Running the Project

| Target | Scheme | Destination |
|---|---|---|
| macOS clipboard manager | **Paste** | My Mac |
| iOS companion app | **Paste-iOS** | iPhone / iPad simulator or device |

Select the desired scheme from the Xcode toolbar and press `⌘R`.

---

## 4. Keyboard Extension — Full Access

The keyboard extension reads clipboard history from the shared App Group CoreData store. This requires the user to grant **Full Access** to the keyboard:

1. On the device or simulator, open **Settings → General → Keyboard → Keyboards → Add New Keyboard**.
2. Select **Paste**.
3. Tap **Paste** in the keyboard list and enable **Allow Full Access**.

Without Full Access, the keyboard extension can display the UI but cannot read from the shared database.

---

## 5. iCloud Sync (optional)

iCloud sync uses `NSPersistentCloudKitContainer` and requires an iCloud-capable provisioning profile. If you do not need sync:

- In **Paste** (macOS) target → **Signing & Capabilities**, you can remove the **iCloud** capability.
- In `AppSettings`, the `iCloudSyncEnabled` flag defaults to `false`; sync will not activate unless the user turns it on.
