import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";
import { reactRouterHonoServer } from "react-router-hono-server/dev";

export default defineConfig({
	plugins: [reactRouterHonoServer({ runtime: "bun" }), reactRouter(), tailwindcss(), tsconfigPaths()],
	build: {
		outDir: "dist",
		sourcemap: false,
		rollupOptions: {
			external: ["bun"],
		},
	},
	server: {
		host: true,
		port: 4096,
	},
	optimizeDeps: {
		include: [
			// Core libraries
			"@tanstack/react-query",
			"react-hook-form",
			"@hookform/resolvers",
			"@hookform/resolvers/arktype",
			"arktype",
			"sonner",
			"lucide-react",
			"next-themes",
			"recharts",
			"date-fns",
			"cron-parser",
			// Radix UI components
			"@radix-ui/react-dialog",
			"@radix-ui/react-select",
			"@radix-ui/react-tooltip",
			"@radix-ui/react-tabs",
			"@radix-ui/react-alert-dialog",
			"@radix-ui/react-slot",
			"@radix-ui/react-separator",
			"@radix-ui/react-checkbox",
			"@radix-ui/react-switch",
			"@radix-ui/react-label",
			"@radix-ui/react-progress",
			// Utility libraries
			"class-variance-authority",
			"clsx",
			"tailwind-merge",
		],
	},
});
