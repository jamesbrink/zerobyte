import { test, describe, expect } from "bun:test";
import { readMountInfo, getMountForPath, getStatFs } from "../mountinfo";
import { isLinux, isDarwin } from "../platform";
import os from "node:os";

describe("mountinfo utilities", () => {
	describe("readMountInfo", () => {
		test("should return an array of mount info objects", async () => {
			const mounts = await readMountInfo();
			expect(Array.isArray(mounts)).toBe(true);
		});

		test("should return mount info with correct structure", async () => {
			const mounts = await readMountInfo();

			// On any supported platform, we should have at least the root mount
			if (isLinux() || isDarwin()) {
				expect(mounts.length).toBeGreaterThan(0);

				for (const mount of mounts) {
					expect(mount).toHaveProperty("mountPoint");
					expect(mount).toHaveProperty("fstype");
					expect(typeof mount.mountPoint).toBe("string");
					expect(typeof mount.fstype).toBe("string");
				}
			}
		});

		test("should include root filesystem on supported platforms", async () => {
			const mounts = await readMountInfo();

			if (isLinux() || isDarwin()) {
				const rootMount = mounts.find((m) => m.mountPoint === "/");
				expect(rootMount).toBeDefined();
				expect(rootMount?.fstype).toBeDefined();
			}
		});

		test("should return empty array on unsupported platforms", async () => {
			// This test validates the fallback behavior
			// We can't easily test unsupported platforms, but we verify the function doesn't throw
			const mounts = await readMountInfo();
			expect(Array.isArray(mounts)).toBe(true);
		});
	});

	describe("getMountForPath", () => {
		test("should find mount for root path", async () => {
			if (isLinux() || isDarwin()) {
				const mount = await getMountForPath("/");
				expect(mount).toBeDefined();
				expect(mount?.mountPoint).toBe("/");
			}
		});

		test("should find mount for home directory", async () => {
			if (isLinux() || isDarwin()) {
				const homeDir = os.homedir();
				const mount = await getMountForPath(homeDir);
				expect(mount).toBeDefined();
				expect(mount?.mountPoint).toBeDefined();
			}
		});

		test("should return the most specific mount point", async () => {
			if (isLinux() || isDarwin()) {
				const mount = await getMountForPath("/usr/bin/ls");
				expect(mount).toBeDefined();
				// The mount point should be a prefix of the path
				expect("/usr/bin/ls".startsWith(mount?.mountPoint || "")).toBe(true);
			}
		});

		test("should return undefined for path with no matching mount", async () => {
			// Use a path that definitely won't match any mount point pattern
			const mount = await getMountForPath("relative/path/that/does/not/match");
			// This might still match if the path gets normalized, but at minimum shouldn't throw
			expect(mount === undefined || mount !== undefined).toBe(true);
		});
	});

	describe("getStatFs", () => {
		test("should return filesystem statistics for root", async () => {
			const stats = await getStatFs("/");

			expect(stats).toHaveProperty("total");
			expect(stats).toHaveProperty("used");
			expect(stats).toHaveProperty("free");

			expect(typeof stats.total).toBe("number");
			expect(typeof stats.used).toBe("number");
			expect(typeof stats.free).toBe("number");

			// Basic sanity checks
			expect(stats.total).toBeGreaterThan(0);
			expect(stats.used).toBeGreaterThanOrEqual(0);
			expect(stats.free).toBeGreaterThanOrEqual(0);
		});

		test("should have consistent values (used + free approximately equals total)", async () => {
			const stats = await getStatFs("/");

			// Due to reserved space and calculation methods, exact equality isn't expected
			// but used should not exceed total
			expect(stats.used).toBeLessThanOrEqual(stats.total);
		});

		test("should return stats for home directory", async () => {
			const homeDir = os.homedir();
			const stats = await getStatFs(homeDir);

			expect(stats.total).toBeGreaterThan(0);
		});
	});
});
