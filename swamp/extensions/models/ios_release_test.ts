import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
  assertThrows,
} from "jsr:@std/assert@1.0.13";
import { join } from "node:path";
import {
  assertUploadable,
  buildMatchesCommits,
  CommandFailed,
  commandFailure,
  CommandTimeout,
  excerpt,
  exitedBySignal,
  exportOptionsPlist,
  interruptedUpload,
  isInside,
  meetsDeploymentTarget,
  readUploadCheck,
  type ReleasePaths,
  type UploadCheck,
  type UploadHistory,
} from "./ios_release.ts";

Deno.test("excerpt leaves short output alone", () => {
  assertEquals(excerpt("abc", 5, 5), "abc");
});

Deno.test("excerpt keeps the start and the end of long output", () => {
  const result = excerpt("START-middle-END", 6, 3);
  assertStringIncludes(result, "START-");
  assertStringIncludes(result, "END");
  assertStringIncludes(result, "7 characters omitted");
  assertEquals(result.includes("middle"), false);
});

Deno.test("command failure includes stderr and stdout", () => {
  const message = commandFailure(
    "xcodebuild test",
    65,
    "stderr cause",
    "Failing tests:\n\tSomeTests.testThing",
  );
  assertStringIncludes(message, "xcodebuild test failed (exit 65)");
  assertStringIncludes(message, "stderr cause");
  assertStringIncludes(message, "SomeTests.testThing");
});

Deno.test("command failure skips an empty stream", () => {
  assertEquals(
    commandFailure("git status", 1, "", "only stdout"),
    "git status failed (exit 1):\nonly stdout",
  );
});

Deno.test("export options sign for the App Store with the given team", () => {
  const plist = exportOptionsPlist("ABCDE12345", "export");
  assertStringIncludes(
    plist,
    "<key>method</key><string>app-store-connect</string>",
  );
  assertStringIncludes(plist, "<key>destination</key><string>export</string>");
  assertStringIncludes(plist, "<key>teamID</key><string>ABCDE12345</string>");
});

Deno.test("upload options change only the destination", () => {
  const exported = exportOptionsPlist("ABCDE12345", "export");
  const uploaded = exportOptionsPlist("ABCDE12345", "upload");
  assertEquals(
    uploaded,
    exported.replace("<string>export</string>", "<string>upload</string>"),
  );
});

Deno.test("isInside accepts a child and rejects the parent and outsiders", () => {
  assertEquals(isInside("/project", "/project/swamp/build/1.7.6"), true);
  assertEquals(isInside("/project", "/project"), false);
  assertEquals(isInside("/project", "/project-other/1.7.6"), false);
  assertEquals(isInside("/project", "/project/../elsewhere/1.7.6"), false);
});

Deno.test("deployment target accepts 13 and later", () => {
  assertEquals(meetsDeploymentTarget("13.0"), true);
  assertEquals(meetsDeploymentTarget("15.0"), true);
  assertEquals(meetsDeploymentTarget("15.0", 15), true);
});

Deno.test("deployment target rejects older, empty and garbage values", () => {
  assertEquals(meetsDeploymentTarget("12.0"), false);
  assertEquals(meetsDeploymentTarget("13.0", 15), false);
  assertEquals(meetsDeploymentTarget(""), false);
  assertEquals(meetsDeploymentTarget("latest"), false);
});

function approvedBuild(overrides: Partial<UploadCheck> = {}): UploadCheck {
  return {
    version: "1.7.6",
    expectedBuild: "421",
    archiveVersion: "1.7.6",
    archiveBuild: "421",
    ipaVersion: "1.7.6",
    ipaBuild: "421",
    verified: {
      version: "1.7.6",
      build: "421",
      commit: "c0ffee",
      completedAt: "2026-11-05T05:21:00.000Z",
    },
    archiveBuiltAt: new Date("2026-11-05T05:20:47.000Z"),
    headCommit: "c0ffee",
    ...overrides,
  };
}

Deno.test("upload is allowed for the verified, approved build", () => {
  assertUploadable(approvedBuild());
});

Deno.test("upload is refused without a verifyIpa result", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ verified: null })),
    Error,
    "verifyIpa has not recorded a result",
  );
});

Deno.test("upload is refused when the archive was rebuilt after verification", () => {
  assertThrows(
    () =>
      assertUploadable(
        approvedBuild({ archiveBuiltAt: new Date("2026-11-05T06:00:00.000Z") }),
      ),
    Error,
    "rebuilt after verifyIpa",
  );
});

Deno.test("upload is refused when the archive has a different build than approved", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ archiveBuild: "425" })),
    Error,
    "archive has build 425, not the approved build 421",
  );
});

Deno.test("upload is refused when the verified IPA has a different build", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ ipaBuild: "425" })),
    Error,
    "verified IPA has build 425",
  );
});

Deno.test("upload is refused when verifyIpa checked another build", () => {
  assertThrows(
    () =>
      assertUploadable(
        approvedBuild({
          verified: {
            version: "1.7.6",
            build: "418",
            completedAt: "2026-11-05T05:21:00.000Z",
          },
        }),
      ),
    Error,
    "verifyIpa checked build 418",
  );
});

Deno.test("upload is refused for another version", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ archiveVersion: "1.7.5" })),
    Error,
    "archive has version 1.7.5, not 1.7.6",
  );
});

Deno.test("upload is refused without an approved build number", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ expectedBuild: "" })),
    Error,
    "no approved build number",
  );
});

Deno.test("an upload refusal lists every problem", () => {
  const error = assertThrows(
    () =>
      assertUploadable(
        approvedBuild({ verified: null, archiveBuild: "9", ipaBuild: "9" }),
      ),
    Error,
  );
  assertStringIncludes(error.message, "verifyIpa has not recorded a result");
  assertStringIncludes(error.message, "archive has build 9");
  assertStringIncludes(error.message, "verified IPA has build 9");
});

Deno.test("upload is refused when the verified IPA has another version", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ ipaVersion: "1.7.5" })),
    Error,
    "verified IPA has version 1.7.5",
  );
});

Deno.test("upload is refused when verifyIpa checked another version", () => {
  assertThrows(
    () =>
      assertUploadable(
        approvedBuild({
          verified: {
            version: "1.7.5",
            build: "421",
            completedAt: "2026-11-05T05:21:00.000Z",
          },
        }),
      ),
    Error,
    "verifyIpa checked version 1.7.5",
  );
});

Deno.test("upload is refused when the verification time cannot be read", () => {
  assertThrows(
    () =>
      assertUploadable(
        approvedBuild({
          verified: { version: "1.7.6", build: "421", completedAt: "unknown" },
        }),
      ),
    Error,
    "rebuilt after verifyIpa",
  );
});

Deno.test("upload is allowed when verification is as new as the archive", () => {
  assertUploadable(
    approvedBuild({ archiveBuiltAt: new Date("2026-11-05T05:21:00.000Z") }),
  );
});

function history(overrides: Partial<UploadHistory> = {}): UploadHistory {
  return {
    version: "1.7.6",
    build: "421",
    attempted: {
      version: "1.7.6",
      build: "421",
      completedAt: "2026-11-05T06:00:00.000Z",
    },
    uploaded: null,
    failed: null,
    archived: {
      version: "1.7.6",
      completedAt: "2026-11-05T05:20:00.000Z",
    },
    ...overrides,
  };
}

Deno.test("an attempt with no outcome is an interrupted upload", () => {
  assertEquals(interruptedUpload(history()), true);
});

Deno.test("no attempt is not an interrupted upload", () => {
  assertEquals(interruptedUpload(history({ attempted: null })), false);
});

Deno.test("an attempt for another build is not interrupted", () => {
  assertEquals(
    interruptedUpload(
      history({
        attempted: {
          version: "1.7.6",
          build: "418",
          completedAt: "2026-11-05T06:00:00.000Z",
        },
      }),
    ),
    false,
  );
});

Deno.test("a later upload result settles the attempt", () => {
  assertEquals(
    interruptedUpload(
      history({
        uploaded: {
          version: "1.7.6",
          build: "421",
          completedAt: "2026-11-05T06:10:00.000Z",
        },
      }),
    ),
    false,
  );
});

Deno.test("a later failure result settles the attempt", () => {
  assertEquals(
    interruptedUpload(
      history({
        failed: {
          version: "1.7.6",
          build: "421",
          completedAt: "2026-11-05T06:10:00.000Z",
        },
      }),
    ),
    false,
  );
});

Deno.test("an upload result for another build does not settle the attempt", () => {
  assertEquals(
    interruptedUpload(
      history({
        uploaded: {
          version: "1.7.6",
          build: "418",
          completedAt: "2026-11-05T06:10:00.000Z",
        },
      }),
    ),
    true,
  );
});

Deno.test("an outcome older than the attempt does not settle it", () => {
  assertEquals(
    interruptedUpload(
      history({
        uploaded: {
          version: "1.7.6",
          build: "421",
          completedAt: "2026-11-05T05:00:00.000Z",
        },
      }),
    ),
    true,
  );
});

Deno.test("rebuilding the archive starts a new attempt", () => {
  assertEquals(
    interruptedUpload(
      history({
        archived: {
          version: "1.7.6",
          completedAt: "2026-11-05T07:00:00.000Z",
        },
      }),
    ),
    false,
  );
});

Deno.test("an attempt with an unreadable time counts as interrupted", () => {
  assertEquals(
    interruptedUpload(
      history({
        attempted: { version: "1.7.6", build: "421", completedAt: "?" },
      }),
    ),
    true,
  );
});

Deno.test("a timeout names the command and the limit", () => {
  const error = new CommandTimeout("xcodebuild", 90_000);
  assertEquals(error.message, "xcodebuild timed out after 90 seconds");
  assertEquals(error instanceof Error, true);
});

function infoPlist(version: string, build: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleShortVersionString</key><string>${version}</string>
<key>CFBundleVersion</key><string>${build}</string>
</dict></plist>
`;
}

async function releaseTree(
  archive: { version: string; build: string },
  ipa: { version: string; build: string },
): Promise<ReleasePaths> {
  const root = await Deno.makeTempDir({ prefix: "ios-release-test-" });
  const paths: ReleasePaths = {
    project: root,
    releaseDir: root,
    archive: join(root, "MobileOrg.xcarchive"),
    app: join(root, "MobileOrg.xcarchive/Products/Applications/MobileOrg.app"),
    exportDir: join(root, "export"),
    ipaPayload: join(root, "ipa"),
    ipaApp: join(root, "ipa/Payload/MobileOrg.app"),
  };
  await Deno.mkdir(paths.app, { recursive: true });
  await Deno.mkdir(paths.ipaApp, { recursive: true });
  await Deno.writeTextFile(
    join(paths.app, "Info.plist"),
    infoPlist(archive.version, archive.build),
  );
  await Deno.writeTextFile(
    join(paths.ipaApp, "Info.plist"),
    infoPlist(ipa.version, ipa.build),
  );
  return paths;
}

const verifiedResult = {
  version: "1.7.6",
  build: "421",
  completedAt: "2026-11-05T05:21:00.000Z",
};

Deno.test({
  name: "the upload check reads the archive and the IPA from their own paths",
  ignore: Deno.build.os !== "darwin",
  fn: async () => {
    const paths = await releaseTree(
      { version: "1.7.6", build: "421" },
      { version: "1.7.5", build: "999" },
    );
    try {
      const check = await readUploadCheck(
        {
          signal: new AbortController().signal,
          readResource: (name) =>
            Promise.resolve(name === "verifyIpa" ? verifiedResult : null),
        },
        paths,
        "1.7.6",
        "421",
      );
      assertEquals(check.archiveVersion, "1.7.6");
      assertEquals(check.archiveBuild, "421");
      assertEquals(check.ipaVersion, "1.7.5");
      assertEquals(check.ipaBuild, "999");
      assertEquals(check.verified, verifiedResult);
      assertEquals(check.expectedBuild, "421");
      assertEquals(check.version, "1.7.6");
      assertEquals(check.archiveBuiltAt instanceof Date, true);
    } finally {
      await Deno.remove(paths.project, { recursive: true });
    }
  },
});

Deno.test({
  name: "the upload check fails when the IPA has not been unpacked",
  ignore: Deno.build.os !== "darwin",
  fn: async () => {
    const paths = await releaseTree(
      { version: "1.7.6", build: "421" },
      { version: "1.7.6", build: "421" },
    );
    try {
      await Deno.remove(paths.ipaPayload, { recursive: true });
      await assertRejects(
        () =>
          readUploadCheck(
            {
              signal: new AbortController().signal,
              readResource: () => Promise.resolve(null),
            },
            paths,
            "1.7.6",
            "421",
          ),
        Error,
        "reading CFBundleShortVersionString",
      );
    } finally {
      await Deno.remove(paths.project, { recursive: true });
    }
  },
});

Deno.test("upload is refused when the source moved after verification", () => {
  assertThrows(
    () => assertUploadable(approvedBuild({ headCommit: "badc0de" })),
    Error,
    "the source is at commit badc0de, but verifyIpa checked commit c0ffee",
  );
});

Deno.test("an archive record for another version does not settle an attempt", () => {
  assertEquals(
    interruptedUpload(
      history({
        archived: {
          version: "1.7.7",
          completedAt: "2026-11-05T07:00:00.000Z",
        },
      }),
    ),
    true,
  );
});

Deno.test("an exit caused by a signal is not a definite result", () => {
  assertEquals(exitedBySignal(130), true);
  assertEquals(exitedBySignal(137), true);
  assertEquals(exitedBySignal(65), false);
  assertEquals(exitedBySignal(1), false);
  assertEquals(exitedBySignal(0), false);
});

Deno.test("a failed command carries its exit code and its output", () => {
  const error = new CommandFailed("xcodebuild test", {
    code: 65,
    stdout: "Failing tests: SomeTests",
    stderr: "",
  });
  assertEquals(error.code, 65);
  assertStringIncludes(error.message, "xcodebuild test failed (exit 65)");
  assertStringIncludes(error.message, "SomeTests");
  assertEquals(error instanceof Error, true);
});

Deno.test("the build number must be the commit count", () => {
  assertEquals(buildMatchesCommits("421", "421"), true);
  assertEquals(buildMatchesCommits("32", "421"), false);
  assertEquals(buildMatchesCommits("421-develop", "421"), false);
  assertEquals(buildMatchesCommits("", ""), false);
});

Deno.test({
  name: "the upload check reports when the archive was built",
  ignore: Deno.build.os !== "darwin",
  fn: async () => {
    const paths = await releaseTree(
      { version: "1.7.6", build: "421" },
      { version: "1.7.6", build: "421" },
    );
    try {
      const builtAt = new Date("2026-01-02T03:04:05.000Z");
      await Deno.utime(join(paths.app, "Info.plist"), builtAt, builtAt);
      const check = await readUploadCheck(
        {
          signal: new AbortController().signal,
          readResource: () => Promise.resolve(null),
        },
        paths,
        "1.7.6",
        "421",
      );
      assertEquals(check.archiveBuiltAt.getTime(), builtAt.getTime());
      assertEquals(check.verified, null);
    } finally {
      await Deno.remove(paths.project, { recursive: true });
    }
  },
});
