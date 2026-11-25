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

- [ ] Investigate `OrgfileParserTests.testParseOrgFileDifferentTodoWords`, which
      fails at `OrgfileParserTests.swift:96` and `:106`. It failed on Xcode 26.3
      with iOS 18.3.1 before any of the release changes touched app code. The
      cause is unknown. The git history mentions a flaky-test revert.
- [ ] Run the tests in CI or locally before each release.

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
