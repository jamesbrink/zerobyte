import { getPaths } from "../utils/platform";

export const OPERATION_TIMEOUT = 5000;

const paths = getPaths();

export const VOLUME_MOUNT_BASE = paths.volumeMountBase;
export const REPOSITORY_BASE = paths.repositoryBase;
export const DATABASE_URL = paths.databaseUrl;
export const RESTIC_PASS_FILE = paths.resticPassFile;

export const DEFAULT_EXCLUDES = [DATABASE_URL, RESTIC_PASS_FILE, REPOSITORY_BASE];

export const REQUIRED_MIGRATIONS = ["v0.21.0"];
