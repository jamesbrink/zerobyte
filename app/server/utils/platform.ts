import os from "node:os";
import path from "node:path";

export type Platform = "linux" | "darwin" | "unsupported";

/**
 * Returns the current platform identifier
 */
export const getPlatform = (): Platform => {
	const p = os.platform();
	if (p === "linux") return "linux";
	if (p === "darwin") return "darwin";
	return "unsupported";
};

export const isLinux = () => getPlatform() === "linux";
export const isDarwin = () => getPlatform() === "darwin";

export type PlatformPaths = {
	dataBase: string;
	volumeMountBase: string;
	repositoryBase: string;
	databaseUrl: string;
	resticPassFile: string;
	resticCacheDir: string;
	sshKeysDir: string;
	rcloneConfigDir: string;
};

/**
 * Returns platform-specific paths for Zerobyte data storage.
 * - Linux: /var/lib/zerobyte/
 * - macOS: ~/Library/Application Support/zerobyte/
 */
export const getPaths = (): PlatformPaths => {
	const platform = getPlatform();

	if (platform === "linux") {
		const base = "/var/lib/zerobyte";
		return {
			dataBase: base,
			volumeMountBase: path.join(base, "volumes"),
			repositoryBase: path.join(base, "repositories"),
			databaseUrl: process.env.DATABASE_URL || path.join(base, "data", "ironmount.db"),
			resticPassFile: path.join(base, "data", "restic.pass"),
			resticCacheDir: path.join(base, "restic", "cache"),
			sshKeysDir: path.join(base, "ssh"),
			rcloneConfigDir: "/root/.config/rclone",
		};
	}

	if (platform === "darwin") {
		const homeDir = os.homedir();
		const appSupport = path.join(homeDir, "Library", "Application Support", "zerobyte");
		return {
			dataBase: appSupport,
			volumeMountBase: path.join(appSupport, "volumes"),
			repositoryBase: path.join(appSupport, "repositories"),
			databaseUrl: process.env.DATABASE_URL || path.join(appSupport, "data", "ironmount.db"),
			resticPassFile: path.join(appSupport, "data", "restic.pass"),
			resticCacheDir: path.join(appSupport, "restic", "cache"),
			sshKeysDir: path.join(appSupport, "ssh"),
			rcloneConfigDir: path.join(homeDir, ".config", "rclone"),
		};
	}

	// Fallback for unsupported platforms - use current directory
	const base = process.cwd();
	return {
		dataBase: base,
		volumeMountBase: path.join(base, "volumes"),
		repositoryBase: path.join(base, "repositories"),
		databaseUrl: process.env.DATABASE_URL || path.join(base, "data", "ironmount.db"),
		resticPassFile: path.join(base, "data", "restic.pass"),
		resticCacheDir: path.join(base, "restic", "cache"),
		sshKeysDir: path.join(base, "ssh"),
		rcloneConfigDir: path.join(base, ".config", "rclone"),
	};
};
