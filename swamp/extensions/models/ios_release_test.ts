import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "jsr:@std/assert@1.0.13";
import {
  assertUploadable,
  commandFailure,
  excerpt,
  exportOptionsPlist,
  isInside,
  meetsDeploymentTarget,
  type UploadCheck,
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
      completedAt: "2026-11-05T05:21:00.000Z",
    },
    archiveBuiltAt: new Date("2026-11-05T05:20:47.000Z"),
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
