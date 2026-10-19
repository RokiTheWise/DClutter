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
  id: Platform;
  name: string;
  shortName: string;
  repositoryUrl: string | null;
} & (AvailableRelease | UpcomingRelease);

export const MAC_REPO = "https://github.com/RokiTheWise/DClutter";
export const WIN_REPO = "https://github.com/RokiTheWise/DClutter-Windows";

// These records are the single source of truth for every download link,
// version and requirement on the site.
export const platforms: Record<Platform, PlatformRelease> = {
  macos: {
    id: "macos",
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
    id: "windows",
    name: "Windows",
    shortName: "Windows",
    status: "available",
    version: "1.0.0",
    downloadUrl: `${WIN_REPO}/releases/download/v1.0.0/DClutter_1.0.0_x64-setup.exe`,
    requirements: "Windows 10 or 11",
    architecture: "x64",
    repositoryUrl: WIN_REPO,
    releaseNotesUrl: `${WIN_REPO}/releases/tag/v1.0.0`,
  },
};

/** Both releases, in the order the download buttons show them. */
export const releases = [platforms.macos, platforms.windows] as const;
