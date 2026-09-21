# Release operations

1. Update `VERSION` and `docs/release-notes.md`.
2. Run `./script/check.sh`, build and test a real local generation.
3. Commit and push to `main`.
4. Tag the commit `v<VERSION>` and push that tag.
5. Wait for the GitHub Actions release job. Inspect the ZIP, `SHA256SUMS`, and signed `appcast.xml` in the new release.
6. Verify **Check for Updates…** from an older installed build.

The updater feed is `https://github.com/sthamann/glim-studio/releases/latest/download/appcast.xml`. Archives use immutable version-specific download URLs. Never overwrite an existing version's archive. Never change or regenerate the update key casually: installed apps trust its public key.

The Ed25519 private key is stored under account `glim-studio-updates` in the maintainer's macOS Keychain and as the encrypted Actions secret `SPARKLE_PRIVATE_KEY`. The repository contains only the public key. `generate_appcast` signs both the archive and the feed; `SURequireSignedFeed` and its prerequisite `SUVerifyUpdateBeforeExtraction` are enabled.

Application updates preserve downloaded models and image history in Application Support. Existing early Lichtbild Studio installations reuse their original Application Support folder to preserve data.

## Developer ID and notarization

The current build is ad-hoc signed. To produce Apple-trusted downloads, obtain a Developer ID Application certificate under an active Apple Developer membership and configure a distribution pipeline that signs the app and all nested code with hardened runtime, submits the final archive with `notarytool`, and staples a successful ticket before generating the Sparkle appcast. The uv helper and Sparkle's XPC services must be included in signing validation. This pipeline is not claimed to be configured until those credentials are available and a notarized artifact has passed Gatekeeper assessment.

## Local packaging

`./script/package_release.sh` creates the archive, feed and checksums in `dist/`. It reads the key from the Keychain locally, or from `SPARKLE_PRIVATE_KEY` in CI. Private keys are passed via standard input, never command-line arguments.
