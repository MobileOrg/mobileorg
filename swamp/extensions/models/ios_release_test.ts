import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.13";
import { commandFailure, excerpt, exportOptionsPlist } from "./ios_release.ts";

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
