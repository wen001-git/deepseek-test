# Google Play Release Implementation Tasks for Claude Code / Codex

This document is a technical execution breakdown for continuing the Google Play release work inside this repository. It is intended for an implementation agent, not for Play Console operators.

## 1. Objective

Bring the Android app and backend to a release-ready technical state for Google Play by removing the highest-risk blockers identified in the release manual.

Primary outcome:

- the repo is technically ready for a human operator to complete Play Console setup, testing tracks, and final submission

## 2. Repo-Specific Facts to Respect

- Android app root: `mobile/`
- Package ID: `com.shortvideoai.shortvideoai`
- Billing product IDs:
  - `creator_pro_monthly`
  - `creator_pro_plus_monthly`
- Backend subscription verification endpoint:
  - `/api/mobile/verify-subscription`
- Production backend env vars:
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_SERVICE_ACCOUNT_JSON`
- Current release signing fallback still allows debug signing when `key.properties` is missing

## 3. Required Implementation Work

### Task A. Make release signing fail closed

Goal:

- release builds must fail if signing config is missing

Implementation:

1. Update `mobile/android/app/build.gradle.kts`.
2. Remove the behavior that falls back to debug signing for release builds.
3. Make release configuration require a valid `key.properties`.
4. Ensure the failure message clearly explains what file is missing and what to do next.

Acceptance criteria:

- `flutter build appbundle --release` fails clearly when `mobile/android/key.properties` is absent
- release build no longer signs with debug signing under any path

### Task B. Fix the Play purchase token path

Goal:

- the mobile app must send a real Play purchase token to the backend

Implementation:

1. Inspect the current purchase object used in the mobile billing flow.
2. Replace any incorrect use of `purchaseID` for server verification if that is not the real Play token.
3. Use the Play purchase verification token value exposed by the Flutter in-app purchase plugin for Android.
4. Keep the backend request payload shape as:
   - `purchase_token`
   - `product_id`
5. Preserve compatibility with existing backend endpoint naming.

Acceptance criteria:

- the mobile request to `/api/mobile/verify-subscription` contains a real Play purchase token
- the implementation is valid for production Play subscription verification

### Task C. Harden backend production verification mode

Goal:

- production misconfiguration must be visible and not silently behave like a valid billing setup

Implementation:

1. Review `mobile_api.py` verification flow.
2. Preserve dev-mode support only for explicit development environments.
3. Ensure production deployment paths fail loudly if:
   - `GOOGLE_PLAY_PACKAGE_NAME` is missing
   - `GOOGLE_SERVICE_ACCOUNT_JSON` is missing
4. Improve error messages so operators can diagnose configuration issues quickly.

Acceptance criteria:

- production billing does not silently accept fake tokens
- configuration errors are obvious from API responses and logs

### Task D. Add release environment configuration for backend URL

Goal:

- Android builds should not rely on a hardcoded production backend URL in code

Implementation:

1. Review `mobile/lib/core/constants/api_constants.dart`.
2. Replace the hardcoded `baseUrl` with a build-time configurable path.
3. Support at least:
   - production backend URL
   - local or staging backend URL
4. Choose one Flutter-compatible pattern and apply it consistently:
   - `--dart-define`
   - flavor-based config
5. Update the code so the app still has a sane default if no override is provided.

Acceptance criteria:

- the app can be built against production and non-production backends without code edits
- the build command for production is explicit and documented

### Task E. Reduce Android release-quality warnings with release impact

Goal:

- clean the warnings that are most likely to affect release reliability or reviewer experience

Implementation priorities:

1. Fix `paywall_screen.dart` async context misuse warning.
2. Replace deprecated `DropdownButtonFormField.value` usage with supported API.
3. Fix any warning directly tied to release-time instability or UI breakage.
4. Leave purely cosmetic lint cleanup for a separate pass if needed.

Acceptance criteria:

- `flutter analyze` shows fewer release-relevant warnings
- no known warning remains that risks billing, navigation, or release flow correctness

### Task F. Add release build documentation for engineers

Goal:

- an engineer can produce a signed AAB without guessing

Implementation:

1. Update or add repo docs in `docs/` or `mobile/README.md`.
2. Document:
   - keystore setup
   - release env configuration
   - release build command
   - output artifact path
3. Keep this technical and concise.

Acceptance criteria:

- a new engineer can build a signed release bundle from repo docs only

## 4. Suggested Execution Order

Recommended order:

1. Task A: release signing fail closed
2. Task B: Play purchase token fix
3. Task C: backend verification hardening
4. Task D: backend URL build-time config
5. Task E: release-relevant warning cleanup
6. Task F: engineer-facing release build documentation

Reasoning:

- signing and billing verification are the highest-risk Play blockers
- backend environment correctness must be fixed before reliable test-track billing
- config and warning cleanup should follow once the core release path is safe

## 5. Validation Commands

Use these commands during implementation:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter analyze
flutter build appbundle --release
```

Backend validation:

```bash
cd /Users/Zhuanz/Claude/deepseek-test
PYTHONPATH=. pytest -q tests/test_backend.py
```

If billing verification logic changes, add or update backend tests for:

- missing env vars
- dev-mode behavior if intentionally preserved
- valid product ID mapping
- invalid product ID rejection

## 6. Done Definition

The implementation work is done when all of the following are true:

- release signing cannot fall back to debug signing
- the app sends a real Play purchase token to the backend
- backend production billing config fails clearly when misconfigured
- backend URL is release-configurable without source edits
- release-relevant analyzer issues are reduced
- release build steps are documented for engineers

At that point, the codebase should be ready for a human to complete:

- Play Console app creation
- subscription setup
- data safety and policy forms
- internal and closed track rollout
- production submission
