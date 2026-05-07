# Android Release Guide

How to build a signed Android APK and publish it as a GitHub Release. The
website's **Download Android .apk** button points at
`https://github.com/niecore/betterftp/releases/latest/download/app-release.apk`,
so the asset filename **must stay `app-release.apk`**.

The upload keystore (`~/keys/betterftp-upload.jks`) and
`betterftp/android/key.properties` are already in place. Gradle picks them
up automatically via [`android/app/build.gradle.kts`](../betterftp/android/app/build.gradle.kts);
if `key.properties` is missing, the build falls back to debug signing.

---

## Per-release steps

### 1. Bump the version

Edit `betterftp/pubspec.yaml`:

```yaml
version: 1.0.1+2   # <semver>+<build number>
```

The build number (`+2`) **must increase** for every release.

### 2. Build the APK

```bash
cd betterftp
flutter clean
flutter pub get
flutter build apk --release
```

Output: `betterftp/build/app/outputs/flutter-apk/app-release.apk`

Sanity check it's signed with the release key, not debug:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The `Owner:` line should be `CN=Nico Müller, O=BetterFTP, OU=Development, C=DE`
(not `CN=Android Debug`).

### 3. Tag the commit

```bash
git tag v1.0.1
git push origin v1.0.1
```

### 4. Create the GitHub Release

```bash
gh release create v1.0.1 \
  betterftp/build/app/outputs/flutter-apk/app-release.apk \
  --title "v1.0.1" \
  --notes "What's new in this release."
```

Or via the web UI: <https://github.com/niecore/betterftp/releases/new> —
select the tag, drag the APK in, publish.

### 5. Verify the website link

Open <https://betterftp.cc> in a browser, click **Download Android .apk**,
confirm the APK downloads. The `releases/latest/download/...` URL
auto-resolves to the most recent published release.

---

## Signing key fingerprint

Public-facing reference. Anyone downloading an APK can verify it was signed
by the same key as previous releases by running `apksigner verify --print-certs`
and matching the SHA-256 against the value below.

| Algorithm | Fingerprint |
|---|---|
| SHA-256 | `0e27365da121afe223e983ffb5214322ccf86c0ed9f51f6c6c862c45615d39e4` |
| SHA-1   | `7f91fa82449c763206a36cc92f13aeb153552d20` |
| MD5     | `2a2f7508bba5b1b324fcb0d243c30c5f` |

Distinguished name: `CN=Nico Müller, O=BetterFTP, OU=Development, C=DE`.
Generated 2026-05-05, valid 10000 days.

If a future APK fingerprint does **not** match, the build did not come from
the original keystore.

## Notes

- **Keep the asset filename `app-release.apk`** — that's what the website
  links to. If you rename it, also update [website/index.html](../website/index.html).
- **Backup the keystore** (`~/keys/betterftp-upload.jks`) to a password
  manager or encrypted offsite storage. If you lose it, you cannot ship
  signed updates to existing users.
- **App Bundle (`.aab`) vs APK**: APK is correct for direct sideloading.
  Switch to `flutter build appbundle` only if/when publishing to the Play
  Store.
