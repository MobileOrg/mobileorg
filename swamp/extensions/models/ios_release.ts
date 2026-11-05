import { z } from "npm:zod@4";
import { join, resolve } from "node:path";

const ARCHIVE_NAME = "MobileOrg.xcarchive";
const SOURCE_INFO_PLIST = "MobileOrg-Info.plist";
const APP_KEY_PLIST = "Configuration/AppKey.plist";
const APP_KEY_PATH = "Dropbox\\ API\\ Key:AppKey";
const PLACEHOLDER_APP_KEY = "YourAppKey";
const MINIMUM_DEPLOYMENT_TARGET = 13;
const PLIST_BUDDY = "/usr/libexec/PlistBuddy";

const GlobalArgsSchema = z.object({
  projectDir: z.string().default("..").describe(
    "MobileOrg checkout, relative to the swamp repository",
  ),
  outputDir: z.string().default("swamp/build/release").describe(
    "Archive and export directory, relative to projectDir",
  ),
  teamId: z.string().regex(/^[A-Z0-9]{10}$/).describe(
    "Apple Developer team ID used to sign the export and upload",
  ),
  scheme: z.string().default("MobileOrg"),
  configuration: z.string().default("AppStore"),
});

const VersionSchema = z.string().regex(
  /^\d+\.\d+\.\d+$/,
  "expected a marketing version such as 1.7.6",
);

const VersionArgsSchema = z.object({ version: VersionSchema });

const ResultSchema = z.object({
  step: z.string(),
  version: z.string(),
  summary: z.string(),
  build: z.string().optional(),
  completedAt: z.string(),
});

type GlobalArgs = z.infer<typeof GlobalArgsSchema>;

interface ReleaseContext {
  globalArgs: GlobalArgs;
  repoDir: string;
  signal: AbortSignal;
  writeResource: (
    specName: string,
    name: string,
    data: Record<string, unknown>,
  ) => Promise<{ name: string }>;
}

interface CommandResult {
  code: number;
  stdout: string;
  stderr: string;
}

/**
 * Start and end of long command output. Tools print the cause of a failure
 * first and the summary last, and the middle is usually a long listing.
 */
export function excerpt(text: string, head = 1000, tail = 3000): string {
  if (text.length <= head + tail) return text;
  return `${text.slice(0, head)}\n[... ${
    text.length - head - tail
  } characters omitted ...]\n${text.slice(-tail)}`;
}

/**
 * Failure message for a command that exited non-zero. xcodebuild prints some
 * causes on stderr and others, such as the failing tests, on stdout, so both
 * streams are included.
 */
export function commandFailure(
  label: string,
  code: number,
  stderr: string,
  stdout: string,
): string {
  const output = [stderr, stdout]
    .filter((stream) => stream.trim() !== "")
    .map((stream) => excerpt(stream))
    .join("\n");
  return `${label} failed (exit ${code}):\n${output}`;
}

/** The ExportOptions.plist that signs for the App Store and exports or uploads. */
export function exportOptionsPlist(
  teamId: string,
  destination: "export" | "upload",
): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>${destination}</string>
<key>teamID</key><string>${teamId}</string>
<key>signingStyle</key><string>automatic</string>
</dict></plist>
`;
}

async function run(
  command: string,
  args: string[],
  cwd: string,
  signal: AbortSignal,
): Promise<CommandResult> {
  const output = await new Deno.Command(command, {
    args,
    cwd,
    stdout: "piped",
    stderr: "piped",
    signal,
  }).output();
  const decoder = new TextDecoder();
  return {
    code: output.code,
    stdout: decoder.decode(output.stdout),
    stderr: decoder.decode(output.stderr),
  };
}

async function runOrThrow(
  label: string,
  command: string,
  args: string[],
  cwd: string,
  signal: AbortSignal,
): Promise<CommandResult> {
  const result = await run(command, args, cwd, signal);
  if (result.code !== 0) {
    throw new Error(
      commandFailure(label, result.code, result.stderr, result.stdout),
    );
  }
  return result;
}

async function plistValue(
  file: string,
  keyPath: string,
  cwd: string,
  signal: AbortSignal,
): Promise<string> {
  const result = await runOrThrow(
    `reading ${keyPath} from ${file}`,
    PLIST_BUDDY,
    ["-c", `print :${keyPath}`, file],
    cwd,
    signal,
  );
  return result.stdout.trim();
}

function paths(context: ReleaseContext, version: string) {
  const project = resolve(context.repoDir, context.globalArgs.projectDir);
  const releaseDir = resolve(
    project,
    context.globalArgs.outputDir,
    version,
  );
  return {
    project,
    releaseDir,
    archive: join(releaseDir, ARCHIVE_NAME),
    app: join(releaseDir, ARCHIVE_NAME, "Products/Applications/MobileOrg.app"),
    exportDir: join(releaseDir, "export"),
    ipaPayload: join(releaseDir, "ipa"),
  };
}

async function record(
  context: ReleaseContext,
  step: string,
  version: string,
  summary: string,
  build?: string,
) {
  const handle = await context.writeResource("result", step, {
    step,
    version,
    summary,
    ...(build ? { build } : {}),
    completedAt: new Date().toISOString(),
  });
  return { dataHandles: [handle] };
}

async function exportArchive(
  context: ReleaseContext,
  version: string,
  destination: "export" | "upload",
  exportPath: string,
): Promise<CommandResult> {
  const p = paths(context, version);
  const optionsFile = join(p.releaseDir, `${destination}-options.plist`);
  await Deno.writeTextFile(
    optionsFile,
    exportOptionsPlist(context.globalArgs.teamId, destination),
  );
  await Deno.remove(exportPath, { recursive: true }).catch(() => {});
  return await runOrThrow(
    `xcodebuild -exportArchive (${destination})`,
    "xcodebuild",
    [
      "-exportArchive",
      "-archivePath",
      p.archive,
      "-exportOptionsPlist",
      optionsFile,
      "-exportPath",
      exportPath,
      "-allowProvisioningUpdates",
    ],
    p.project,
    context.signal,
  );
}

export const model = {
  type: "@mobileorg/ios-release",
  version: "2026.11.05.1",
  globalArguments: GlobalArgsSchema,
  resources: {
    result: {
      description: "Outcome of one release step",
      schema: ResultSchema,
      lifetime: "infinite",
      garbageCollection: 10,
    },
  },
  methods: {
    verifySource: {
      description:
        "Refuse to release from the wrong branch, a dirty tree, a source version that does not match, or without the real Dropbox key",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const { project } = paths(context, args.version);
        const { signal } = context;

        const branch = (await runOrThrow(
          "reading the current branch",
          "git",
          ["rev-parse", "--abbrev-ref", "HEAD"],
          project,
          signal,
        )).stdout.trim();
        if (branch !== `release/${args.version}`) {
          throw new Error(
            `on branch ${branch}, expected release/${args.version}`,
          );
        }

        const changes = (await runOrThrow(
          "reading the working tree status",
          "git",
          ["status", "--porcelain", "--untracked-files=no"],
          project,
          signal,
        )).stdout.trim();
        if (changes) {
          throw new Error(
            `tracked files have uncommitted changes:\n${changes}`,
          );
        }

        const sourceVersion = await plistValue(
          join(project, SOURCE_INFO_PLIST),
          "CFBundleShortVersionString",
          project,
          signal,
        );
        if (sourceVersion !== args.version) {
          throw new Error(
            `${SOURCE_INFO_PLIST} has version ${sourceVersion}, expected ${args.version}`,
          );
        }

        const appKey = await plistValue(
          join(project, APP_KEY_PLIST),
          APP_KEY_PATH,
          project,
          signal,
        );
        if (appKey === "" || appKey === PLACEHOLDER_APP_KEY) {
          throw new Error(`${APP_KEY_PLIST} still holds the placeholder key`);
        }
        const flags = (await runOrThrow(
          "reading the AppKey.plist index flags",
          "git",
          ["ls-files", "-v", APP_KEY_PLIST],
          project,
          signal,
        )).stdout;
        if (!flags.startsWith("S")) {
          throw new Error(
            `${APP_KEY_PLIST} is not marked skip-worktree; the key could be committed`,
          );
        }

        return await record(
          context,
          "verifySource",
          args.version,
          `branch ${branch}, clean tree, version ${sourceVersion}, Dropbox key set`,
        );
      },
    },

    test: {
      description: "Run the unit tests on a simulator",
      arguments: z.object({
        version: VersionSchema,
        destination: z.string().default(
          "platform=iOS Simulator,name=iPhone 17",
        ).describe("xcodebuild destination for the tests"),
      }),
      execute: async (
        args: { version: string; destination: string },
        context: ReleaseContext,
      ) => {
        const { project } = paths(context, args.version);
        await runOrThrow(
          "xcodebuild test",
          "xcodebuild",
          [
            "test",
            "-scheme",
            context.globalArgs.scheme,
            "-destination",
            args.destination,
          ],
          project,
          context.signal,
        );
        return await record(
          context,
          "test",
          args.version,
          `unit tests passed on ${args.destination}`,
        );
      },
    },

    archive: {
      description:
        "Archive the App Store configuration. Replaces any earlier archive for this version",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        await Deno.remove(p.releaseDir, { recursive: true }).catch(() => {});
        await Deno.mkdir(p.releaseDir, { recursive: true });
        await runOrThrow(
          "xcodebuild archive",
          "xcodebuild",
          [
            "archive",
            "-scheme",
            context.globalArgs.scheme,
            "-configuration",
            context.globalArgs.configuration,
            "-destination",
            "generic/platform=iOS",
            "-archivePath",
            p.archive,
            "-allowProvisioningUpdates",
          ],
          p.project,
          context.signal,
        );
        return await record(
          context,
          "archive",
          args.version,
          `archived to ${p.archive}`,
        );
      },
    },

    verifyArchive: {
      description:
        "Check the archived app's version, deployment target and Dropbox key",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        const plist = join(p.app, "Info.plist");
        const { signal } = context;
        const version = await plistValue(
          plist,
          "CFBundleShortVersionString",
          p.project,
          signal,
        );
        const build = await plistValue(
          plist,
          "CFBundleVersion",
          p.project,
          signal,
        );
        const minimumOs = await plistValue(
          plist,
          "MinimumOSVersion",
          p.project,
          signal,
        );
        const scheme = await plistValue(
          plist,
          "CFBundleURLTypes:0:CFBundleURLSchemes:0",
          p.project,
          signal,
        );
        if (version !== args.version) {
          throw new Error(
            `archive has version ${version}, expected ${args.version}`,
          );
        }
        if (Number.parseInt(minimumOs, 10) < MINIMUM_DEPLOYMENT_TARGET) {
          throw new Error(
            `archive targets iOS ${minimumOs}; App Store Connect requires ${MINIMUM_DEPLOYMENT_TARGET} or later`,
          );
        }
        if (scheme === `db-${PLACEHOLDER_APP_KEY}`) {
          throw new Error("archive carries the placeholder Dropbox key");
        }
        return await record(
          context,
          "verifyArchive",
          args.version,
          `version ${version} build ${build}, minimum iOS ${minimumOs}`,
          build,
        );
      },
    },

    exportIpa: {
      description: "Export a distribution-signed IPA from the archive",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        await exportArchive(context, args.version, "export", p.exportDir);
        return await record(
          context,
          "exportIpa",
          args.version,
          `exported to ${p.exportDir}`,
        );
      },
    },

    verifyIpa: {
      description:
        "Check the IPA is signed for distribution with a production push entitlement",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        const { signal } = context;
        await Deno.remove(p.ipaPayload, { recursive: true }).catch(() => {});
        await Deno.mkdir(p.ipaPayload, { recursive: true });
        await runOrThrow(
          "unzipping the IPA",
          "unzip",
          [
            "-q",
            join(p.exportDir, "MobileOrg.ipa"),
            "-d",
            p.ipaPayload,
          ],
          p.project,
          signal,
        );
        const app = join(p.ipaPayload, "Payload/MobileOrg.app");

        // codesign reports on stderr.
        const signature = (await runOrThrow(
          "reading the code signature",
          "codesign",
          ["-dvv", app],
          p.project,
          signal,
        )).stderr;
        const distribution = new RegExp(
          `Authority=Apple Distribution: .* \\(${context.globalArgs.teamId}\\)`,
        );
        if (!distribution.test(signature)) {
          throw new Error(
            `IPA is not signed with the Apple Distribution certificate for team ${context.globalArgs.teamId}`,
          );
        }

        const profile = join(p.releaseDir, "profile.plist");
        const decoded = await runOrThrow(
          "decoding the provisioning profile",
          "security",
          ["cms", "-D", "-i", join(app, "embedded.mobileprovision")],
          p.project,
          signal,
        );
        await Deno.writeTextFile(profile, decoded.stdout);
        const push = await plistValue(
          profile,
          "Entitlements:aps-environment",
          p.project,
          signal,
        );
        if (push !== "production") {
          throw new Error(
            `profile has aps-environment=${push}, expected production`,
          );
        }
        const debuggable = await plistValue(
          profile,
          "Entitlements:get-task-allow",
          p.project,
          signal,
        );
        if (debuggable !== "false") {
          throw new Error("profile allows debugging (get-task-allow)");
        }

        const infoPlist = join(app, "Info.plist");
        const version = await plistValue(
          infoPlist,
          "CFBundleShortVersionString",
          p.project,
          signal,
        );
        const build = await plistValue(
          infoPlist,
          "CFBundleVersion",
          p.project,
          signal,
        );
        return await record(
          context,
          "verifyIpa",
          args.version,
          `Apple Distribution, production push, version ${version} build ${build}`,
          build,
        );
      },
    },

    upload: {
      description:
        "Upload the archive to App Store Connect. This cannot be undone; run it only after approval",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        const result = await exportArchive(
          context,
          args.version,
          "upload",
          join(p.releaseDir, "upload"),
        );
        const output = `${result.stdout}\n${result.stderr}`;
        if (!output.includes("Upload succeeded")) {
          throw new Error(
            `xcodebuild finished without reporting a successful upload:\n${
              excerpt(output)
            }`,
          );
        }
        return await record(
          context,
          "upload",
          args.version,
          "uploaded to App Store Connect",
        );
      },
    },
  },
};
