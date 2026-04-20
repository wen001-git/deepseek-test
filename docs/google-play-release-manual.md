# Google Play Release Manual for `shortvideoai`

This manual explains what must be completed before publishing the Android app to Google Play, and how to operate the release from local build through Play Console submission.

It is tailored to the current codebase:

- Android package ID: `com.shortvideoai.shortvideoai`
- App name in code: `短视频创作助手` / `Short Video AI`
- Subscription product IDs:
  - `creator_pro_monthly`
  - `creator_pro_plus_monthly`
- Backend mobile subscription verification env vars:
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_SERVICE_ACCOUNT_JSON`

## 1. Scope and Release Goal

The goal of this document is to get the Flutter Android app from the current repository state to a Google Play production release that:

- installs from Play without signing or integrity issues
- passes Play Console review and policy checks
- supports Google Play subscriptions in production
- uses the production backend
- supports English by default, with Simplified Chinese available in-app

This manual assumes:

- you are publishing the Android app only
- the Play Console account is a new personal account, so testing gates may apply before production
- Google Play Billing is used only for digital app entitlements

## 2. Current Repo State

The current codebase already includes:

- Flutter Android app structure under `mobile/`
- Android manifest with `INTERNET` and Billing permission
- Play Billing integration in the mobile app
- backend subscription verification endpoint at `/api/mobile/verify-subscription`
- release signing support via `mobile/android/key.properties`

The current codebase is **not production-ready yet** for Play release because of the following operational gaps:

- release builds fall back to debug signing if `key.properties` is missing
- the mobile billing flow still needs production verification validation against real Play purchase tokens
- Play Console metadata, compliance declarations, and policy assets are not represented in the repo
- production billing backend credentials must still be configured

## 3. Pre-Release Checklist

Complete every item in this section before uploading a production build.

### 3.1 Android identity and signing

1. Confirm the permanent package name:
   - `com.shortvideoai.shortvideoai`
2. Create an upload keystore and keep it in a secure location.
3. Create `mobile/android/key.properties` from `mobile/android/key.properties.template`.
4. Fill in:
   - `storeFile`
   - `storePassword`
   - `keyAlias`
   - `keyPassword`
5. Verify that the release build is signed with the real upload key.
6. Do not publish any build that uses debug signing.

Recommended keystore generation command:

```bash
cd mobile/android
keytool -genkey -v -keystore app/keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### 3.2 Versioning

Before every Play upload:

1. Increment the app version in `mobile/pubspec.yaml`.
2. Ensure the generated Android `versionCode` is higher than the previous upload.
3. Ensure the user-facing `versionName` is correct for the release notes.

### 3.3 Target API and build compliance

Google Play target API requirements change over time. Verify the current requirement on release day.

At the time this manual was prepared, Google states:

- starting **August 31, 2025**, new apps and app updates must target **Android 15 / API 35** or higher

Before release:

1. Run a release build.
2. Confirm the final target SDK used by the Android build satisfies the current Play requirement.
3. Re-check the official Play target API page on the release date.

Reference:

- https://developer.android.com/google/play/requirements/target-sdk

### 3.4 Production backend and billing verification

The backend currently expects:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_SERVICE_ACCOUNT_JSON`

Before production billing is enabled:

1. Create a Google Cloud service account with Android Publisher access.
2. Generate the service account JSON credentials.
3. Store the JSON securely on the backend host.
4. Set:
   - `GOOGLE_PLAY_PACKAGE_NAME=com.shortvideoai.shortvideoai`
   - `GOOGLE_SERVICE_ACCOUNT_JSON=/absolute/path/to/service-account.json`
5. Restart the backend with the production env vars applied.

Important:

- If these env vars are absent, the backend currently accepts a dev-mode subscription token path.
- Do not ship production monetization while the backend is still in dev verification mode.

### 3.5 Google Play subscription setup

Create the following subscriptions in Play Console:

- `creator_pro_monthly`
- `creator_pro_plus_monthly`

For each subscription:

1. Create the subscription product.
2. Create at least one base plan.
3. Set pricing.
4. Set country or region availability.
5. Decide whether to offer:
   - free trial
   - intro pricing
   - standard recurring monthly plan only
6. Activate the base plan.

Keep the product IDs exactly aligned with the app code and backend mapping.

### 3.6 Privacy, policy, and reviewer access

Prepare the following before any serious review submission:

1. Privacy policy URL
2. Contact email
3. App access instructions for reviewer login
4. Test account credentials for Play review if login is required
5. Content rating questionnaire inputs
6. Data safety form inputs

The privacy policy must be:

- public
- live
- non-geofenced
- not a PDF
- clearly labeled as a privacy policy

References:

- https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- https://support.google.com/googleplay/android-developer/answer/10787469?hl=en

## 4. Play Console Setup

## 4.1 Create the app

In Play Console:

1. Create a new app.
2. Set the default store language.
3. Set app type to `App`.
4. Set distribution to `Free` or `Paid` as required.
5. Add the developer contact email.
6. Accept the developer declarations and Play App Signing terms.

Reference:

- https://support.google.com/googleplay/android-developer/answer/9859152?hl=en

## 4.2 Enroll in Play App Signing

Use Play App Signing.

Operational steps:

1. Upload the app bundle signed with your upload key.
2. Allow Google to manage the app signing key.
3. Save the upload key securely.
4. Export and store the upload certificate fingerprint for future integrations.

Reference:

- https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN

## 4.3 Store listing assets

Prepare:

- app name
- short description
- full description
- app icon
- phone screenshots
- feature graphic
- optional promo video

Localization required for this app:

- English
- Simplified Chinese

Recommended screenshot set:

1. Login screen
2. Home / toolbox screen
3. Script generation screen
4. Subscription / paywall screen
5. Profile / language switch screen

Reference:

- https://support.google.com/googleplay/android-developer/answer/1078870?hl=en

## 4.4 App content and policy declarations

Complete all required sections in Play Console:

1. Privacy policy
2. App access
3. Ads declaration
4. Content rating
5. Data safety
6. Permissions declaration, if triggered by final manifest or bundled dependencies

References:

- Content rating: https://support.google.com/googleplay/android-developer/answer/9898843?hl=en
- Permissions declaration: https://support.google.com/googleplay/android-developer/answer/9214102?hl=en-EN

## 5. Local Build and Validation Procedure

All release candidates must be validated locally before uploading to Play.

### 5.1 Install dependencies

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter pub get
```

### 5.2 Run static checks

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter analyze
```

Notes:

- The repo currently has analyzer warnings that should be reviewed before production.
- Do not treat a warning-heavy build as automatically production-ready.

### 5.3 Build the Android App Bundle

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter build appbundle --release
```

Expected output:

- `build/app/outputs/bundle/release/app-release.aab`

### 5.4 Verify release assumptions

Before upload, confirm:

- the build is signed with the real upload key
- the app starts on a physical Android device
- the backend URL points to production
- login works
- quota handling works
- subscription products load from Play
- purchase flow starts correctly
- restore flow behaves correctly

## 6. Testing Track Strategy

Because this manual assumes a **new personal Play Console account**, do not plan to jump directly to production.

Use this track order:

1. Internal testing
2. Closed testing
3. Production

Reference:

- https://support.google.com/googleplay/android-developer/answer/9845334

## 6.1 Internal testing

Use internal testing first for fast validation.

Recommended internal test scope:

- up to 100 testers
- team members only
- billing testers included

Validate:

1. installation from Play
2. sign in
3. sign out
4. script generation
5. subscription product loading
6. purchase flow
7. restore purchases
8. backend entitlement refresh

## 6.2 Closed testing

Promote only after internal testing passes.

Closed testing should validate:

1. wider device coverage
2. Play install/update behavior
3. login on production backend
4. end-to-end paid subscription behavior
5. store listing visibility and metadata quality
6. reviewer instructions are correct

## 6.3 Production eligibility note

New personal developer accounts may have extra production release testing requirements enforced by Google Play.

Before planning a production date:

1. Confirm the current personal-account production eligibility requirement in Play Console.
2. Ensure the testing period and tester requirements, if shown in your account, are fully completed.
3. Do not assume an internal test alone is enough for production eligibility.

## 7. Subscription Operations

## 7.1 License testing

Before using real customer payments:

1. Add billing test accounts in Play Console.
2. Install from a Play testing track, not only from local sideload.
3. Use test accounts to validate:
   - successful purchase
   - canceled purchase
   - restore
   - renewal state handling
   - expired or revoked entitlement behavior

## 7.2 Backend operational verification

For every billing test, verify backend logs for:

- received product ID
- received purchase token
- Google Play verification success
- correct tier activation
- correct expiration date persistence

If verification fails:

1. confirm the package name matches
2. confirm product IDs match Play Console exactly
3. confirm service account permissions are correct
4. confirm the tester account is eligible for the track and purchase path

## 8. Play Review Readiness

Before production submission, ensure the reviewer can use the app without confusion.

Prepare:

1. a review account username
2. a review account password
3. a short reviewer instruction note
4. explanation of any paywall or entitlement logic

Suggested reviewer note template:

```text
Test login:
Username: <review_account>
Password: <review_password>

After login:
1. Open Toolbox
2. Open Script Writing
3. Generate content
4. Open Profile to switch language if needed
5. Subscription plans are shown on the Upgrade screen
```

If the app requires a paid entitlement to view important areas, provide a testable path for the reviewer.

## 9. Release Day Procedure

Use this sequence on release day.

### 9.1 Final preflight

1. Re-check the current Play target API requirement.
2. Confirm backend production env vars are active.
3. Confirm Play subscriptions are active.
4. Confirm privacy policy URL is still live.
5. Confirm release notes are ready.

### 9.2 Build and upload

1. Build the release AAB.
2. Upload to the selected track in Play Console.
3. Add release notes.
4. Complete all unresolved Play Console tasks.
5. Submit for review.

### 9.3 After submission

Monitor:

- Play Console review messages
- Android vitals
- crashes and ANRs
- billing failures
- backend subscription verification errors
- login and quota complaints

## 10. Rollback and Hotfix Procedure

If the production release has a critical issue:

1. Stop rollout if staged rollout is active.
2. Prepare a hotfix build with a higher version code.
3. Rebuild and upload a corrected AAB.
4. Update release notes with a brief fix summary.
5. If billing is affected, notify support and review affected user entitlements.

## 11. Final Go/No-Go Checklist

Release is **GO** only if all items below are true:

- upload keystore exists and is secure
- release build does not use debug signing
- target API meets current Play requirement
- Play App Signing is enabled
- privacy policy is live
- Data safety is completed
- content rating is completed
- app access instructions are prepared
- internal testing passed
- closed testing passed
- personal-account production gate, if present, has been satisfied
- subscriptions exist and are active in Play Console
- backend verifies real Play purchases in production mode
- reviewer login works
- production backend is stable

If any of the above is false, the release is **NO-GO**.

## 12. References

- Google Play target API requirements:
  - https://developer.android.com/google/play/requirements/target-sdk
- Create and set up your app:
  - https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
- Play App Signing:
  - https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN
- Testing tracks:
  - https://support.google.com/googleplay/android-developer/answer/9845334
- Data safety:
  - https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Privacy policy:
  - https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- Content rating:
  - https://support.google.com/googleplay/android-developer/answer/9898843?hl=en
- Permissions declaration:
  - https://support.google.com/googleplay/android-developer/answer/9214102?hl=en-EN
- Store listing assets:
  - https://support.google.com/googleplay/android-developer/answer/1078870?hl=en
- Play Billing overview:
  - https://developer.android.com/google/play/billing/
- Subscriptions:
  - https://developer.android.com/google/play/billing/subscriptions.html
