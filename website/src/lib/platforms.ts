export type Platform = "macos" | "windows";

type AvailableRelease = {
  status: "available";
  version: string;
  downloadUrl: string;
  requirements: string;
  architecture: string;
  releaseNotesUrl: string;
};

type UpcomingRelease = {
  status: "development";
  version?: never;
  downloadUrl?: never;
  requirements?: never;
  architecture?: never;
  releaseNotesUrl?: never;
};

export type PlatformRelease = {
  name: string;
  shortName: string;
  repositoryUrl: string | null;
} & (AvailableRelease | UpcomingRelease);

export const MAC_REPO = "https://github.com/RokiTheWise/DClutter";

// Windows is intentionally not given a download or minimum OS until its release
// is confirmed. To launch it, replace the development record with a complete
// available release. Both download areas and installation copy use this record.
export const platforms: Record<Platform, PlatformRelease> = {
  macos: {
    name: "macOS",
    shortName: "Mac",
    status: "available",
    version: "1.1.0",
    downloadUrl: `${MAC_REPO}/releases/download/v1.1.0/DClutter-1.1.0.zip`,
    requirements: "macOS 14+",
    architecture: "Apple Silicon & Intel",
    repositoryUrl: MAC_REPO,
    releaseNotesUrl: `${MAC_REPO}/releases/tag/v1.1.0`,
  },
  windows: {
    name: "Windows",
    shortName: "Windows",
    status: "development",
    repositoryUrl: "https://github.com/RokiTheWise/DClutter-Windows",
  },
};

export function platformFromUserAgent(userAgent: string): Platform {
  return /Windows NT/i.test(userAgent) ? "windows" : "macos";
}
