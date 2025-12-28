import "dotenv/config";
import { Database } from "bun:sqlite";
import path from "node:path";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { DATABASE_URL } from "../core/constants";
import * as schema from "./schema";
import fs from "node:fs/promises";
import { config } from "../core/config";
import { isLinux, isDarwin } from "../utils/platform";

await fs.mkdir(path.dirname(DATABASE_URL), { recursive: true });

const sqlite = new Database(DATABASE_URL);
export const db = drizzle({ client: sqlite, schema });

export const runDbMigrations = () => {
	let migrationsFolder: string;

	if (config.__prod__) {
		if (isDarwin()) {
			// macOS production - migrations copied alongside app by install.sh
			migrationsFolder = path.join(process.cwd(), "migrations");
		} else {
			// Docker/Linux production
			migrationsFolder = path.join("/app", "assets", "migrations");
		}
	} else if (isLinux()) {
		// Development on Linux (Docker)
		migrationsFolder = path.join("/app", "app", "drizzle");
	} else {
		// Development on macOS (native) or other platforms
		migrationsFolder = path.join(process.cwd(), "app", "drizzle");
	}

	migrate(db, { migrationsFolder });

	sqlite.run("PRAGMA foreign_keys = ON;");
};
