import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ALIASES = {
  "gsd-add-todo": "add-todo",
  "gsd-check-todos": "check-todos",
  "gsd-new-epic": "new-epic",
  "gsd-new-project": "new-project",
  "gsd-progress": "progress",
  "gsd-discuss-phase": "discuss-phase",
  "gsd-plan-phase": "plan-phase",
  "gsd-execute-phase": "execute-phase",
  "gsd-verify-work": "verify-work",
  "gsd-resume-work": "resume-work",
};

const CGSD_CLICK_INTENSITY_LEVELS = [0, 20, 40, 60, 80, 100];

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
    "- /gsd-new-epic <title> (deterministisk + forum best-effort)",
    "- /gsd-progress (deterministisk)",
    "- /gsd-discuss-phase <n>",
    "- /gsd-new-project [--auto]",
    "- /gsd-plan-phase <n>",
    "- /gsd-execute-phase <n>",
    "- /gsd-verify-work [n]",
    "- /gsd-resume-work",
    "- /gsd-project-mode [status|check|set]",
    "- /gsd-project-bind <project>",
    "- /cgsd [status|check|set|intensity|bind|projects]",
    "- /cgsd add-project <project> <path>",
    "- /cgsd-panel, /cgsd-status, /cgsd-check",
    "- /cgsd-off, /cgsd-medium, /cgsd-high",
    "- /cgsd-i0, /cgsd-i20, /cgsd-i40, /cgsd-i60, /cgsd-i80, /cgsd-i100",
    "- /badgeid-activity (legacy alias)",
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

function tokenizeArgs(raw) {
  return (raw ?? "")
    .toString()
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function normalizeProjectMode(value) {
  const v = (value ?? "").toString().trim().toLowerCase();
  if (!v) return "";
  if (["off", "inaktiv", "inactive", "disable", "disabled", "none", "0", "av"].includes(v)) return "off";
  if (["medium", "medel", "normal", "1"].includes(v)) return "medium";
  if (["high", "hog", "hög", "very-active", "2"].includes(v)) return "high";
  return "";
}

function parseIntensityPercent(value) {
  const raw = (value ?? "").toString().trim();
  if (!raw) return null;
  const normalized = raw.endsWith("%") ? raw.slice(0, -1).trim() : raw;
  if (!/^-?\d+$/.test(normalized)) return null;
  const parsed = Number.parseInt(normalized, 10);
  if (!Number.isFinite(parsed)) return null;
  if (parsed < 0 || parsed > 100) return null;
  return parsed;
}

function modeFromIntensity(percent) {
  if (percent <= 19) return "off";
  if (percent <= 69) return "medium";
  return "high";
}

function normalizeProjectSelector(value) {
  const v = (value ?? "").toString().trim().toLowerCase();
  if (!v) return "this";
  if (["this", "current", "here", "channel", "kanal", "thread"].includes(v)) return "this";
  if (["all", "alla", "*", "global"].includes(v)) return "all";
  return v;
}

function normalizeProjectKey(value) {
  const raw = (value ?? "").toString().trim().toLowerCase();
  if (!raw) return "";
  if (!/^[a-z0-9][a-z0-9._-]*$/.test(raw)) return "";
  return raw;
}

function parseProjectModeRequest(rawArgs) {
  const args = tokenizeArgs(rawArgs);
  if (args.length === 0) {
    return { action: "status", selector: "this", mode: "" };
  }

  const first = args[0].toLowerCase();
  if (["help", "hjalp", "hjälp"].includes(first)) {
    return { action: "help", selector: "this", mode: "" };
  }
  if (first === "set") {
    const selector = normalizeProjectSelector(args[1] ?? "this");
    const mode = normalizeProjectMode(args[2] ?? "");
    if (!mode) return { error: "Usage: /gsd-project-mode set <project|this|all> off|medium|high" };
    return { action: "set", selector, mode };
  }
  if (["status", "check"].includes(first)) {
    return { action: first, selector: normalizeProjectSelector(args[1] ?? "this"), mode: "" };
  }

  const firstMode = normalizeProjectMode(first);
  if (firstMode) {
    return { action: "set", selector: normalizeProjectSelector(args[1] ?? "this"), mode: firstMode };
  }

  const selector = normalizeProjectSelector(first);
  const second = (args[1] ?? "").toLowerCase();
  if (!second) return { action: "status", selector, mode: "" };

  if (["status", "check"].includes(second)) {
    return { action: second, selector, mode: "" };
  }

  const secondMode = normalizeProjectMode(second);
  if (secondMode) {
    return { action: "set", selector, mode: secondMode };
  }

  return { error: "Usage: /gsd-project-mode [status|check|set] [project|this|all] [off|medium|high]" };
}

function translateBadgeidActivityArgs(rawArgs) {
  const args = tokenizeArgs(rawArgs);
  if (args.length === 0) return "status badgeid";

  const first = (args[0] ?? "").toLowerCase();
  if (["help", "hjalp", "hjälp"].includes(first)) return "help";

  if (first === "set") {
    const second = (args[1] ?? "").toLowerCase();
    const third = (args[2] ?? "").toLowerCase();
    const secondMode = normalizeProjectMode(second);
    const thirdMode = normalizeProjectMode(third);
    if (secondMode) return `set badgeid ${secondMode}`;
    if (thirdMode) return `set ${second} ${thirdMode}`;
    return "help";
  }

  if (["status", "check"].includes(first)) return `${first} badgeid`;

  const mode = normalizeProjectMode(first);
  if (mode) return `${mode} badgeid`;

  return rawArgs;
}

function projectModeHelp() {
  return [
    "Project activity mode:",
    "- /gsd-project-mode status [this|<project>|all]",
    "- /gsd-project-mode check [this|<project>|all]",
    "- /gsd-project-mode set <this|<project>|all> off|medium|high",
    "- /gsd-project-mode <off|medium|high> [this|<project>|all]",
    "- /gsd-project-mode <project> <off|medium|high>",
    "",
    "Example:",
    "- /gsd-project-mode high",
    "- /gsd-project-mode badgeid medium",
    "- /gsd-project-mode check all",
  ].join("\n");
}

function projectBindHelp() {
  return [
    "Project binding:",
    "- /gsd-project-bind <project>",
    "- /gsd-project-bind show [this|all]",
    "",
    "Examples:",
    "- /gsd-project-bind badgeid",
    "- /gsd-project-bind show",
    "- /gsd-project-bind show all",
  ].join("\n");
}

function cgsdHelp() {
  return [
    "CGSD control plane:",
    "- /cgsd",
    "- /cgsd panel",
    "- /cgsd add-project <project> <path>",
    "- /cgsd status [this|<project>|all]",
    "- /cgsd check [this|<project>|all]",
    "- /cgsd set <this|<project>|all> off|medium|high",
    "- /cgsd <off|medium|high> [this|<project>|all]",
    "- /cgsd intensity [this|<project>|all] <0-100>",
    "- /cgsd bind <project>",
    "- /cgsd projects",
    "",
    "Click-only quick commands (no args):",
    "- /cgsd-panel, /cgsd-status, /cgsd-check",
    "- /cgsd-off, /cgsd-medium, /cgsd-high",
    "- /cgsd-i0, /cgsd-i20, /cgsd-i40, /cgsd-i60, /cgsd-i80, /cgsd-i100",
    "",
    "Intensity mapping:",
    "- 0-19 -> off",
    "- 20-69 -> medium",
    "- 70-100 -> high",
  ].join("\n");
}

function parseCgsdRequest(rawArgs) {
  const raw = (rawArgs ?? "").toString().trim();
  if (!raw) return { action: "dashboard" };

  const addMatch = raw.match(/^(add-project|add)\s+(\S+)\s+(.+)$/i);
  if (addMatch) {
    const projectKey = normalizeProjectKey(addMatch[2] ?? "");
    const projectRoot = (addMatch[3] ?? "").toString().trim();
    if (!projectKey || !projectRoot) {
      return { action: "help", error: "Usage: /cgsd add-project <project> <path>" };
    }
    return { action: "add-project", projectKey, projectRoot };
  }
  if (/^(add-project|add)\b/i.test(raw)) {
    return { action: "help", error: "Usage: /cgsd add-project <project> <path>" };
  }

  const args = tokenizeArgs(raw);

  const first = (args[0] ?? "").toLowerCase();
  if (["panel", "dashboard"].includes(first)) {
    return { action: "dashboard" };
  }
  if (["help", "hjalp", "hjälp", "menu"].includes(first)) {
    return { action: "help" };
  }
  if (["projects", "list", "catalog"].includes(first)) {
    return { action: "projects" };
  }
  if (first === "bind") {
    const project = (args[1] ?? "").toString().trim();
    if (!project) return { action: "help", error: "Usage: /cgsd bind <project>" };
    return { action: "bind", bindArgs: project };
  }
  if (["status", "check"].includes(first)) {
    return { action: "project-mode", modeArgs: `${first} ${normalizeProjectSelector(args[1] ?? "this")}` };
  }
  if (first === "set") {
    const selector = normalizeProjectSelector(args[1] ?? "this");
    const modeToken = args[2] ?? "";
    const mode = normalizeProjectMode(modeToken);
    if (mode) return { action: "project-mode", modeArgs: `set ${selector} ${mode}` };
    const intensity = parseIntensityPercent(modeToken);
    if (intensity !== null) {
      const mapped = modeFromIntensity(intensity);
      return {
        action: "project-mode",
        modeArgs: `set ${selector} ${mapped}`,
        note: `Intensity ${intensity}% mapped to mode=${mapped}.`,
      };
    }
    return { action: "help", error: "Usage: /cgsd set <this|<project>|all> off|medium|high|<0-100>" };
  }
  if (["intensity", "resources", "resource", "power", "load"].includes(first)) {
    let selector = "this";
    let intensityToken = args[1] ?? "";
    if (args.length >= 3) {
      selector = normalizeProjectSelector(args[1] ?? "this");
      intensityToken = args[2] ?? "";
    }
    const intensity = parseIntensityPercent(intensityToken);
    if (intensity === null) {
      return { action: "help", error: "Usage: /cgsd intensity [this|<project>|all] <0-100>" };
    }
    const mapped = modeFromIntensity(intensity);
    return {
      action: "project-mode",
      modeArgs: `set ${selector} ${mapped}`,
      note: `Intensity ${intensity}% mapped to mode=${mapped}.`,
    };
  }

  const firstMode = normalizeProjectMode(first);
  if (firstMode) {
    return {
      action: "project-mode",
      modeArgs: `set ${normalizeProjectSelector(args[1] ?? "this")} ${firstMode}`,
    };
  }

  const firstIntensity = parseIntensityPercent(first);
  if (firstIntensity !== null) {
    const mapped = modeFromIntensity(firstIntensity);
    return {
      action: "project-mode",
      modeArgs: `set ${normalizeProjectSelector(args[1] ?? "this")} ${mapped}`,
      note: `Intensity ${firstIntensity}% mapped to mode=${mapped}.`,
    };
  }

  const selector = normalizeProjectSelector(first);
  const secondToken = (args[1] ?? "").toString().trim();
  if (!secondToken) {
    return { action: "project-mode", modeArgs: `status ${selector}` };
  }
  const secondMode = normalizeProjectMode(secondToken);
  if (secondMode) return { action: "project-mode", modeArgs: `set ${selector} ${secondMode}` };
  const secondIntensity = parseIntensityPercent(secondToken);
  if (secondIntensity !== null) {
    const mapped = modeFromIntensity(secondIntensity);
    return {
      action: "project-mode",
      modeArgs: `set ${selector} ${mapped}`,
      note: `Intensity ${secondIntensity}% mapped to mode=${mapped}.`,
    };
  }

  return { action: "help", error: "Could not parse /cgsd command." };
}

function resolveProjectRootPath(api, ctx, projectRootRaw) {
  const expanded = expandPath(projectRootRaw ?? "");
  if (!expanded) return "";
  if (path.isAbsolute(expanded)) return path.resolve(expanded);
  const workspaceDir = resolveWorkspaceDir(api, ctx);
  if (workspaceDir) return path.resolve(workspaceDir, expanded);
  return path.resolve(expanded);
}

async function handleCgsdAddProject(api, ctx, req) {
  const registryWrap = readProjectActivityRegistry(api);
  const registry = registryWrap.data;
  const projectKey = normalizeProjectKey(req.projectKey ?? "");
  if (!projectKey) {
    return { text: "Invalid project key. Use lowercase letters, numbers, dot, dash, underscore." };
  }

  const projectRoot = resolveProjectRootPath(api, ctx, req.projectRoot);
  if (!projectRoot) {
    return { text: "Invalid project root path." };
  }
  if (!fs.existsSync(projectRoot)) {
    return { text: `Project root does not exist: ${projectRoot}` };
  }
  let stats;
  try {
    stats = fs.statSync(projectRoot);
  } catch {
    return { text: `Could not read project root: ${projectRoot}` };
  }
  if (!stats.isDirectory()) {
    return { text: `Project root must be a directory: ${projectRoot}` };
  }

  if (!registry.projects || typeof registry.projects !== "object" || Array.isArray(registry.projects)) {
    registry.projects = {};
  }

  const existing = registry.projects[projectKey] ?? {};
  const previousRoot = (existing?.projectRoot ?? "").toString().trim();
  registry.projects[projectKey] = {
    projectKey,
    projectRoot,
    currentMode: normalizeProjectMode(existing?.currentMode ?? "") || "high",
    delivery:
      existing?.delivery && typeof existing.delivery === "object" && !Array.isArray(existing.delivery)
        ? { ...existing.delivery }
        : {},
    jobs: Array.isArray(existing?.jobs) ? existing.jobs : [],
  };
  writeProjectActivityRegistry(registryWrap.path, registry);

  const lines = [];
  if (previousRoot && previousRoot !== projectRoot) {
    lines.push(`Updated project '${projectKey}' root:`);
    lines.push(`- from: ${previousRoot}`);
    lines.push(`- to:   ${projectRoot}`);
  } else {
    lines.push(`Registered project '${projectKey}' with root: ${projectRoot}`);
  }
  lines.push(`Jobs in registry: ${registry.projects[projectKey].jobs.length}`);
  lines.push("");
  lines.push("Next:");
  lines.push(`- /cgsd bind ${projectKey}`);
  lines.push("- /cgsd status");
  if (registry.projects[projectKey].jobs.length === 0) {
    lines.push("- This project has no jobs yet; run CGSD install for this project to add cron jobs.");
  }
  return { text: lines.join("\n") };
}

function renderCgsdProjects(registry) {
  const keys = Object.keys(registry.projects ?? {});
  if (keys.length === 0) {
    return "No projects found in activity registry.";
  }

  const map = registry.channelProjectMap && typeof registry.channelProjectMap === "object" ? registry.channelProjectMap : {};
  const lines = ["Registered projects:"];
  for (const key of keys.sort()) {
    const project = registry.projects[key] ?? {};
    const mode = (project.currentMode ?? "unknown").toString();
    const refs = Object.entries(map)
      .filter(([, projectKey]) => projectKey === key)
      .map(([ref]) => ref);
    const boundSuffix =
      refs.length === 0 ? "no bindings" : `${refs.length} binding${refs.length === 1 ? "" : "s"}`;
    lines.push(`- ${key}: mode=${mode}, ${boundSuffix}`);
  }
  return lines.join("\n");
}

async function handleCgsd(api, ctx) {
  const req = parseCgsdRequest(ctx.args ?? "");
  const registryWrap = readProjectActivityRegistry(api);
  const registry = registryWrap.data;

  if (req.action === "help") {
    const prefix = req.error ? `${req.error}\n\n` : "";
    return { text: `${prefix}${cgsdHelp()}` };
  }

  if (req.action === "projects") {
    return { text: truncate(`${renderCgsdProjects(registry)}\n\n${projectBindHelp()}`, 1900) };
  }

  if (req.action === "add-project") {
    return await handleCgsdAddProject(api, ctx, req);
  }

  if (req.action === "bind") {
    return await handleProjectBind(api, { ...ctx, args: req.bindArgs ?? "" });
  }

  if (req.action === "dashboard") {
    const status = await handleProjectMode(api, { ...ctx, args: "status this" });
    const bindings = renderProjectBindings(registry, "this", ctx);
    return {
      text: truncate(
        [
          "CGSD Control Dashboard",
          "",
          status.text ?? "",
          "",
          bindings,
          "",
          "Quick actions:",
          "- /cgsd-panel",
          "- /cgsd-status",
          "- /cgsd-check",
          "- /cgsd off",
          "- /cgsd medium",
          "- /cgsd high",
          "- /cgsd intensity 80",
          "- /cgsd projects, /cgsd bind <project>",
          "",
          "Click-only intensity presets:",
          "- /cgsd-i0, /cgsd-i20, /cgsd-i40, /cgsd-i60, /cgsd-i80, /cgsd-i100",
        ].join("\n"),
        1900,
      ),
    };
  }

  const result = await handleProjectMode(api, { ...ctx, args: req.modeArgs ?? "" });
  if (!req.note) return result;
  return { text: truncate(`${req.note}\n\n${result.text ?? ""}`, 1900) };
}

function parseProjectBindRequest(rawArgs) {
  const args = tokenizeArgs(rawArgs);
  if (args.length === 0) return { action: "help", selector: "this", project: "" };

  const first = (args[0] ?? "").toLowerCase();
  if (["help", "hjalp", "hjälp"].includes(first)) return { action: "help", selector: "this", project: "" };
  if (["show", "status", "list"].includes(first)) {
    return {
      action: "show",
      selector: normalizeProjectSelector(args[1] ?? "this"),
      project: "",
    };
  }

  return {
    action: "bind",
    selector: "this",
    project: first,
  };
}

function resolveProjectActivityRegistryPath(api) {
  const cfg = getPluginConfig(api);
  const localCfg = readLocalPluginConfig();
  const home = process.env.HOME || "";

  const selected = expandPath(
    pickDefined(
      process.env.CGSD_PROJECT_ACTIVITY_REGISTRY,
      cfg.projectActivityRegistry,
      localCfg.projectActivityRegistry,
      home ? path.join(home, ".openclaw", "cgsd-project-activity.json") : "",
    ),
  );
  return selected;
}

function ensureProjectActivityRegistryShape(data) {
  const out = data && typeof data === "object" && !Array.isArray(data) ? { ...data } : {};
  if (!out.version || typeof out.version !== "number") out.version = 1;
  if (!out.projects || typeof out.projects !== "object" || Array.isArray(out.projects)) out.projects = {};
  if (!out.channelProjectMap || typeof out.channelProjectMap !== "object" || Array.isArray(out.channelProjectMap)) {
    out.channelProjectMap = {};
  }
  return out;
}

function readProjectActivityRegistry(api) {
  const registryPath = resolveProjectActivityRegistryPath(api);
  if (!registryPath) {
    return { path: "", data: ensureProjectActivityRegistryShape({}) };
  }
  if (!fs.existsSync(registryPath)) {
    return { path: registryPath, data: ensureProjectActivityRegistryShape({}) };
  }
  try {
    const raw = fs.readFileSync(registryPath, "utf8");
    const parsed = JSON.parse(raw);
    return { path: registryPath, data: ensureProjectActivityRegistryShape(parsed) };
  } catch {
    return { path: registryPath, data: ensureProjectActivityRegistryShape({}) };
  }
}

function writeProjectActivityRegistry(registryPath, data) {
  if (!registryPath) return;
  fs.mkdirSync(path.dirname(registryPath), { recursive: true });
  fs.writeFileSync(registryPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

function resolveContextRefs(ctx) {
  const refs = [];
  const pushRef = (value) => {
    const v = (value ?? "").toString().trim();
    if (v) refs.push(v);
  };

  pushRef(ctx?.messageThreadId);
  const keys = [
    "target",
    "to",
    "channelId",
    "messageChannelId",
    "channelTargetId",
    "roomId",
    "threadId",
    "replyTo",
    "deliveryTarget",
  ];
  for (const key of keys) pushRef(ctx?.[key]);

  const dc = ctx?.deliveryContext;
  if (dc && typeof dc === "object") {
    pushRef(dc.to);
    pushRef(dc.target);
    pushRef(dc.threadId);
    pushRef(dc.channelId);
  }

  return uniq(refs);
}

function resolveProjectKeysForSelector(registry, selector, ctx) {
  const projects = registry?.projects ?? {};
  const keys = Object.keys(projects);
  if (keys.length === 0) return { error: "No projects found in activity registry yet." };

  if (selector === "all") return { keys };

  if (selector === "this") {
    const refs = resolveContextRefs(ctx);
    const found = new Set();
    const map = registry?.channelProjectMap ?? {};
    for (const ref of refs) {
      const mapped = (map?.[ref] ?? "").toString().trim();
      if (mapped && projects[mapped]) found.add(mapped);
    }
    if (found.size === 0) {
      for (const key of keys) {
        const project = projects[key] ?? {};
        const deliveryTarget = (project?.delivery?.target ?? "").toString().trim();
        const forumTarget = (project?.delivery?.forumTarget ?? "").toString().trim();
        if (refs.includes(deliveryTarget) || refs.includes(forumTarget)) found.add(key);
      }
    }
    if (found.size === 0 && keys.length === 1) found.add(keys[0]);
    if (found.size === 0) {
      return {
        error: `Could not resolve project for current channel/thread.\nKnown refs: ${refs.join(", ") || "none"}`,
      };
    }
    return { keys: [...found] };
  }

  if (projects[selector]) return { keys: [selector] };
  const ci = keys.find((k) => k.toLowerCase() === selector.toLowerCase());
  if (ci) return { keys: [ci] };
  return { error: `Unknown project '${selector}'. Known: ${keys.join(", ")}` };
}

function resolveExpectedModeSpec(job, mode) {
  const modes = job?.modes ?? {};
  let spec = modes[mode];
  if (!spec && mode === "off") spec = { enabled: false };
  if (!spec) spec = modes.high ?? {};
  const enabled = spec?.enabled !== false;
  const cron = (spec?.cron ?? "").toString().trim();
  return { enabled, cron };
}

function renderProjectBindings(registry, selector, ctx) {
  const map = registry?.channelProjectMap ?? {};
  const refs = resolveContextRefs(ctx);
  if (selector === "all") {
    const entries = Object.entries(map).sort((a, b) => a[0].localeCompare(b[0]));
    if (entries.length === 0) return "No channel/thread bindings yet.";
    const lines = ["Channel/thread bindings:"];
    for (const [ref, project] of entries) {
      lines.push(`- ${ref} -> ${project}`);
    }
    return lines.join("\n");
  }

  if (refs.length === 0) return "No current channel/thread reference found in context.";
  const lines = ["Current context bindings:"];
  let found = 0;
  for (const ref of refs) {
    const project = (map[ref] ?? "").toString().trim();
    if (!project) continue;
    lines.push(`- ${ref} -> ${project}`);
    found += 1;
  }
  if (found === 0) {
    lines.push("- none");
  }
  return lines.join("\n");
}

async function readCronJobs(api) {
  const raw = await runCommand(api, ["openclaw", "cron", "list", "--all", "--json"], {
    timeoutMs: 45000,
  });
  try {
    const parsed = JSON.parse(raw);
    const jobs = Array.isArray(parsed?.jobs) ? parsed.jobs : [];
    return jobs;
  } catch {
    throw new Error("Could not parse cron list JSON.");
  }
}

function findRuntimeJob(jobs, jobSpec) {
  const id = (jobSpec?.id ?? "").toString().trim();
  const name = (jobSpec?.name ?? "").toString().trim();
  if (id) {
    const byId = jobs.find((j) => (j?.id ?? "").toString().trim() === id);
    if (byId) return byId;
  }
  if (name) {
    const byName = jobs.find((j) => (j?.name ?? "").toString().trim() === name);
    if (byName) return byName;
  }
  return null;
}

function renderProjectStatus(registry, selectedKeys, jobs) {
  const lines = [];
  for (const key of selectedKeys) {
    const project = registry.projects[key] ?? {};
    const mode = normalizeProjectMode(project.currentMode) || "high";
    const target = (project?.delivery?.target ?? "-").toString().trim() || "-";
    lines.push(`Project ${key} (mode=${mode}, target=${target})`);
    const projectJobs = Array.isArray(project.jobs) ? project.jobs : [];
    if (projectJobs.length === 0) {
      lines.push("- No jobs registered.");
      lines.push("");
      continue;
    }
    for (const job of projectJobs) {
      const runtime = findRuntimeJob(jobs, job);
      const expected = resolveExpectedModeSpec(job, mode);
      if (!runtime) {
        lines.push(`- ${job.name || job.key}: missing in cron list (expected ${expected.enabled ? "enabled" : "paused"})`);
        continue;
      }
      const state = runtime.enabled ? "enabled" : "paused";
      const expr = runtime?.schedule?.expr ?? "-";
      const expectedStr = expected.enabled
        ? `enabled${expected.cron ? ` @ ${expected.cron}` : ""}`
        : "paused";
      lines.push(`- ${runtime.name}: ${state}, cron=${expr}, expected=${expectedStr}`);
    }
    lines.push("");
  }
  return lines.join("\n").trim();
}

function evaluateProjectMode(registry, selectedKeys, jobs) {
  const mismatches = [];
  let checked = 0;
  for (const key of selectedKeys) {
    const project = registry.projects[key] ?? {};
    const mode = normalizeProjectMode(project.currentMode) || "high";
    const projectJobs = Array.isArray(project.jobs) ? project.jobs : [];
    for (const job of projectJobs) {
      checked += 1;
      const runtime = findRuntimeJob(jobs, job);
      const expected = resolveExpectedModeSpec(job, mode);
      const label = `${key}/${job.name || job.key || job.id || "job"}`;
      if (!runtime) {
        mismatches.push(`${label}: missing in cron list`);
        continue;
      }
      const isEnabled = !!runtime.enabled;
      if (expected.enabled !== isEnabled) {
        mismatches.push(`${label}: expected ${expected.enabled ? "enabled" : "paused"}, got ${isEnabled ? "enabled" : "paused"}`);
        continue;
      }
      const actualCron = (runtime?.schedule?.expr ?? "").toString().trim();
      if (expected.enabled && expected.cron && actualCron && actualCron !== expected.cron) {
        mismatches.push(`${label}: expected cron '${expected.cron}', got '${actualCron}'`);
      }
    }
  }
  return { checked, mismatches };
}

async function applyProjectMode(api, registry, selectedKeys, mode) {
  const lines = [];
  for (const key of selectedKeys) {
    const project = registry.projects[key] ?? {};
    const projectJobs = Array.isArray(project.jobs) ? project.jobs : [];
    lines.push(`Project ${key}: set mode ${mode}`);
    for (const job of projectJobs) {
      const expected = resolveExpectedModeSpec(job, mode);
      const id = (job?.id ?? "").toString().trim();
      const name = (job?.name ?? job?.key ?? "job").toString();
      if (!id) {
        lines.push(`- ${name}: skipped (missing job id in registry)`);
        continue;
      }
      try {
        if (!expected.enabled) {
          await runCommand(api, ["openclaw", "cron", "disable", id], { timeoutMs: 45000 });
          lines.push(`- ${name}: paused`);
          continue;
        }
        if (expected.cron) {
          await runCommand(api, ["openclaw", "cron", "edit", id, "--enable", "--cron", expected.cron], {
            timeoutMs: 45000,
          });
          lines.push(`- ${name}: enabled @ ${expected.cron}`);
        } else {
          await runCommand(api, ["openclaw", "cron", "enable", id], { timeoutMs: 45000 });
          lines.push(`- ${name}: enabled`);
        }
      } catch (err) {
        lines.push(`- ${name}: failed (${truncate(String(err?.message ?? err), 140)})`);
      }
    }
    project.currentMode = mode;
    lines.push("");
  }
  return lines.join("\n").trim();
}

async function handleProjectMode(api, ctx) {
  const request = parseProjectModeRequest(ctx.args ?? "");
  if (request.error) return { text: `${request.error}\n\n${projectModeHelp()}` };
  if (request.action === "help") return { text: projectModeHelp() };

  const registryWrap = readProjectActivityRegistry(api);
  const registry = registryWrap.data;
  const resolved = resolveProjectKeysForSelector(registry, request.selector, ctx);
  if (resolved.error) return { text: `${resolved.error}\n\n${projectModeHelp()}` };
  const selectedKeys = resolved.keys;

  try {
    if (request.action === "set") {
      const applySummary = await applyProjectMode(api, registry, selectedKeys, request.mode);
      writeProjectActivityRegistry(registryWrap.path, registry);
      const jobs = await readCronJobs(api);
      const evalResult = evaluateProjectMode(registry, selectedKeys, jobs);
      const verdict =
        evalResult.mismatches.length === 0
          ? `CHECK_OK: ${evalResult.checked} jobs match mode=${request.mode}.`
          : `CHECK_FAIL: ${evalResult.mismatches.length} mismatch(es).\n- ${evalResult.mismatches.join("\n- ")}`;
      return { text: truncate(`${applySummary}\n\n${verdict}`, 1900) };
    }

    const jobs = await readCronJobs(api);
    if (request.action === "status") {
      return { text: truncate(renderProjectStatus(registry, selectedKeys, jobs), 1900) };
    }

    const evalResult = evaluateProjectMode(registry, selectedKeys, jobs);
    if (evalResult.mismatches.length === 0) {
      return { text: `CHECK_OK: ${evalResult.checked} jobs match expected mode.` };
    }
    return {
      text: truncate(
        `CHECK_FAIL: ${evalResult.mismatches.length} mismatch(es).\n- ${evalResult.mismatches.join("\n- ")}`,
        1900,
      ),
    };
  } catch (err) {
    return { text: `gsd-project-mode failed: ${truncate(String(err?.message ?? err), 900)}` };
  }
}

async function handleBadgeidActivity(api, ctx) {
  const mapped = translateBadgeidActivityArgs(ctx.args ?? "");
  return await handleProjectMode(api, { ...ctx, args: mapped });
}

async function handleProjectBind(api, ctx) {
  const req = parseProjectBindRequest(ctx.args ?? "");
  if (req.action === "help") return { text: projectBindHelp() };

  const registryWrap = readProjectActivityRegistry(api);
  const registry = registryWrap.data;

  if (req.action === "show") {
    return { text: renderProjectBindings(registry, req.selector, ctx) };
  }

  const project = req.project;
  const knownProjects = Object.keys(registry.projects ?? {});
  if (!project) return { text: projectBindHelp() };
  if (!knownProjects.includes(project)) {
    const ci = knownProjects.find((k) => k.toLowerCase() === project.toLowerCase());
    if (ci) {
      req.project = ci;
    } else {
      return {
        text: `Unknown project '${project}'. Known: ${knownProjects.join(", ") || "none"}\n\n${projectBindHelp()}`,
      };
    }
  }

  const finalProject = req.project;
  const refs = resolveContextRefs(ctx);
  if (refs.length === 0) {
    return { text: "Could not find channel/thread reference in current context." };
  }

  if (!registry.channelProjectMap || typeof registry.channelProjectMap !== "object") {
    registry.channelProjectMap = {};
  }
  for (const ref of refs) {
    registry.channelProjectMap[ref] = finalProject;
  }
  writeProjectActivityRegistry(registryWrap.path, registry);

  const lines = [
    `Bound ${refs.length} ref(s) to project '${finalProject}':`,
    ...refs.map((r) => `- ${r}`),
  ];
  return { text: lines.join("\n") };
}

function parseBool(value, fallback = false) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value !== "string") return fallback;
  const v = value.trim().toLowerCase();
  if (!v) return fallback;
  if (["1", "true", "yes", "on"].includes(v)) return true;
  if (["0", "false", "no", "off"].includes(v)) return false;
  return fallback;
}

function pickDefined(...values) {
  for (const value of values) {
    if (value !== undefined && value !== null) return value;
  }
  return undefined;
}

function readLocalPluginConfig() {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  const localPath = path.join(moduleDir, "config.local.json");
  if (!fs.existsSync(localPath)) return {};
  try {
    const raw = fs.readFileSync(localPath, "utf8");
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed;
    }
  } catch {
    // ignore malformed local config
  }
  return {};
}

function safeSlugUpper(text) {
  const normalized = (text ?? "")
    .toString()
    .trim()
    .replace(/\.md$/i, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toUpperCase();
  return normalized || "UNTITLED";
}

function defaultLoopFiles(workspaceDir) {
  const root = path.join(workspaceDir, ".openclaw");
  return {
    inboxFile: path.join(root, "LOOP-INBOX.md"),
    queueFile: path.join(root, "LOOP-QUEUE.md"),
  };
}

function resolveLoopConfig(api, workspaceDir) {
  const cfg = getPluginConfig(api);
  const localCfg = readLocalPluginConfig();
  const defaults = defaultLoopFiles(workspaceDir);
  const inboxFile = expandPath(pickDefined(cfg.loopInboxFile, localCfg.loopInboxFile)) || defaults.inboxFile;
  const queueFile = expandPath(pickDefined(cfg.loopQueueFile, localCfg.loopQueueFile)) || defaults.queueFile;
  const epicId = (pickDefined(cfg.defaultEpicId, localCfg.defaultEpicId, "EPIC-GSD-BACKLOG")).toString().trim() || "EPIC-GSD-BACKLOG";
  const epicTitle = (pickDefined(cfg.defaultEpicTitle, localCfg.defaultEpicTitle, "GSD Backlog")).toString().trim() || "GSD Backlog";
  const discordForumTarget = (
    pickDefined(cfg.discordForumTarget, localCfg.discordForumTarget) ??
    process.env.CGSD_DISCORD_FORUM_TARGET ??
    ""
  )
    .toString()
    .trim();
  const discordAccountId = (pickDefined(cfg.discordAccountId, localCfg.discordAccountId, "")).toString().trim();

  return {
    inboxFile,
    queueFile,
    epicId,
    epicTitle,
    autoQueueTodo: parseBool(pickDefined(cfg.autoQueueTodo, localCfg.autoQueueTodo), true),
    autoThreadOnNewEpic: parseBool(pickDefined(cfg.autoThreadOnNewEpic, localCfg.autoThreadOnNewEpic), true),
    discordForumTarget,
    discordAccountId,
  };
}

function ensureLoopFiles(inboxFile, queueFile) {
  fs.mkdirSync(path.dirname(inboxFile), { recursive: true });
  fs.mkdirSync(path.dirname(queueFile), { recursive: true });
  if (!fs.existsSync(inboxFile)) fs.writeFileSync(inboxFile, "# LOOP-INBOX\n\n", "utf8");
  if (!fs.existsSync(queueFile)) fs.writeFileSync(queueFile, "# LOOP-QUEUE\n\n", "utf8");
}

function queueItemExists(filePath, id) {
  if (!id || !fs.existsSync(filePath)) return false;
  const content = fs.readFileSync(filePath, "utf8");
  return content.includes(`- id: ${id}`);
}

function parseBlockField(block, fieldName) {
  const re = new RegExp(`^\\s*${fieldName}:\\s*(.+)$`, "m");
  const match = block.match(re);
  if (!match || !match[1]) return "";
  return match[1].trim();
}

function findEpicBindingByThread(filePath, threadRef) {
  if (!threadRef || !fs.existsSync(filePath)) return null;
  const content = fs.readFileSync(filePath, "utf8");
  const blocks = content.split(/\n(?=- id:\s)/g);
  for (const block of blocks) {
    const epicThread = parseBlockField(block, "epic_thread");
    if (epicThread !== threadRef) continue;
    const epicId = parseBlockField(block, "epic_id");
    if (!epicId) continue;
    const epicTitle = parseBlockField(block, "epic_title") || epicId;
    return { epicId, epicTitle, epicThread };
  }
  return null;
}

function resolveCurrentThreadRef(ctx) {
  if (!ctx || ctx.channel !== "discord") return "";
  const raw = ctx.messageThreadId;
  if (raw === undefined || raw === null) return "";
  const threadRef = String(raw).trim();
  return threadRef || "";
}

function resolveEpicContext(loopConfig, ctx) {
  const threadRef = resolveCurrentThreadRef(ctx);
  if (!threadRef) {
    return {
      epicId: loopConfig.epicId,
      epicTitle: loopConfig.epicTitle,
      epicThread: "n/a",
    };
  }

  const existing =
    findEpicBindingByThread(loopConfig.queueFile, threadRef) ||
    findEpicBindingByThread(loopConfig.inboxFile, threadRef);
  if (existing) return existing;

  return {
    epicId: `EPIC-${threadRef}`,
    epicTitle: `Discord thread ${threadRef}`,
    epicThread: threadRef,
  };
}

function appendInboxItem(inboxFile, item) {
  const lines = [
    "",
    `- id: ${item.id}`,
    `  title: ${item.title}`,
    `  type: ${item.type ?? "quality"}`,
    `  epic_id: ${item.epicId}`,
    `  epic_title: ${item.epicTitle}`,
    `  epic_thread: ${item.epicThread ?? "n/a"}`,
    `  gsd_action: ${item.gsdAction}`,
    `  gsd_phase: ${item.gsdPhase ?? ""}`,
    `  impact: ${item.impact ?? "medium"}`,
    `  effort: ${item.effort ?? "s"}`,
    "  acceptance:",
    "    - [ ] mapped to active GSD phase/todo",
    "    - [ ] verification passes",
    `  next_step: ${item.nextStep ?? "review and prioritize"}`,
    `  owner: ${item.owner ?? "ralphclaw"}`,
    `  status: ${item.status ?? "ready"}`,
    `  source_area: ${item.sourceArea ?? "general"}`,
  ];
  fs.appendFileSync(inboxFile, `${lines.join("\n")}\n`, "utf8");
}

function appendQueueItem(queueFile, item) {
  const lines = [
    "",
    `- id: ${item.id}`,
    `  title: ${item.title}`,
    `  source: ${item.source ?? "GSD-TODO"}`,
    `  source_path: ${item.sourcePath ?? ".planning/todos/pending"}`,
    `  epic_id: ${item.epicId}`,
    `  epic_thread: ${item.epicThread ?? "n/a"}`,
    `  gsd_action: ${item.gsdAction}`,
    `  gsd_phase: ${item.gsdPhase ?? ""}`,
    `  priority: ${item.priority ?? "P1"}`,
    `  status: ${item.status ?? "ready"}`,
    `  verify_status: ${item.verifyStatus ?? "pending"}`,
    "  verify_failures:",
    "  retry_count: 0",
    `  owner: ${item.owner ?? "ralphclaw"}`,
    "  blocker:",
    "  unblock_next_step:",
  ];
  fs.appendFileSync(queueFile, `${lines.join("\n")}\n`, "utf8");
}

async function getProgressMeta(api, workspaceDir) {
  try {
    const progress = await runGsdToolsJson(api, workspaceDir, ["init", "progress"]);
    const currentPhase = progress?.current_phase?.number
      ? String(progress.current_phase.number).trim()
      : "";
    return {
      roadmapExists: !!progress?.roadmap_exists,
      currentPhase,
    };
  } catch {
    return {
      roadmapExists: false,
      currentPhase: "",
    };
  }
}

async function syncTodoToLoop(api, workspaceDir, todo, ctx) {
  const loop = resolveLoopConfig(api, workspaceDir);
  ensureLoopFiles(loop.inboxFile, loop.queueFile);
  const epic = resolveEpicContext(loop, ctx);

  const id = `GSD-TODO-${safeSlugUpper(todo.filename ?? todo.path ?? todo.title)}`;
  if (queueItemExists(loop.inboxFile, id) || queueItemExists(loop.queueFile, id)) {
    return { synced: false, reason: "exists", id };
  }

  const progressMeta = await getProgressMeta(api, workspaceDir);
  const gsdAction = progressMeta.roadmapExists ? "/gsd-resume-work" : "/gsd-new-project";
  const gsdPhase = progressMeta.currentPhase;

  appendInboxItem(loop.inboxFile, {
    id,
    title: todo.title,
    epicId: epic.epicId,
    epicTitle: epic.epicTitle,
    epicThread: epic.epicThread,
    gsdAction,
    gsdPhase,
    nextStep: `sync from ${todo.path}`,
    sourceArea: todo.area,
  });

  appendQueueItem(loop.queueFile, {
    id,
    title: todo.title,
    sourcePath: todo.path,
    epicId: epic.epicId,
    epicThread: epic.epicThread,
    gsdAction,
    gsdPhase,
  });

  return {
    synced: true,
    id,
    inboxFile: toPosixRel(workspaceDir, loop.inboxFile),
    queueFile: toPosixRel(workspaceDir, loop.queueFile),
    epicId: epic.epicId,
    epicThread: epic.epicThread,
  };
}

async function createDiscordEpicThread(api, loopConfig, epicTitle, epicId) {
  if (!loopConfig.discordForumTarget) {
    return { created: false, reason: "missing_target" };
  }

  const argv = [
    "openclaw",
    "message",
    "thread",
    "create",
    "--channel",
    "discord",
    "--target",
    loopConfig.discordForumTarget,
    "--thread-name",
    epicTitle,
    "--message",
    `Epic ${epicId}\nCreated via /gsd-new-epic\n\nUse this thread for scope, decisions, and acceptance.`,
    "--json",
  ];
  if (loopConfig.discordAccountId) {
    argv.push("--account", loopConfig.discordAccountId);
  }

  try {
    const out = await runCommand(api, argv, { timeoutMs: 45000 });
    let threadId = "";
    try {
      const parsed = JSON.parse(out);
      threadId =
        parsed?.threadId?.toString?.() ||
        parsed?.id?.toString?.() ||
        parsed?.result?.threadId?.toString?.() ||
        parsed?.result?.id?.toString?.() ||
        "";
    } catch {
      // no-op
    }
    return { created: true, threadId: threadId.trim() };
  } catch (err) {
    return { created: false, reason: truncate(String(err?.message ?? err), 300) };
  }
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

  const loopConfig = resolveLoopConfig(api, workspaceDir);
  let loopLine = "Loop sync: disabled";
  if (loopConfig.autoQueueTodo) {
    try {
      const syncResult = await syncTodoToLoop(api, workspaceDir, {
        filename,
        path: relativePath,
        title,
        area,
      }, ctx);
      if (syncResult.synced) {
        const epicMeta = syncResult.epicThread && syncResult.epicThread !== "n/a"
          ? `${syncResult.epicId} @thread ${syncResult.epicThread}`
          : syncResult.epicId;
        loopLine = `Loop sync: queued (${syncResult.id}, ${epicMeta})`;
      } else {
        loopLine = `Loop sync: skipped (${syncResult.reason})`;
      }
    } catch (err) {
      loopLine = `Loop sync: failed (${truncate(String(err?.message ?? err), 120)})`;
    }
  }

  return {
    text: [
      `Todo sparad: ${relativePath}`,
      `Title: ${title}`,
      `Area: ${area}`,
      commitLine,
      loopLine,
      "",
      "Nästa:",
      `- /gsd-check-todos ${area}`,
      "- /gsd-progress",
    ].join("\n"),
  };
}

async function handleNewEpic(api, ctx) {
  const args = (ctx.args ?? "").trim();
  if (!args) {
    return {
      text: "Usage: /gsd-new-epic <title>",
    };
  }

  const workspaceDir = resolveWorkspaceDir(api, ctx);
  const loop = resolveLoopConfig(api, workspaceDir);
  ensureLoopFiles(loop.inboxFile, loop.queueFile);

  let epicTitle = args[0].toUpperCase() + args.slice(1);
  const threadRef = resolveCurrentThreadRef(ctx);
  const existingFromThread = threadRef
    ? findEpicBindingByThread(loop.queueFile, threadRef) || findEpicBindingByThread(loop.inboxFile, threadRef)
    : null;
  const epicId = existingFromThread?.epicId || `EPIC-${safeSlugUpper(epicTitle)}`;
  if (existingFromThread?.epicTitle) epicTitle = existingFromThread.epicTitle;
  const intakeId = `${epicId}-INTAKE`;

  if (queueItemExists(loop.inboxFile, intakeId) || queueItemExists(loop.queueFile, intakeId)) {
    return {
      text: [
        `Epic finns redan: ${epicId}`,
        `Inbox: ${toPosixRel(workspaceDir, loop.inboxFile)}`,
      ].join("\n"),
    };
  }

  let epicThread = "n/a";
  let threadLine = "Forum thread: skipped";
  if (threadRef) {
    epicThread = threadRef;
    threadLine = `Forum thread: reused current thread (${epicThread})`;
  } else if (loop.autoThreadOnNewEpic) {
    const thread = await createDiscordEpicThread(api, loop, epicTitle, epicId);
    if (thread.created) {
      epicThread = thread.threadId || loop.discordForumTarget || "discord";
      threadLine = `Forum thread: created (${epicThread})`;
    } else if (thread.reason === "missing_target") {
      threadLine = "Forum thread: skipped (configure discordForumTarget)";
    } else {
      threadLine = `Forum thread: failed (${thread.reason})`;
    }
  }

  appendInboxItem(loop.inboxFile, {
    id: intakeId,
    title: `${epicTitle} (Epic intake)`,
    type: "feature",
    epicId,
    epicTitle,
    epicThread,
    gsdAction: "/gsd-discuss-phase",
    gsdPhase: "",
    impact: "high",
    effort: "m",
    nextStep: "break epic into executable tasks and promote one item",
    sourceArea: "planning",
  });

  appendQueueItem(loop.queueFile, {
    id: `${epicId}-DISCOVERY`,
    title: `${epicTitle} - discovery and scope`,
    source: "EPIC-INTAKE",
    sourcePath: toPosixRel(workspaceDir, loop.inboxFile),
    epicId,
    epicThread,
    gsdAction: "/gsd-discuss-phase",
    gsdPhase: "",
    priority: "P1",
  });

  return {
    text: [
      `Epic skapad: ${epicId}`,
      threadLine,
      `Inbox: ${toPosixRel(workspaceDir, loop.inboxFile)}`,
      `Queue: ${toPosixRel(workspaceDir, loop.queueFile)}`,
      "",
      "Nästa:",
      "- /gsd-discuss-phase 1",
      "- /gsd-plan-phase 1",
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
  if (gsdCommand === "new-epic") return await handleNewEpic(api, ctx);

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

function registerCgsdClickCommands(api) {
  const quickCommands = [
    {
      name: "cgsd-panel",
      description: "Open CGSD dashboard (click-first surface).",
      args: "",
    },
    {
      name: "cgsd-status",
      description: "Show activity status for the current bound project.",
      args: "status this",
    },
    {
      name: "cgsd-check",
      description: "Check current bound project against expected cron state.",
      args: "check this",
    },
    {
      name: "cgsd-off",
      description: "Set current bound project to off mode.",
      args: "set this off",
    },
    {
      name: "cgsd-medium",
      description: "Set current bound project to medium mode.",
      args: "set this medium",
    },
    {
      name: "cgsd-high",
      description: "Set current bound project to high mode.",
      args: "set this high",
    },
    {
      name: "cgsd-all-off",
      description: "Set all registered projects to off mode.",
      args: "set all off",
    },
    {
      name: "cgsd-all-medium",
      description: "Set all registered projects to medium mode.",
      args: "set all medium",
    },
    {
      name: "cgsd-all-high",
      description: "Set all registered projects to high mode.",
      args: "set all high",
    },
  ];

  for (const intensity of CGSD_CLICK_INTENSITY_LEVELS) {
    quickCommands.push({
      name: `cgsd-i${intensity}`,
      description: `Set current bound project intensity to ${intensity}%`,
      args: `intensity this ${intensity}`,
    });
  }

  for (const quick of quickCommands) {
    api.registerCommand({
      name: quick.name,
      description: quick.description,
      acceptsArgs: false,
      handler: async (ctx) => {
        return await handleCgsd(api, { ...ctx, args: quick.args });
      },
    });
  }
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

    api.registerCommand({
      name: "gsd-project-mode",
      description: "Manage project activity levels (off|medium|high) from chat.",
      acceptsArgs: true,
      handler: async (ctx) => {
        return await handleProjectMode(api, ctx);
      },
    });

    api.registerCommand({
      name: "gsd-project-bind",
      description: "Bind current channel/thread context to a project key.",
      acceptsArgs: true,
      handler: async (ctx) => {
        return await handleProjectBind(api, ctx);
      },
    });

    api.registerCommand({
      name: "badgeid-activity",
      description: "Backward-compatible alias for /gsd-project-mode ... badgeid",
      acceptsArgs: true,
      handler: async (ctx) => {
        return await handleBadgeidActivity(api, ctx);
      },
    });

    api.registerCommand({
      name: "cgsd",
      description: "CGSD control plane for per-project activity settings.",
      acceptsArgs: true,
      handler: async (ctx) => {
        return await handleCgsd(api, ctx);
      },
    });
    registerCgsdClickCommands(api);

    api.logger.info("GSD command aliases registered");
  },
};

export default plugin;
