# Before merging the swamp release workflow

Pull request #299 (`swamp-release-workflow` into `develop`) adds the 1.7.6
release commits, the `release-ios` swamp workflow and its
`@mobileorg/ios-release` extension. This plan covers what must happen before it
merges. Work after the merge is in [post-1.7.6-todo.md](post-1.7.6-todo.md).

## Decisions

- [ ] **Helper processes after a timeout.** A timed-out or cancelled
      `xcodebuild` may leave helper processes running, because Deno ends only
      the direct child. The options are to accept this and keep the plan entry,
      or to add a process-group wrapper (macOS has no `setsid`, so it would need
      `perl` or similar). Recommendation: accept it. The upload step already
      blocks a retry after an interrupted upload, and stray processes can be
      found and ended by hand.
- [ ] **A sixth review of `7f20bd2`.** The five review rounds the pre-push review
      allows ran before this commit. It adds a six-line check that the archive
      is not newer than its `verifyArchive` result, with two tests.
      Recommendation: review it along with the gate test below. That test needs
      the extension source again anyway.
- [ ] **The test gate while the parser test is flaky.** `runTests` defaults to
      `true`, so a flaky failure of
      `OrgfileParserTests.testParseOrgFileDifferentTodoWords` stops a release.
      The options are to keep the default and rerun on a flaky failure, to
      default to `false` until the test is fixed, or to fix the test before
      merging. Recommendation: keep the default. A skipped test run is recorded
      in the run inputs.
- [ ] **Tagging and pushing in the workflow.** Tagging and pushing were left for
      a second pass. The option is to add them before this merge or after it.
      Recommendation: after it, so the first real release through the workflow
      shows how tagging should fit.
- [ ] **`IDEWorkspaceChecks.plist`.** Xcode created
      `MobileOrg.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`,
      which is untracked. Apple recommends committing it. The other options are
      to ignore it or leave it untracked. A file that is not tracked does not
      affect the workflow's clean-tree check.

## Steps

1. **Sign in to Xcode again.** On 2026-11-05 an export failed with `No Accounts`,
   because the keychain was missing `Xcode-Username` and `Xcode-Token`. Open
   Xcode, then Settings, then Accounts, and sign in. Then check that
   `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier` no longer
   shows team `59B7VFRF7R` as a Personal Team.
2. **Run the workflow to the approval gate.** The preflight needs the branch
   `release/1.7.6`, and before the merge only the pull request branch contains
   `swamp/`. Point a temporary local branch at the pull request branch for the
   test and restore the real one afterwards:

   ```sh
   git switch swamp-release-workflow
   git branch -m release/1.7.6 release/1.7.6-keep
   git switch -c release/1.7.6
   cd swamp && swamp workflow run release-ios --input version=1.7.6 --input runTests=false
   ```

   Check that:
   - `verify-archive` passes. This shows that `xcodebuild archive` changes no
     tracked file such as `Package.resolved`, which the clean-tree check would
     otherwise reject.
   - The gate prompt shows the build that `verifyIpa` recorded in this run, not
     one from an earlier run. Compare it with
     `swamp data query 'model("mobileorg-release") && name == "verifyIpa"' --select content`.
3. **Test the refusal path at the gate without uploading.** Approve the gate,
   then resume with a wrong build number. The upload must refuse before it
   contacts App Store Connect:

   ```sh
   swamp workflow approve release-ios confirm-upload --run RUN_ID
   swamp workflow resume release-ios --run RUN_ID --input approvedBuild=1
   ```

   The step should fail with `refusing to upload` and name build 1. This shows
   that the resume input reaches the upload step. The upload cannot run with
   the correct number in this run, because a run keeps the first value it is
   given. Do not resume with the real build number. Version 1.7.6 is already
   in App Store Connect.
4. **Restore the branches.** Return to the pull request branch, delete the
   temporary branch and move the real one back. Check that `release/1.7.6` and
   `v1.7.6` both point at `ac03720`:

   ```sh
   cd .. && git switch swamp-release-workflow
   git branch -D release/1.7.6
   git branch -m release/1.7.6-keep release/1.7.6
   git rev-parse --short release/1.7.6 'v1.7.6^{commit}'
   ```

5. **Run the unit tests on the test simulator.** Run the workflow once with
   `runTests=true`, or run
   `xcodebuild test -scheme MobileOrg -destination 'platform=iOS Simulator,name=iPhone 17'`,
   and record whether the parser test passes. Then apply the test-gate decision
   above.
6. **Record the results.** Add the outcome of steps 2 to 5 to the pull request.
   If any step fails, fix it on the branch and run the pre-push review again
   before pushing.
7. **Merge.** Mark the pull request ready and merge it with a merge commit, not
   a squash. Then check that the tag is reachable from `develop`:

   ```sh
   git fetch origin
   git merge-base --is-ancestor v1.7.6 origin/develop && echo reachable
   ```

## Known limits at merge

- The upload step has not run through the workflow. The first real release is
  its first full run.
- The upload exports and signs again from the archive. The checks in
  `verifyIpa` cover the earlier export, not the file that is sent.
- The tag `v1.7.6` points at `ac03720`, which builds as 421. Build 420 was
  uploaded, from `d999596`, before the deployment-target commit.
