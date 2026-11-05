import { z } from "npm:zod@4.1.5";
import { join, resolve, sep } from "node:path";

const ARCHIVE_NAME = "MobileOrg.xcarchive";
const SOURCE_INFO_PLIST = "MobileOrg-Info.plist";
const APP_KEY_PLIST = "Configuration/AppKey.plist";
const APP_KEY_PATH = "Dropbox\\ API\\ Key:AppKey";
const PLACEHOLDER_APP_KEY = "YourAppKey";
const MINIMUM_DEPLOYMENT_TARGET = 13;
const PLIST_BUDDY = "/usr/libexec/PlistBuddy";

const SECOND = 1000;
const QUICK_TIMEOUT = 60 * SECOND;
const TOOL_TIMEOUT = 5 * 60 * SECOND;
const BUILD_TIMEOUT = 30 * 60 * SECOND;
const UPLOAD_TIMEOUT = 60 * 60 * SECOND;

/** A value xcodebuild receives as an argument. It must not start with "-". */
const XcodebuildArgSchema = z.string().regex(
  /^[A-Za-z0-9][A-Za-z0-9 ._,=:/()'-]*$/,
  "must start with a letter or digit and use only letters, digits, spaces and . _ , = : / ( ) ' -",
);

const GlobalArgsSchema = z.object({
  projectDir: z.string().default("..").describe(
    "MobileOrg checkout, relative to the swamp repository",
  ),
  outputDir: z.string().default("swamp/build/release").describe(
    "Archive and export directory. It must resolve inside projectDir",
  ),
  teamId: z.string().regex(/^[A-Z0-9]{10}$/).describe(
    "Apple Developer team ID used to sign the export and upload",
  ),
  scheme: XcodebuildArgSchema.default("MobileOrg"),
  configuration: XcodebuildArgSchema.default("AppStore"),
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
  readResource: (
    instanceName: string,
  ) => Promise<Record<string, unknown> | null>;
  writeResource: (
    specName: string,
    name: string,
    data: Record<string, unknown>,
  ) => Promise<{ name: string }>;
}

/** The files and directories one release version works with. */
export interface ReleasePaths {
  project: string;
  releaseDir: string;
  archive: string;
  app: string;
  exportDir: string;
  ipaPayload: string;
  ipaApp: string;
}

/** Where and how long a command runs. */
interface Where {
  cwd: string;
  signal: AbortSignal;
  timeoutMs: number;
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

/** Whether `child` is a path strictly inside `parent`. */
export function isInside(parent: string, child: string): boolean {
  return resolve(child).startsWith(resolve(parent) + sep);
}

/** Whether a MinimumOSVersion string such as "13.0" meets the App Store floor. */
export function meetsDeploymentTarget(
  minimumOs: string,
  minimum = MINIMUM_DEPLOYMENT_TARGET,
): boolean {
  const major = Number.parseInt(minimumOs, 10);
  return Number.isInteger(major) && major >= minimum;
}

/** What `upload` compares before it sends a build to App Store Connect. */
export interface UploadCheck {
  version: string;
  expectedBuild: string;
  archiveVersion: string;
  archiveBuild: string;
  ipaVersion: string;
  ipaBuild: string;
  verified: Record<string, unknown> | null;
  archiveBuiltAt: Date;
}

/**
 * Throw unless the archive and IPA on disk are the build that `verifyIpa`
 * checked and the build the operator approved. An upload cannot be undone.
 */
export function assertUploadable(check: UploadCheck): void {
  const problems: string[] = [];
  if (check.expectedBuild === "") problems.push("no approved build number");
  if (check.verified === null) {
    problems.push("verifyIpa has not recorded a result");
  } else {
    if (check.verified.version !== check.version) {
      problems.push(
        `verifyIpa checked version ${check.verified.version}, not ${check.version}`,
      );
    }
    if (check.verified.build !== check.expectedBuild) {
      problems.push(
        `verifyIpa checked build ${check.verified.build}, not the approved build ${check.expectedBuild}`,
      );
    }
    const verifiedAt = Date.parse(String(check.verified.completedAt));
    if (!(verifiedAt >= check.archiveBuiltAt.getTime())) {
      problems.push("the archive was rebuilt after verifyIpa checked it");
    }
  }
  if (check.archiveVersion !== check.version) {
    problems.push(
      `the archive has version ${check.archiveVersion}, not ${check.version}`,
    );
  }
  if (check.archiveBuild !== check.expectedBuild) {
    problems.push(
      `the archive has build ${check.archiveBuild}, not the approved build ${check.expectedBuild}`,
    );
  }
  if (check.ipaVersion !== check.version) {
    problems.push(
      `the verified IPA has version ${check.ipaVersion}, not ${check.version}`,
    );
  }
  if (check.ipaBuild !== check.expectedBuild) {
    problems.push(
      `the verified IPA has build ${check.ipaBuild}, not the approved build ${check.expectedBuild}`,
    );
  }
  if (problems.length > 0) {
    throw new Error(`refusing to upload:\n- ${problems.join("\n- ")}`);
  }
}

/** A command that ran past its deadline, so its outcome is unknown. */
export class CommandTimeout extends Error {
  constructor(command: string, timeoutMs: number) {
    super(`${command} timed out after ${timeoutMs / SECOND} seconds`);
    this.name = "CommandTimeout";
  }
}

/** The recorded outcomes of earlier upload attempts. */
export interface UploadHistory {
  version: string;
  build: string;
  attempted: Record<string, unknown> | null;
  uploaded: Record<string, unknown> | null;
  failed: Record<string, unknown> | null;
  archived: Record<string, unknown> | null;
}

function recordedAt(record: Record<string, unknown> | null): number {
  return record === null ? Number.NaN : Date.parse(String(record.completedAt));
}

function isFor(
  record: Record<string, unknown> | null,
  version: string,
  build: string,
): boolean {
  return record !== null && record.version === version &&
    record.build === build;
}

/**
 * Whether an earlier upload of this build started and never reported an
 * outcome, so it may have reached App Store Connect. Rebuilding the archive
 * starts a new attempt.
 */
export function interruptedUpload(history: UploadHistory): boolean {
  const { version, build } = history;
  if (!isFor(history.attempted, version, build)) return false;
  const attemptedAt = recordedAt(history.attempted);
  if (Number.isNaN(attemptedAt)) return true;
  if (recordedAt(history.archived) > attemptedAt) return false;
  return ![history.uploaded, history.failed].some((outcome) =>
    isFor(outcome, version, build) && recordedAt(outcome) >= attemptedAt
  );
}

async function run(
  command: string,
  args: string[],
  where: Where,
): Promise<CommandResult> {
  const deadline = AbortSignal.timeout(where.timeoutMs);
  try {
    const output = await new Deno.Command(command, {
      args,
      cwd: where.cwd,
      stdout: "piped",
      stderr: "piped",
      signal: AbortSignal.any([where.signal, deadline]),
    }).output();
    const decoder = new TextDecoder();
    return {
      code: output.code,
      stdout: decoder.decode(output.stdout),
      stderr: decoder.decode(output.stderr),
    };
  } catch (error) {
    if (deadline.aborted) {
      throw new CommandTimeout(command, where.timeoutMs);
    }
    throw error;
  }
}

async function runOrThrow(
  label: string,
  command: string,
  args: string[],
  where: Where,
): Promise<CommandResult> {
  const result = await run(command, args, where);
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
  where: Where,
): Promise<string> {
  const result = await runOrThrow(
    `reading ${keyPath} from ${file}`,
    PLIST_BUDDY,
    ["-c", `print :${keyPath}`, file],
    where,
  );
  return result.stdout.trim();
}

/** Read what is on disk and in the stored results for `assertUploadable`. */
export async function readUploadCheck(
  context: Pick<ReleaseContext, "signal" | "readResource">,
  p: ReleasePaths,
  version: string,
  expectedBuild: string,
): Promise<UploadCheck> {
  const quick: Where = {
    cwd: p.project,
    signal: context.signal,
    timeoutMs: QUICK_TIMEOUT,
  };
  const archiveInfo = join(p.app, "Info.plist");
  const ipaInfo = join(p.ipaApp, "Info.plist");
  return {
    version,
    expectedBuild,
    archiveVersion: await plistValue(
      archiveInfo,
      "CFBundleShortVersionString",
      quick,
    ),
    archiveBuild: await plistValue(archiveInfo, "CFBundleVersion", quick),
    ipaVersion: await plistValue(ipaInfo, "CFBundleShortVersionString", quick),
    ipaBuild: await plistValue(ipaInfo, "CFBundleVersion", quick),
    verified: await context.readResource("verifyIpa"),
    archiveBuiltAt: (await Deno.stat(archiveInfo)).mtime ?? new Date(),
  };
}

/** Remove a file or directory, ignoring only that it does not exist. */
async function removeIfExists(path: string): Promise<void> {
  try {
    await Deno.remove(path, { recursive: true });
  } catch (error) {
    if (!(error instanceof Deno.errors.NotFound)) throw error;
  }
}

function paths(context: ReleaseContext, version: string): ReleasePaths {
  const project = resolve(context.repoDir, context.globalArgs.projectDir);
  const releaseDir = resolve(project, context.globalArgs.outputDir, version);
  if (!isInside(project, releaseDir)) {
    throw new Error(
      `outputDir ${context.globalArgs.outputDir} resolves outside projectDir`,
    );
  }
  return {
    project,
    releaseDir,
    archive: join(releaseDir, ARCHIVE_NAME),
    app: join(releaseDir, ARCHIVE_NAME, "Products/Applications/MobileOrg.app"),
    exportDir: join(releaseDir, "export"),
    ipaPayload: join(releaseDir, "ipa"),
    ipaApp: join(releaseDir, "ipa", "Payload/MobileOrg.app"),
  };
}

function inProject(
  context: ReleaseContext,
  project: string,
  timeoutMs: number,
): Where {
  return { cwd: project, signal: context.signal, timeoutMs };
}

async function record(
  context: ReleaseContext,
  step: string,
  version: string,
  summary: string,
  build?: string,
) {
  return await context.writeResource("result", step, {
    step,
    version,
    summary,
    ...(build ? { build } : {}),
    completedAt: new Date().toISOString(),
  });
}

async function exportArchive(
  context: ReleaseContext,
  version: string,
  destination: "export" | "upload",
  exportPath: string,
  timeoutMs: number,
): Promise<CommandResult> {
  const p = paths(context, version);
  const optionsFile = join(p.releaseDir, `${destination}-options.plist`);
  await Deno.writeTextFile(
    optionsFile,
    exportOptionsPlist(context.globalArgs.teamId, destination),
  );
  await removeIfExists(exportPath);
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
    inProject(context, p.project, timeoutMs),
  );
}

export const model = {
  type: "@mobileorg/ios-release",
  version: "2026.11.05.2",
  globalArguments: GlobalArgsSchema,
  resources: {
    result: {
      description: "Outcome of one release step",
      schema: ResultSchema,
      lifetime: "infinite",
      garbageCollection: 10,
    },
  },
  upgrades: [
    {
      toVersion: "2026.11.05.2",
      description:
        "Stricter validation of scheme and configuration; no fields added, removed or renamed",
      upgradeAttributes: (old: Record<string, unknown>) => old,
    },
  ],
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
        const quick = inProject(context, project, QUICK_TIMEOUT);

        const branch = (await runOrThrow(
          "reading the current branch",
          "git",
          ["rev-parse", "--abbrev-ref", "HEAD"],
          quick,
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
          quick,
        )).stdout.trim();
        if (changes) {
          throw new Error(
            `tracked files have uncommitted changes:\n${changes}`,
          );
        }

        const sourceVersion = await plistValue(
          join(project, SOURCE_INFO_PLIST),
          "CFBundleShortVersionString",
          quick,
        );
        if (sourceVersion !== args.version) {
          throw new Error(
            `${SOURCE_INFO_PLIST} has version ${sourceVersion}, expected ${args.version}`,
          );
        }

        const appKey = await plistValue(
          join(project, APP_KEY_PLIST),
          APP_KEY_PATH,
          quick,
        );
        if (appKey === "" || appKey === PLACEHOLDER_APP_KEY) {
          throw new Error(`${APP_KEY_PLIST} still holds the placeholder key`);
        }
        const flags = (await runOrThrow(
          "reading the AppKey.plist index flags",
          "git",
          ["ls-files", "-v", APP_KEY_PLIST],
          quick,
        )).stdout;
        if (!flags.startsWith("S")) {
          throw new Error(
            `${APP_KEY_PLIST} is not marked skip-worktree; the key could be committed`,
          );
        }

        const handle = await record(
          context,
          "verifySource",
          args.version,
          `branch ${branch}, clean tree, version ${sourceVersion}, Dropbox key set`,
        );
        return { dataHandles: [handle] };
      },
    },

    test: {
      description: "Run the unit tests on a simulator",
      arguments: z.object({
        version: VersionSchema,
        destination: XcodebuildArgSchema.default(
          "platform=iOS Simulator,name=iPhone 17",
        ).describe("xcodebuild destination for the tests"),
      }),
      execute: async (
        args: { version: string; destination: string },
        context: ReleaseContext,
      ) => {
        const { project } = paths(context, args.version);
        await runOrThrow("xcodebuild test", "xcodebuild", [
          "test",
          "-scheme",
          context.globalArgs.scheme,
          "-destination",
          args.destination,
        ], inProject(context, project, BUILD_TIMEOUT));
        const handle = await record(
          context,
          "test",
          args.version,
          `unit tests passed on ${args.destination}`,
        );
        return { dataHandles: [handle] };
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
        await removeIfExists(p.releaseDir);
        await Deno.mkdir(p.releaseDir, { recursive: true });
        await runOrThrow("xcodebuild archive", "xcodebuild", [
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
        ], inProject(context, p.project, BUILD_TIMEOUT));
        const handle = await record(
          context,
          "archive",
          args.version,
          `archived to ${p.archive}`,
        );
        return { dataHandles: [handle] };
      },
    },

    verifyArchive: {
      description:
        "Check the archived app's version, deployment target and Dropbox URL scheme",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        const quick = inProject(context, p.project, QUICK_TIMEOUT);
        const plist = join(p.app, "Info.plist");
        const version = await plistValue(
          plist,
          "CFBundleShortVersionString",
          quick,
        );
        const build = await plistValue(plist, "CFBundleVersion", quick);
        const minimumOs = await plistValue(plist, "MinimumOSVersion", quick);
        const scheme = await plistValue(
          plist,
          "CFBundleURLTypes:0:CFBundleURLSchemes:0",
          quick,
        );
        const appKey = await plistValue(
          join(p.project, APP_KEY_PLIST),
          APP_KEY_PATH,
          quick,
        );
        if (version !== args.version) {
          throw new Error(
            `archive has version ${version}, expected ${args.version}`,
          );
        }
        const commits = (await runOrThrow(
          "counting commits",
          "git",
          ["rev-list", "HEAD", "--count"],
          quick,
        )).stdout.trim();
        if (build !== commits) {
          throw new Error(
            `archive has build ${build}, but the source has ${commits} commits; the build number script did not run on this commit`,
          );
        }
        if (!meetsDeploymentTarget(minimumOs)) {
          throw new Error(
            `archive targets iOS "${minimumOs}"; App Store Connect requires ${MINIMUM_DEPLOYMENT_TARGET} or later`,
          );
        }
        if (appKey === "" || appKey === PLACEHOLDER_APP_KEY) {
          throw new Error(`${APP_KEY_PLIST} still holds the placeholder key`);
        }
        if (scheme !== `db-${appKey}`) {
          throw new Error(
            "the archive's Dropbox URL scheme does not match the key in AppKey.plist",
          );
        }
        const handle = await record(
          context,
          "verifyArchive",
          args.version,
          `version ${version} build ${build}, minimum iOS ${minimumOs}, Dropbox URL scheme matches the key`,
          build,
        );
        return { dataHandles: [handle] };
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
        await exportArchive(
          context,
          args.version,
          "export",
          p.exportDir,
          BUILD_TIMEOUT,
        );
        const handle = await record(
          context,
          "exportIpa",
          args.version,
          `exported to ${p.exportDir}`,
        );
        return { dataHandles: [handle] };
      },
    },

    verifyIpa: {
      description:
        "Check the IPA's version, that its signature is valid and from the Apple Distribution certificate, and that its signed entitlements have production push and no debugging",
      arguments: VersionArgsSchema,
      execute: async (
        args: z.infer<typeof VersionArgsSchema>,
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        const quick = inProject(context, p.project, QUICK_TIMEOUT);
        const tool = inProject(context, p.project, TOOL_TIMEOUT);
        await removeIfExists(p.ipaPayload);
        await Deno.mkdir(p.ipaPayload, { recursive: true });
        await runOrThrow("unzipping the IPA", "unzip", [
          "-q",
          join(p.exportDir, "MobileOrg.ipa"),
          "-d",
          p.ipaPayload,
        ], tool);

        await runOrThrow(
          "verifying the code signature",
          "codesign",
          ["--verify", "--deep", "--strict", p.ipaApp],
          tool,
        );
        // codesign reports the signing authority on stderr.
        const signature = (await runOrThrow(
          "reading the code signature",
          "codesign",
          ["-dvv", p.ipaApp],
          tool,
        )).stderr;
        const distribution = new RegExp(
          `Authority=Apple Distribution: .* \\(${context.globalArgs.teamId}\\)`,
        );
        if (!distribution.test(signature)) {
          throw new Error(
            `IPA is not signed with the Apple Distribution certificate for team ${context.globalArgs.teamId}`,
          );
        }

        const entitlements = join(p.releaseDir, "entitlements.plist");
        const signed = await runOrThrow(
          "reading the signed entitlements",
          "codesign",
          ["-d", "--entitlements", ":-", p.ipaApp],
          tool,
        );
        await Deno.writeTextFile(entitlements, signed.stdout);
        const push = await plistValue(
          entitlements,
          "aps-environment",
          quick,
        );
        if (push !== "production") {
          throw new Error(
            `signed entitlements have aps-environment=${push}, expected production`,
          );
        }
        // An App Store signature normally omits get-task-allow. Only a value
        // of true is a problem.
        const debuggable = await run(
          PLIST_BUDDY,
          ["-c", "print :get-task-allow", entitlements],
          quick,
        );
        if (debuggable.code === 0 && debuggable.stdout.trim() === "true") {
          throw new Error(
            "signed entitlements allow debugging (get-task-allow)",
          );
        }

        const infoPlist = join(p.ipaApp, "Info.plist");
        const version = await plistValue(
          infoPlist,
          "CFBundleShortVersionString",
          quick,
        );
        const build = await plistValue(infoPlist, "CFBundleVersion", quick);
        if (version !== args.version) {
          throw new Error(
            `IPA has version ${version}, expected ${args.version}`,
          );
        }
        const handle = await record(
          context,
          "verifyIpa",
          args.version,
          `valid Apple Distribution signature, production push, version ${version} build ${build}`,
          build,
        );
        return { dataHandles: [handle] };
      },
    },

    upload: {
      description:
        "Upload the archive to App Store Connect. This cannot be undone. It refuses unless the archive and the verified IPA are the approved build. It exports and signs again from the archive, so the signature checks of verifyIpa cover the earlier export, not the file that is sent",
      arguments: z.object({
        version: VersionSchema,
        expectedBuild: z.string().min(
          1,
          "no approved build: resume the run with --input approvedBuild=<the build shown at the approval>",
        ).describe(
          "The build number verifyIpa reported and the operator approved",
        ),
      }),
      execute: async (
        args: { version: string; expectedBuild: string },
        context: ReleaseContext,
      ) => {
        const p = paths(context, args.version);
        assertUploadable(
          await readUploadCheck(context, p, args.version, args.expectedBuild),
        );
        if (
          interruptedUpload({
            version: args.version,
            build: args.expectedBuild,
            attempted: await context.readResource("uploadAttempted"),
            uploaded: await context.readResource("upload"),
            failed: await context.readResource("uploadFailed"),
            archived: await context.readResource("archive"),
          })
        ) {
          throw new Error(
            `an earlier upload of build ${args.expectedBuild} did not report an outcome, so it may have reached App Store Connect. Check App Store Connect. If the build is not there, run the workflow again to rebuild the archive`,
          );
        }

        // Recorded before the upload so a cancelled or timed-out run still
        // shows that an upload may have reached App Store Connect.
        const attempted = await record(
          context,
          "uploadAttempted",
          args.version,
          `uploading build ${args.expectedBuild}`,
          args.expectedBuild,
        );
        let result: CommandResult;
        try {
          result = await exportArchive(
            context,
            args.version,
            "upload",
            join(p.releaseDir, "upload"),
            UPLOAD_TIMEOUT,
          );
        } catch (error) {
          // A timeout or a cancellation leaves the outcome unknown. Any other
          // failure is xcodebuild reporting that the upload did not complete,
          // so record it and allow a retry.
          if (error instanceof CommandTimeout || context.signal.aborted) {
            throw error;
          }
          await record(
            context,
            "uploadFailed",
            args.version,
            "xcodebuild reported that the upload failed",
            args.expectedBuild,
          );
          throw error;
        }
        const confirmed = /upload succeeded/i.test(
          `${result.stdout}\n${result.stderr}`,
        );
        const uploaded = await record(
          context,
          "upload",
          args.version,
          confirmed
            ? `uploaded build ${args.expectedBuild} to App Store Connect`
            : `xcodebuild exited 0 for build ${args.expectedBuild} without printing an upload confirmation; check App Store Connect before running again`,
          args.expectedBuild,
        );
        return { dataHandles: [attempted, uploaded] };
      },
    },
  },
};
