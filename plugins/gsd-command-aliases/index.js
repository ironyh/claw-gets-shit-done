import fs from "node:fs";
import path from "node:path";

const ALIASES = {
  "gsd-add-todo": "add-todo",
  "gsd-check-todos": "check-todos",
  "gsd-new-project": "new-project",
  "gsd-progress": "progress",
  "gsd-discuss-phase": "discuss-phase",
  "gsd-plan-phase": "plan-phase",
  "gsd-execute-phase": "execute-phase",
  "gsd-verify-work": "verify-work",
  "gsd-resume-work": "resume-work",
};

function truncate(text, max = 1600) {
  if (!text) return "";
  if (text.length <= max) return text;
  return `${text.slice(0, max)}\n...`;
}

function expandPath(value) {
  if (!value || typeof value !== "string") return "";
  const trimmed = value.trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("~/")) {
    const home = process.env.HOME || "";
    if (!home) return "";
    return path.join(home, trimmed.slice(2));
  }
  return trimmed;
}

function uniq(values) {
  return [...new Set(values.filter(Boolean))];
}

function getPluginConfig(api) {
  const cfg = api?.config;
  if (!cfg || typeof cfg !== "object") return {};
  return cfg;
}

function pickSender(ctx) {
  const sender = (ctx.senderId ?? "").toString().trim();
  if (sender) return sender;
  const from = (ctx.from ?? "").toString().trim();
  if (from) return from;
  return "";
}

function toPosixRel(baseDir, targetPath) {
  return path.relative(baseDir, targetPath).split(path.sep).join("/");
}

function escapeYamlDoubleQuoted(value) {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function inferArea(title) {
  const t = title.toLowerCase();
  if (/(^|\W)(api|endpoint|backend|route|controller)(\W|$)/.test(t)) return "api";
  if (/(^|\W)(ui|ux|modal|button|css|layout|view|frontend|component)(\W|$)/.test(t)) return "ui";
  if (/(^|\W)(auth|token|login|logout|oauth|session)(\W|$)/.test(t)) return "auth";
  if (/(^|\W)(db|database|migration|sql|query)(\W|$)/.test(t)) return "database";
  if (/(^|\W)(test|testing|spec|e2e|unit)(\W|$)/.test(t)) return "testing";
  if (/(^|\W)(doc|docs|readme|guide)(\W|$)/.test(t)) return "docs";
  if (/(^|\W)(planning|roadmap|phase|milestone)(\W|$)/.test(t)) return "planning";
  if (/(^|\W)(script|tool|cli|automation|build)(\W|$)/.test(t)) return "tooling";
  return "general";
}

function formatAge(isoValue) {
  if (!isoValue) return "unknown";
  const then = new Date(isoValue).getTime();
  if (!Number.isFinite(then)) return "unknown";
  const deltaMs = Date.now() - then;
  if (deltaMs < 0) return "0m";
  const mins = Math.floor(deltaMs / 60000);
  if (mins < 60) return `${Math.max(1, mins)}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d`;
  const months = Math.floor(days / 30);
  return `${months}mo`;
}

function findWorkspaceFromPluginSource(api) {
  const pluginDir = path.dirname(api.source);
  return path.resolve(pluginDir, "..", "..");
}

function candidateWorkspaceDirs(api, ctx) {
  const pluginConfig = getPluginConfig(api);
  const home = process.env.HOME || "";
  return uniq([
    expandPath(ctx?.workspaceDir),
    expandPath(ctx?.workingDirectory),
    expandPath(ctx?.cwd),
    expandPath(pluginConfig.workspaceDir),
    expandPath(process.env.GSD_WORKSPACE_DIR),
    expandPath(process.env.OPENCLAW_WORKSPACE),
    process.cwd(),
    findWorkspaceFromPluginSource(api),
    home ? path.join(home, ".openclaw", "workspace") : "",
  ]);
}

function resolveWorkspaceDir(api, ctx) {
  const candidates = candidateWorkspaceDirs(api, ctx);
  for (const dir of candidates) {
    const toolPath = path.join(dir, "skills", "claw-gets-shit-done", "bin", "gsd-tools");
    if (fs.existsSync(toolPath)) return dir;
  }

  for (const dir of candidates) {
    const planningPath = path.join(dir, ".planning");
    if (fs.existsSync(planningPath)) return dir;
  }

  return candidates[0] || findWorkspaceFromPluginSource(api);
}

function resolveGsdToolsPath(api, workspaceDir) {
  const pluginConfig = getPluginConfig(api);
  const home = process.env.HOME || "";
  const candidates = [
    expandPath(process.env.GSD_TOOLS_PATH),
    expandPath(pluginConfig.gsdToolsPath),
    path.join(workspaceDir, "skills", "claw-gets-shit-done", "bin", "gsd-tools"),
    process.env.CODEX_HOME
      ? path.join(process.env.CODEX_HOME, "skills", "claw-gets-shit-done", "bin", "gsd-tools")
      : "",
    home ? path.join(home, ".codex", "skills", "claw-gets-shit-done", "bin", "gsd-tools") : "",
  ];

  for (const dir of candidates) {
    if (dir && fs.existsSync(dir)) return dir;
  }

  return path.join(workspaceDir, "skills", "claw-gets-shit-done", "bin", "gsd-tools");
}

async function runCommand(api, argv, options = {}) {
  const run = await api.runtime.system.runCommandWithTimeout(argv, {
    timeoutMs: options.timeoutMs ?? 45000,
    ...(options.cwd ? { cwd: options.cwd } : {}),
  });

  if (run.code !== 0) {
    const err = (run.stderr || run.stdout || "").trim() || "okänt fel";
    throw new Error(err);
  }

  return (run.stdout || "").trim();
}

async function runGsdTools(api, workspaceDir, args, options = {}) {
  const gsdTools = resolveGsdToolsPath(api, workspaceDir);
  if (!fs.existsSync(gsdTools)) {
    throw new Error(
      `gsd-tools saknas: ${gsdTools}\n` +
        "Sätt GSD_TOOLS_PATH eller GSD_WORKSPACE_DIR om din installation inte använder standard-path.",
    );
  }

  const argv = [gsdTools, ...args, ...(options.raw ? ["--raw"] : [])];
  return await runCommand(api, argv, {
    cwd: workspaceDir,
    timeoutMs: options.timeoutMs ?? 45000,
  });
}

async function runGsdToolsJson(api, workspaceDir, args, options = {}) {
  const out = await runGsdTools(api, workspaceDir, args, {
    ...options,
    raw: true,
  });
  try {
    return JSON.parse(out);
  } catch {
    throw new Error(`Ogiltigt JSON-svar från gsd-tools (${args.join(" ")})`);
  }
}

function extractReplyText(stdout) {
  const trimmed = (stdout ?? "").trim();
  if (!trimmed) return "";

  try {
    const parsed = JSON.parse(trimmed);
    const payloadTexts = Array.isArray(parsed?.result?.payloads)
      ? parsed.result.payloads
          .map((entry) => (typeof entry?.text === "string" ? entry.text.trim() : ""))
          .filter(Boolean)
      : [];
    if (payloadTexts.length > 0) return payloadTexts.join("\n\n");

    const candidates = [
      parsed?.reply?.text,
      parsed?.result?.reply?.text,
      parsed?.text,
      parsed?.result?.text,
      parsed?.message,
    ];
    const first = candidates.find((v) => typeof v === "string" && v.trim().length > 0);
    if (first) return first.trim();
  } catch {
    // Fall through: command may return non-JSON text
  }

  return trimmed;
}

function commandHelp() {
  return [
    "GSD hyphen-aliaser:",
    "- /gsd-add-todo <text> (deterministisk)",
    "- /gsd-check-todos [area] (deterministisk)",
    "- /gsd-progress (deterministisk)",
    "- /gsd-discuss-phase <n>",
    "- /gsd-new-project [--auto]",
    "- /gsd-plan-phase <n>",
    "- /gsd-execute-phase <n>",
    "- /gsd-verify-work [n]",
    "- /gsd-resume-work",
    "",
    "Hyphen-kommandon finns för bättre slash-UX i OpenClaw.",
  ].join("\n");
}

function buildSkillPrompt(gsdCommand, args) {
  const userInput = `${gsdCommand}${args ? ` ${args}` : ""}`;
  return [
    'Use the "gsd" skill for this request.',
    "",
    "User input:",
    userInput,
  ].join("\n");
}

function userFallbackHint(gsdCommand, args) {
  return `Prova igen med: /gsd ${gsdCommand}${args ? ` ${args}` : ""}`;
}

async function handleAddTodo(api, ctx) {
  const args = (ctx.args ?? "").trim();
  if (!args) {
    return {
      text: "Usage: /gsd-add-todo <text>",
    };
  }

  const workspaceDir = resolveWorkspaceDir(api, ctx);
  const pendingDir = path.join(workspaceDir, ".planning", "todos", "pending");
  const completedDir = path.join(workspaceDir, ".planning", "todos", "completed");
  fs.mkdirSync(pendingDir, { recursive: true });
  fs.mkdirSync(completedDir, { recursive: true });

  const init = await runGsdToolsJson(api, workspaceDir, ["init", "todos"]);
  const title = args[0].toUpperCase() + args.slice(1);
  const slug = (await runGsdTools(api, workspaceDir, ["generate-slug", title], { raw: true })).trim();
  const date = (init?.date ?? new Date().toISOString().slice(0, 10)).trim();
  const created = (init?.timestamp ?? new Date().toISOString()).trim();
  const area = inferArea(title);
  const filename = `${date}-${slug}.md`;
  const absolutePath = path.join(pendingDir, filename);
  const relativePath = toPosixRel(workspaceDir, absolutePath);

  if (fs.existsSync(absolutePath)) {
    return {
      text: `Todo finns redan: ${relativePath}\n${userFallbackHint("check-todos", area)}`,
    };
  }

  const markdown = [
    "---",
    `created: ${created}`,
    `title: "${escapeYamlDoubleQuoted(title)}"`,
    `area: "${escapeYamlDoubleQuoted(area)}"`,
    "files: []",
    "---",
    "",
    "## Problem",
    "",
    title,
    "",
    "## Solution",
    "",
    "TBD",
    "",
  ].join("\n");
  fs.writeFileSync(absolutePath, markdown, "utf8");

  const filesForCommit = [relativePath];
  const statePath = path.join(workspaceDir, ".planning", "STATE.md");
  if (fs.existsSync(statePath)) {
    filesForCommit.push(".planning/STATE.md");
  }

  let commitLine = "Commit: skipped";
  try {
    await runGsdTools(api, workspaceDir, [
      "commit",
      `docs: capture todo - ${title}`,
      "--files",
      ...filesForCommit,
    ]);
    commitLine = `Commit: docs: capture todo - ${title}`;
  } catch (err) {
    commitLine = `Commit: skipped (${truncate(String(err?.message ?? err), 120)})`;
  }

  return {
    text: [
      `Todo sparad: ${relativePath}`,
      `Title: ${title}`,
      `Area: ${area}`,
      commitLine,
      "",
      "Nästa:",
      `- /gsd-check-todos ${area}`,
      "- /gsd-progress",
    ].join("\n"),
  };
}

async function handleCheckTodos(api, ctx) {
  const workspaceDir = resolveWorkspaceDir(api, ctx);
  const area = (ctx.args ?? "").trim();
  const initArgs = ["init", "todos", ...(area ? [area] : [])];
  const init = await runGsdToolsJson(api, workspaceDir, initArgs);
  const todos = Array.isArray(init?.todos) ? init.todos : [];

  if (todos.length === 0) {
    return {
      text: area
        ? `Inga pending todos för area "${area}".\n${userFallbackHint("check-todos", "")}`
        : "Inga pending todos.\nLägg till med /gsd-add-todo <text>.",
    };
  }

  const lines = [`Pending todos (${todos.length}):`, ""];
  for (let i = 0; i < todos.length; i += 1) {
    const todo = todos[i] ?? {};
    const title = (todo.title ?? "Untitled").toString().trim();
    const todoArea = (todo.area ?? "general").toString().trim();
    const age = formatAge((todo.created ?? "").toString().trim());
    lines.push(`${i + 1}. ${title} (${todoArea}, ${age} ago)`);
  }

  lines.push("");
  lines.push("Filter: /gsd-check-todos <area>");
  lines.push("Add: /gsd-add-todo <text>");

  return { text: lines.join("\n") };
}

async function handleProgress(api, ctx) {
  const workspaceDir = resolveWorkspaceDir(api, ctx);
  const init = await runGsdToolsJson(api, workspaceDir, ["init", "progress"]);

  if (!init?.roadmap_exists) {
    return {
      text: "Ingen GSD-roadmap hittades ännu.\nStarta med: /gsd-new-project",
    };
  }

  const table = await runGsdTools(api, workspaceDir, ["progress", "table"], { raw: true });
  const nextPhase = init?.next_phase?.number
    ? `${init.next_phase.number} ${init.next_phase.name ?? ""}`.trim()
    : "none";
  const currentPhase = init?.current_phase?.number
    ? `${init.current_phase.number} ${init.current_phase.name ?? ""}`.trim()
    : "none";

  return {
    text: [
      table,
      "",
      `Current phase: ${currentPhase}`,
      `Next phase: ${nextPhase}`,
      init?.paused_at ? `Paused at: ${init.paused_at}` : "Paused at: none",
    ].join("\n"),
  };
}

async function forwardToGsd(api, ctx, gsdCommand) {
  if (gsdCommand === "add-todo") return await handleAddTodo(api, ctx);
  if (gsdCommand === "check-todos") return await handleCheckTodos(api, ctx);
  if (gsdCommand === "progress") return await handleProgress(api, ctx);

  const sender = pickSender(ctx);
  if (!sender) {
    return {
      text: `Saknar sender-id för aliasrouting.\n${userFallbackHint(gsdCommand, (ctx.args ?? "").trim())}`,
    };
  }

  const args = (ctx.args ?? "").trim();
  const prompt = buildSkillPrompt(gsdCommand, args);

  const argv = [
    "openclaw",
    "agent",
    "--agent",
    "main",
    "--channel",
    ctx.channel,
    "--to",
    sender,
    "--message",
    prompt,
    "--json",
    "--timeout",
    "180",
  ];

  const run = await api.runtime.system.runCommandWithTimeout(argv, {
    timeoutMs: 190000,
  });

  if (run.code !== 0) {
    const err = (run.stderr || run.stdout || "").trim();
    const looksLikeLock = /session file locked|gateway timeout|all models failed/i.test(err);
    if (looksLikeLock) {
      return {
        text: [
          "Alias-forwarding misslyckades pga sessions-låsning i runtime.",
          userFallbackHint(gsdCommand, args),
        ].join("\n"),
      };
    }
    return {
      text: `Alias-fel: ${truncate(err || "okänt fel", 900)}`,
    };
  }

  const text = extractReplyText(run.stdout);
  return {
    text: truncate(text || `Körde /gsd ${gsdCommand}${args ? ` ${args}` : ""}`, 1800),
  };
}

const plugin = {
  id: "gsd-command-aliases",
  name: "GSD Command Aliases",
  description: "Hyphen slash-command aliases for GSD workflows.",
  register(api) {
    for (const [alias, gsdCommand] of Object.entries(ALIASES)) {
      api.registerCommand({
        name: alias,
        description: `Alias for /gsd ${gsdCommand}`,
        acceptsArgs: true,
        handler: async (ctx) => {
          return await forwardToGsd(api, ctx, gsdCommand);
        },
      });
    }

    api.registerCommand({
      name: "gsd-help",
      description: "Show available /gsd-* aliases.",
      acceptsArgs: false,
      handler: async () => ({ text: commandHelp() }),
    });

    api.logger.info("GSD command aliases registered");
  },
};

export default plugin;
