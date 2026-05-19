# Code Signing & Notarization — ClaudeMeterPro

This document explains how to sign and notarize ClaudeMeterPro so it installs without Gatekeeper warnings on any Mac.

---

## Prerequisites

- Active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year)
- Xcode Command Line Tools: `xcode-select --install`

---

## 1. Create a Developer ID Application Certificate

1. Open **Xcode → Settings → Accounts**, sign in with your Apple ID.
2. Click **Manage Certificates → +** and choose **Developer ID Application**.
3. Xcode creates and installs the certificate into your login keychain automatically.

Verify it is visible:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Copy the full identity string, e.g.:
```
Developer ID Application: Your Name (XXXXXXXXXX)
```

---

## 2. Local Build — Sign & Notarize

### 2a. Set up a notarization keychain profile (one-time)

App-specific passwords expire; a keychain profile is more durable:

```bash
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "your@email.com" \
  --team-id "XXXXXXXXXX"
# Prompts for an app-specific password from appleid.apple.com
```

### 2b. Build, sign, and notarize

```bash
DEVELOPER_ID="Developer ID Application: Your Name (XXXXXXXXXX)" \
NOTARY_KEYCHAIN_PROFILE="notary-profile" \
bash scripts/build-dmg.sh
```

Or using username/password directly:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (XXXXXXXXXX)" \
APPLE_ID="your@email.com" \
TEAM_ID="XXXXXXXXXX" \
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
bash scripts/build-dmg.sh
```

The script handles signing, DMG creation, notarization submission, waiting, and stapling.

### 2c. Verify the result

```bash
# Gatekeeper check
spctl --assess --type exec --verbose ClaudeMeterPro.app

# Notarization staple
xcrun stapler validate ClaudeMeterPro-v*.dmg

# Signature details
codesign -dv --verbose=4 ClaudeMeterPro.app
```

A clean output from `spctl` looks like:
```
ClaudeMeterPro.app: accepted
source=Notarized Developer ID
```

---

## 3. CI/CD — GitHub Actions

The workflow at `.github/workflows/release.yml` builds, signs, notarizes, and uploads the DMG automatically on any `v*` tag push.

### Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID` | `Developer ID Application: Your Name (XXXXXXXXXX)` |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` export (see below) |
| `DEVELOPER_ID_CERTIFICATE_P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_ID` | Your Apple ID email |
| `TEAM_ID` | 10-character team ID from developer.apple.com |
| `APP_PASSWORD` | App-specific password from appleid.apple.com |

### Exporting the certificate as a .p12

1. Open **Keychain Access → My Certificates**.
2. Right-click **Developer ID Application: Your Name** → **Export**.
3. Choose `.p12` format and set a strong password.
4. Base64-encode it for the GitHub secret:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
# Paste into the DEVELOPER_ID_CERTIFICATE_P12_BASE64 secret
```

### Triggering a signed release

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build, sign, notarize, and attach the DMG to the release automatically.

---

## 4. Entitlements

The app uses `ClaudeMeterPro/ClaudeMeterPro.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.claudemeterpro.shared</string>
</array>
```

Sandbox is disabled because the app monitors system-level Claude API usage. If Apple requires sandboxing in the future, network client access is already declared.

---

## 5. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `CSSMERR_TP_NOT_TRUSTED` on codesign | Certificate chain incomplete; re-import from Keychain Access |
| Notarization status `Invalid` | Check submission log: `xcrun notarytool log <submission-id>` |
| Gatekeeper still warns after staple | Staple validation failed; re-run `xcrun stapler staple` then `validate` |
| CI: `errSecInternalComponent` on import | Keychain not unlocked; check the unlock step in release.yml |
| `The executable does not have the hardened runtime` | Ensure `--options runtime` is passed to `codesign` (already in build-dmg.sh) |
