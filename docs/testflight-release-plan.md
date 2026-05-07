# iOS Release Guide

How to ship a new BetterFTP build to TestFlight / the App Store. One-time
setup (Apple Developer account, certificates, App Store Connect record,
bundle ID, signing, privacy manifest, ITSAppUsesNonExemptEncryption) is
already done — this doc is just the recurring per-release loop.

---

## Per-release steps

### 1. Bump the build number

Edit `betterftp/pubspec.yaml`:

```yaml
version: 1.0.0+2   # marketing version stays, build number must increase
```

App Store Connect rejects duplicate build numbers within the same marketing
version. Bump on every upload.

### 2. Build the IPA

```bash
cd betterftp
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

Output: `betterftp/build/ios/ipa/betterftp.ipa`

### 3. Upload to App Store Connect

Two options — pick one.

**Transporter** (simplest):

1. Open the Transporter app (free on the Mac App Store).
2. Drag in `build/ios/ipa/betterftp.ipa` → Deliver.

**Xcode Organizer**:

1. In Xcode: Product → Archive (scheme Runner, destination "Any iOS Device").
2. Organizer → Distribute App → App Store Connect → Upload.

Either way, the build appears in App Store Connect → TestFlight in ~5 min,
then takes 10–30 min to finish "Processing".

### 4. Distribute via TestFlight

Once the build shows "Ready to Submit":

- **Internal testers**: TestFlight → Internal Testing → toggle the new build
  into the group. No review required, testers get it within minutes.
- **External testers**: toggle into the external group + fill in "What to
  Test". First build per marketing version triggers Beta App Review
  (24–48h); subsequent builds with the same "What to Test" copy usually
  skip review.

Keep "What to Test" concrete, e.g.: "Pair a Wahoo Kickr Core, run the 20-min
ramp, confirm FTP result matches expectations."

### 5. (App Store release) Submit for review

When promoting a TestFlight build to the public App Store:

1. App Store Connect → App Store tab → select the build for the version.
2. Update "What's New in This Version".
3. Submit for Review.

Apple review typically takes 24–48h.

---

## Notes

- `ITSAppUsesNonExemptEncryption=false` is set in `Info.plist` — no per-build
  export-compliance question.
- `PrivacyInfo.xcprivacy` is in place; only revisit if Apple rejects an
  upload citing it.
- Bundle ID is `cc.betterftp.app`. Don't change it — re-creating the App
  Store Connect record means losing all TestFlight history.
