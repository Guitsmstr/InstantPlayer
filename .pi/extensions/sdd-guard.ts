/**
 * sdd-guard — deterministic permission enforcement for the InstantPlayer SDD flow.
 *
 * Pi has no declarative tool permissions (the `permissions:` blocks in the old
 * .opencode/agents/*.md). This extension is their deterministic equivalent:
 * the rules live here, keyed by agent role, and every tool call is checked
 * before execution.
 *
 * Role detection: PI_AGENT_NAME is set by the vendored subagent extension
 * (.pi/extensions/subagent/index.ts) for every child process. When the variable
 * is absent we are in the interactive session = coordinator. An unrecognized
 * name is treated as "unknown" and denied everything.
 *
 * Enforcement:
 * - bash: per-role command allowlist matched per shell segment (&&, ||, |, ;,
 *   newline). Hard denies for every role first: command substitution ($(` / `),
 *   redirection (except 2>&1 / >&2), env-var prefixes, and secret files (.env*).
 *   The secret check runs before the allowlist so a `cat *` rule can never
 *   reach a secret.
 * - edit/write: per-role path scopes; never .env*, never .git/**, never outside
 *   the worktree.
 * - read: unrestricted (opencode parity) — secrets are protected at the shell
 *   layer (cat/head/tail/ls denies) and by the edit/write rules below.
 * - step budgets (the opencode `steps:` limits): assistant messages are counted
 *   per process; once the role's budget is exhausted, tool calls are blocked
 *   with a "report to the coordinator" message.
 * - coordinator (interactive session): commands outside its allowlist are asked
 *   via UI (`effect: ask` semantics) and blocked when no UI is present. Hard
 *   denies are never asked.
 *
 * Toggle: /sdd-guard on|off|status
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import path from "node:path";

type Role = "coordinator" | "spec-author" | "implementer" | "implementer-flash" | "validator" | "unknown";

const KNOWN_ROLES: Role[] = ["coordinator", "spec-author", "implementer", "implementer-flash", "validator"];

function currentRole(): Role {
	const name = process.env.PI_AGENT_NAME;
	if (!name) return "coordinator";
	return (KNOWN_ROLES as string[]).includes(name) ? (name as Role) : "unknown";
}

/* ------------------------------------------------------------------ bash */

const READ_ONLY_GIT = ["git status*", "git diff*", "git log*", "git show*", "git rev-parse*", "git ls-files*"];
const READ_ONLY_FILTERS = ["cat *", "head *", "tail *", "echo *", "ls *"];
const GATE = ["./scripts/validate.sh*"];

const SHELL_ALLOW: Record<Role, string[]> = {
	coordinator: [], // coordinator is allowlist + ask (see below), never plain deny
	"spec-author": [...READ_ONLY_GIT, "git branch", "git branch --show-current*", ...READ_ONLY_FILTERS, "git add *", "git commit *", ...GATE],
	implementer: [
		...READ_ONLY_GIT,
		"git branch",
		"git branch --show-current*",
		...READ_ONLY_FILTERS,
		"git add *",
		"git commit *",
		"git rm *",
		...GATE,
		"./scripts/app.sh*",
		"./scripts/repo-fs.sh*",
		"swiftlint *",
		"swiftformat --lint*",
	],
	"implementer-flash": [
		...READ_ONLY_GIT,
		"git branch",
		"git branch --show-current*",
		...READ_ONLY_FILTERS,
		"git add *",
		"git commit *",
		"git rm *",
		...GATE,
		"./scripts/app.sh*",
		"./scripts/repo-fs.sh*",
		"swiftlint *",
		"swiftformat --lint*",
	],
	validator: [...READ_ONLY_GIT, ...READ_ONLY_FILTERS, ...GATE, "./scripts/app.sh status*"],
	unknown: [],
};

const COORDINATOR_SHELL = [
	...READ_ONLY_GIT,
	"git branch*",
	...READ_ONLY_FILTERS,
	"git add *",
	"git commit *",
	"git rm *",
	"git switch *",
	"git merge *",
	...GATE,
	"./scripts/app.sh*",
	"./scripts/repo-fs.sh*",
];

function matchesPattern(segment: string, pattern: string): boolean {
	const seg = segment.replace(/\s+/g, " ").trim();
	const pat = pattern.trim();
	if (pat.endsWith("*")) return seg.startsWith(pat.slice(0, -1));
	return seg === pat;
}

/** Split a compound command into segments; every segment must pass. */
function splitSegments(command: string): string[] {
	return command
		.split(/\s*(?:&&|\|\||[|;]|\r?\n)\s*/)
		.map((s) => s.trim())
		.filter(Boolean);
}

/** Returns a violation reason, or null when the command is acceptable for the role. */
function checkBash(command: string, role: Role): string | null {
	// Hard denies — all roles, never asked, checked before anything else.
	if (command.includes("$(") || command.includes("`")) {
		return "command substitution ($(...)/backticks) is not allowed";
	}
	const withoutStdFd = command.replace(/2>&1/g, "").replace(/>&2/g, "");
	if (/[<>]/.test(withoutStdFd)) {
		return "shell redirection is not allowed (write files with the edit/write tools)";
	}
	for (const segment of splitSegments(command)) {
		if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(segment)) {
			return "env-var command prefixes are not allowed";
		}
		if (/(^|[\s/])\.env/.test(segment)) {
			return "secret files (.env*) are off limits";
		}
	}
	const segments = splitSegments(command);
	if (role === "coordinator") {
		const unknown = segments.find((s) => !COORDINATOR_SHELL.some((p) => matchesPattern(s, p)));
		return unknown === undefined ? null : `__ASK__${unknown}`;
	}
	const allow = SHELL_ALLOW[role];
	const violation = segments.find((s) => !allow.some((p) => matchesPattern(s, p)));
	return violation === undefined ? null : `command not in the ${role} allowlist: ${violation}`;
}

/* --------------------------------------------------------------- files */

type Scope = string[] | "all" | "none";

const EDIT_SCOPE: Record<Role, Scope> = {
	coordinator: "all",
	"spec-author": ["docs/specs/", "docs/backlog.md", "docs/decisions.md"],
	implementer: "all",
	"implementer-flash": "all",
	validator: "none",
	unknown: "none",
};

function checkPath(p: string, role: Role, cwd: string): string | null {
	const abs = path.resolve(cwd, p);
	const root = path.resolve(cwd);
	if (abs !== root && !abs.startsWith(root + path.sep)) {
		return `path outside the worktree: ${p}`;
	}
	const rel = path.relative(root, abs);
	if (rel.split(path.sep).includes(".git")) {
		return `.git/** is off limits: ${p}`;
	}
	if (path.basename(rel).startsWith(".env")) {
		return `secret files (.env*) are off limits: ${p}`;
	}
	const scope = EDIT_SCOPE[role];
	if (scope === "all") return null;
	if (scope === "none") return `${role} is read-only: writes are not allowed (${p})`;
	const ok = scope.some((entry) => (entry.endsWith("/") ? rel.startsWith(entry) : rel === entry));
	return ok ? null : `path outside the ${role} edit scope (${scope.join(", ")}): ${p}`;
}

/* ------------------------------------------------------- step budgets */

const STEP_BUDGET: Partial<Record<Role, number>> = {
	"spec-author": 25,
	implementer: 120,
	"implementer-flash": 60,
	validator: 30,
};

let assistantSteps = 0;
let budgetExhausted = false;

/* ------------------------------------------------------------- plugin */

let enabled = true;

export default function sddGuard(pi: ExtensionAPI) {
	pi.on("message_end", async (event) => {
		const message = event.message as { role?: string } | undefined;
		if (message?.role === "assistant") assistantSteps += 1;
		const budget = STEP_BUDGET[currentRole()];
		if (budget !== undefined && assistantSteps > budget) budgetExhausted = true;
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!enabled) return undefined;
		const role = currentRole();

		if (budgetExhausted) {
			return {
				block: true,
				reason: `step budget (${STEP_BUDGET[role]}) exhausted for ${role} — stop and report to the coordinator with the evidence gathered so far`,
			};
		}

		const input = (event.input ?? {}) as { path?: string; command?: string };
		const cwd = ctx.cwd ?? process.cwd();

		if (event.toolName === "bash" && typeof input.command === "string") {
			const violation = checkBash(input.command, role);
			if (violation === null) return undefined;
			if (violation.startsWith("__ASK__")) {
				const command = violation.slice("__ASK__".length);
				if (!ctx.hasUI) {
					return { block: true, reason: `outside the coordinator allowlist (no UI to ask): ${command}` };
				}
				const choice = await ctx.ui.select(
					`⚠️ Outside the SDD shell allowlist:\n\n  ${command}\n\nRun it?`,
					["No", "Yes"],
				);
				return choice === "Yes" ? undefined : { block: true, reason: `Blocked by user: ${command}` };
			}
			return { block: true, reason: `sdd-guard (${role}): ${violation}` };
		}

		if ((event.toolName === "edit" || event.toolName === "write") && typeof input.path === "string") {
			const violation = checkPath(input.path, role, cwd);
			return violation === null ? undefined : { block: true, reason: `sdd-guard (${role}): ${violation}` };
		}

		return undefined;
	});

	pi.registerCommand("sdd-guard", {
		description: "Toggle or inspect sdd-guard enforcement (on|off|status)",
		handler: (arg, ctx) => {
			const mode = (arg ?? "status").trim();
			if (mode === "on" || mode === "off") {
				enabled = mode === "on";
				ctx.ui.notify(`sdd-guard ${enabled ? "enabled" : "disabled"}`, "info");
				return;
			}
			ctx.ui.notify(
				`sdd-guard: ${enabled ? "on" : "off"} · role: ${currentRole()} · steps: ${assistantSteps}`,
				"info",
			);
		},
	});
}
