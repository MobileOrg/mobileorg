# Todo after the 1.7.6 submission

Version 1.7.6 (build 418) was uploaded to App Store Connect on 2026-11-04 and
submitted for review. It is tagged `v1.7.6` on `release/1.7.6` (`ac03720`).
Nothing has been pushed.

## Finish the release

- [ ] Wait for App Review. Check that the app is available again once it is
      approved.
- [ ] Push `release/1.7.6` and open a pull request into `develop`. Merge with a
      merge commit or fast-forward. A squash merge leaves `v1.7.6` pointing at a
      commit that is not in `develop`.
- [ ] Push the tag: `git push origin v1.7.6`.
- [ ] Keep the local `Configuration/AppKey.plist` edit out of every commit. It is
      marked `skip-worktree`. Check `git status` before staging.

## Build and release hygiene

- [ ] Redesign how the Dropbox key reaches the build. `Configuration/AppKey.plist`
      is tracked and holds placeholders, so every release needs a local edit.
      Move the key to a gitignored local file read by the build script. Stop
      bundling `AppSecret`: the app reads only `AppKey`
      (`Classes/Sync/Dropbox/DropboxTransferManager.swift`), and the file is
      packaged into the app. Update the README, which tells contributors to edit
      `AppKey.plist` (`README.org:52`). Discuss the design before starting.
- [ ] Add `ITSAppUsesNonExemptEncryption` to `MobileOrg-Info.plist` so App Store
      Connect stops asking the export compliance questions on each upload. The
      value depends on the answers given on the form. It needs a new build
      number to take effect.
- [ ] Remove `.travis.yml` and the Travis badge (`README.org:2`). CI is no longer
      Travis.
- [ ] Give the two build-phase scripts declared outputs, or turn off "Based on
      dependency analysis", to clear the build warnings that they run on every
      build.
- [ ] Raise the deployment target to iOS 15 before April 2027. App Store Connect
      will then reject builds below 15.0. The target is set in
      `Global.shared.xcconfig`.
- [ ] Update the README Xcode requirement, which still says Xcode 12.

## Tests

- [ ] Investigate the flaky parser test. `OrgfileParserTests.testParseOrgFileDifferentTodoWords`
      failed at `OrgfileParserTests.swift:96` and `:106` on Xcode 26.3 with an
      iPhone 16 on iOS 18.3.1, before any release change touched app code. Through
      the release workflow on an iPhone 17 on iOS 26.2 the test step failed once
      and passed on the next run with no code change. The names of the tests in
      that second failure were not captured. The git history mentions a flaky-test
      revert. The workflow's test step is a hard gate by default, so a flaky failure
      blocks a release: rerun it, or pass `runTests=false`, which the run records.
      Find the cause so the gate can be trusted.
- [ ] Run the tests in CI or locally before each release. The `release-ios`
      workflow does this with `runTests` (on by default).

## Release workflow (`swamp/`)

The `release-ios` swamp workflow builds, verifies, exports and uploads a release,
and stops at an approval gate before the upload. Run it from the `release/<version>`
branch. It does not yet cover:

- [ ] Tagging the release commit, committing, and pushing, behind a second
      approval gate.
- [ ] Submitting the build for review. That stays manual in App Store Connect.
- [ ] An end-to-end test of the `upload` step. Its preconditions have unit
      tests, including one that reads real plists from disk: the archive, the
      unpacked IPA and the stored `verifyIpa` result must all match the build
      you approved, and an interrupted earlier upload of that build blocks a
      retry until the archive is rebuilt. The upload itself has only been
      exercised by hand. The first real release through the workflow is the
      first full run.
- [ ] Approving the upload takes two commands: `swamp workflow approve` and then
      `swamp workflow resume --input approvedBuild=<build>`, with the build the
      gate prompt shows. The build you type is what the upload is held to, so a
      second run cannot change what ships. Confirm that the resume input works
      at the first real release.
- [ ] `upload` exports and signs again from the archive. The signature and
      entitlement checks in `verifyIpa` cover the earlier export, not the file
      that is sent, and `destination upload` leaves no file to check afterwards.
- [ ] Run the extension tests with
      `~/.swamp/deno/deno test --allow-read --allow-write --allow-run extensions/models/`
      from `swamp/`. Two tests read plists with PlistBuddy and run on macOS only.
- [ ] Reproducing the uploaded build number. Build 418 was uploaded for 1.7.6.
      The build number is the git commit count, so the tagged commit `ac03720`
      builds as 421. The tag matches the source, not the number.
- [ ] The default test simulator is `iPhone 17`, because xcodebuild resolves a
      missing OS to the latest runtime. Change the `testDestination` input if
      that device is not installed.

## Worth reviewing

These come from reading `Classes/Utilities/GlobalUtils.m` and
`Classes/Settings/Settings.m` while answering the export compliance question.
Neither has been tested or confirmed as a problem.

- [ ] The file encryption derives its key from the password with a single MD5
      round (the OpenSSL `EVP_BytesToKey` scheme) and takes its salt from the
      current time. Decide whether this matters for the data protected.
- [ ] The encryption password is stored in `NSUserDefaults`
      (`Settings.m:166`), not the Keychain.

## Environment notes

- [ ] Xcode's cached team data showed the team as "Personal Team" even after the
      paid membership was active. `xcodebuild` worked, so the cache did not block
      the release. Check whether Distribute App in the Organizer works after an
      Xcode restart.
