# Setting up the macOS app + APNs

This is the part I can't do for you from here — it needs your Apple
Developer account and a local Xcode. The three files in
`ConDaoFerryWatch/` are ready to drop in once the project exists.

## 1. Enroll in the Apple Developer Program
developer.apple.com → Enroll → $99/year. Takes a few hours to a day or two
to activate.

## 2. Create the Xcode project
- Xcode → File → New → Project → macOS → App
- Product Name: `ConDaoFerryWatch`
- If Xcode offers a choice of app lifecycle, pick the **AppKit App
  Delegate** option (not SwiftUI App lifecycle) so `AppDelegate.swift`
  is used directly. If your Xcode version only offers the SwiftUI
  lifecycle, that's fine too — just wrap this delegate with
  `@NSApplicationDelegateAdaptor(AppDelegate.self)` in your `App` struct.
- Note the **Bundle Identifier** you choose (e.g.
  `com.yourname.condaoferrywatch`) — you'll need it for the
  `APNS_BUNDLE_ID` secret.

## 3. Replace the generated files
Swap in the three files from this folder:
- `AppDelegate.swift`
- `Info.plist`
- `ConDaoFerryWatch.entitlements`

## 4. Enable Push Notifications capability
Project target → **Signing & Capabilities** →
- Select your Team (this is what makes the Team ID available)
- **+ Capability** → **Push Notifications**
- **+ Capability** → **Background Modes** → check **Remote notifications**
  (helps delivery reliability, not strictly required)

## 5. Build and run once, capture the device token
Run the app (⌘R). Grant the notification permission prompt. Check
Xcode's console (or Console.app, filtered to "ConDaoFerryWatch") for a
line like:

```
APNs device token: 8a3f9c2e1b...
```

Copy that hex string — it's your `APNS_DEVICE_TOKEN`.

*(If you ever reinstall or the token changes, redo this step and update
the GitHub secret.)*

## 6. Create an APNs Auth Key
developer.apple.com → **Certificates, IDs & Profiles** → **Keys** → **+**
- Check **Apple Push Notifications service (APNs)**
- Register, then **download the `.p8` file immediately** — Apple only
  lets you download it once
- Note the **Key ID** shown on that page
- Your **Team ID** is on the Membership page (top-right of the developer
  portal)

## 7. Add GitHub Actions secrets
In your repo → **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|---|---|
| `APNS_KEY_ID` | Key ID from step 6 |
| `APNS_TEAM_ID` | Team ID from step 6 |
| `APNS_AUTH_KEY` | full contents of the `.p8` file, including the `-----BEGIN/END PRIVATE KEY-----` lines |
| `APNS_DEVICE_TOKEN` | hex string from step 5 |
| `APNS_BUNDLE_ID` | bundle identifier from step 2 |

## 8. Test end-to-end
Push this whole repo to GitHub, go to the **Actions** tab, and run
"Con Dao ferry smoothness check" manually (`workflow_dispatch`) before
waiting for the schedule. Check the run log for `Sent: ...` — if you see
an APNs error instead, it's almost always a mismatched bundle ID/topic or
a token registered against the wrong environment (sandbox vs production —
see the note in `apns_push.py`).

## About sandbox vs. production
A plain Xcode Debug build registers with APNs' **sandbox** environment.
The workflow is already set to `APNS_ENV: sandbox` to match. This works
indefinitely for personal use — you don't need Developer ID signing or
notarization just to receive pushes on your own Mac. Only switch to
production if you later archive and distribute a signed release build.
