#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const pluginPath = "/home/irony/code/cgsd/plugins/gsd-command-aliases/index.js";
const pluginUrl = pathToFileURL(pluginPath).href;

async function main() {
  const { default: plugin } = await import(pluginUrl);

  const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "cgsd-project-controls-"));
  process.env.HOME = tempHome;

  const registryPath = path.join(tempHome, ".openclaw", "cgsd-project-activity.json");
  fs.mkdirSync(path.dirname(registryPath), { recursive: true });
  const gammaRoot = path.join(tempHome, "projects", "gamma");
  fs.mkdirSync(gammaRoot, { recursive: true });

  const registry = {
  version: 1,
  projects: {
    demo: {
      projectKey: "demo",
      projectRoot: "/tmp/demo",
      currentMode: "high",
      delivery: { channel: "discord", target: "chan-demo", forumTarget: "forum-demo" },
      jobs: [
        {
          key: "ralph",
          name: "Kai RalphClaw [demo]",
          id: "job-demo-ralph",
          modes: {
            off: { enabled: false },
            medium: { enabled: true, cron: "*/20 * * * *" },
            high: { enabled: true, cron: "*/10 * * * *" },
          },
        },
        {
          key: "autoclaw",
          name: "Kai AutoClaw [demo]",
          id: "job-demo-autoclaw",
          modes: {
            off: { enabled: false },
            medium: { enabled: true, cron: "0 */4 * * *" },
            high: { enabled: true, cron: "0 */2 * * *" },
          },
        },
      ],
    },
    alpha: {
      projectKey: "alpha",
      projectRoot: "/tmp/alpha",
      currentMode: "high",
      delivery: { channel: "discord", target: "chan-alpha", forumTarget: "forum-alpha" },
      jobs: [
        {
          key: "ralph",
          name: "Kai RalphClaw [alpha]",
          id: "job-alpha-ralph",
          modes: {
            off: { enabled: false },
            medium: { enabled: true, cron: "*/30 * * * *" },
            high: { enabled: true, cron: "*/15 * * * *" },
          },
        },
      ],
    },
    badgeid: {
      projectKey: "badgeid",
      projectRoot: "/tmp/badgeid",
      currentMode: "high",
      delivery: { channel: "discord", target: "chan-badgeid", forumTarget: "forum-badgeid" },
      jobs: [
        {
          key: "ralph",
          name: "Kai RalphClaw [badgeid]",
          id: "job-badgeid-ralph",
          modes: {
            off: { enabled: false },
            medium: { enabled: true, cron: "*/22 * * * *" },
            high: { enabled: true, cron: "*/11 * * * *" },
          },
        },
      ],
    },
  },
  channelProjectMap: {},
};
  fs.writeFileSync(registryPath, `${JSON.stringify(registry, null, 2)}\n`, "utf8");

  const runtimeJobs = [
  {
    id: "job-demo-ralph",
    name: "Kai RalphClaw [demo]",
    enabled: true,
    schedule: { expr: "*/10 * * * *" },
  },
  {
    id: "job-demo-autoclaw",
    name: "Kai AutoClaw [demo]",
    enabled: true,
    schedule: { expr: "0 */2 * * *" },
  },
  {
    id: "job-alpha-ralph",
    name: "Kai RalphClaw [alpha]",
    enabled: true,
    schedule: { expr: "*/15 * * * *" },
  },
  {
    id: "job-badgeid-ralph",
    name: "Kai RalphClaw [badgeid]",
    enabled: true,
    schedule: { expr: "*/11 * * * *" },
  },
  ];

  const commandHandlers = new Map();
  const api = {
  config: {},
  source: pluginPath,
  logger: { info: () => {} },
  runtime: {
    system: {
      runCommandWithTimeout: async (argv) => {
        if (argv[0] !== "openclaw" || argv[1] !== "cron") {
          return { code: 1, stdout: "", stderr: `unexpected command: ${argv.join(" ")}` };
        }

        const sub = argv[2];
        if (sub === "list" && argv.includes("--json")) {
          return { code: 0, stdout: JSON.stringify({ jobs: runtimeJobs }), stderr: "" };
        }

        const id = argv[3];
        const job = runtimeJobs.find((j) => j.id === id);
        if (!job) {
          return { code: 1, stdout: "", stderr: `unknown job id: ${id}` };
        }

        if (sub === "enable") {
          job.enabled = true;
          return { code: 0, stdout: JSON.stringify(job), stderr: "" };
        }
        if (sub === "disable") {
          job.enabled = false;
          return { code: 0, stdout: JSON.stringify(job), stderr: "" };
        }
        if (sub === "edit") {
          job.enabled = true;
          const cronIdx = argv.indexOf("--cron");
          if (cronIdx !== -1 && argv[cronIdx + 1]) {
            job.schedule.expr = argv[cronIdx + 1];
          }
          return { code: 0, stdout: JSON.stringify(job), stderr: "" };
        }

        return { code: 1, stdout: "", stderr: `unsupported cron command: ${argv.join(" ")}` };
      },
    },
  },
  registerCommand: ({ name, handler }) => {
    commandHandlers.set(name, handler);
  },
  };

  plugin.register(api);

  const mode = commandHandlers.get("gsd-project-mode");
  const bind = commandHandlers.get("gsd-project-bind");
  const badgeidActivity = commandHandlers.get("badgeid-activity");
  const cgsd = commandHandlers.get("cgsd");
  const cgsdPanel = commandHandlers.get("cgsd-panel");
  const cgsdStatus = commandHandlers.get("cgsd-status");
  const cgsdCheck = commandHandlers.get("cgsd-check");
  const cgsdHigh = commandHandlers.get("cgsd-high");
  const cgsdI80 = commandHandlers.get("cgsd-i80");
  const cgsdAllOff = commandHandlers.get("cgsd-all-off");
  assert.ok(mode, "gsd-project-mode command should register");
  assert.ok(bind, "gsd-project-bind command should register");
  assert.ok(badgeidActivity, "badgeid-activity command should register");
  assert.ok(cgsd, "cgsd command should register");
  assert.ok(cgsdPanel, "cgsd-panel command should register");
  assert.ok(cgsdStatus, "cgsd-status command should register");
  assert.ok(cgsdCheck, "cgsd-check command should register");
  assert.ok(cgsdHigh, "cgsd-high command should register");
  assert.ok(cgsdI80, "cgsd-i80 command should register");
  assert.ok(cgsdAllOff, "cgsd-all-off command should register");

  const ambiguousCtx = {
  channel: "discord",
  target: "chan-unknown",
  messageThreadId: "thread-unknown",
  args: "status",
  };
  const ambiguous = await mode(ambiguousCtx);
  assert.match(ambiguous.text, /Could not resolve project/i);

  const bindCtx = {
  channel: "discord",
  target: "chan-demo",
  messageThreadId: "thread-demo-1",
  args: "demo",
  };
  const bindRes = await bind(bindCtx);
  assert.match(bindRes.text, /Bound 2 ref\(s\)/);

  const showRes = await bind({ ...bindCtx, args: "show this" });
  assert.match(showRes.text, /chan-demo -> demo/);

  const aliasMode = await badgeidActivity({ ...bindCtx, args: "medium" });
  assert.match(aliasMode.text, /mode medium/i);
  assert.equal(runtimeJobs.find((j) => j.id === "job-badgeid-ralph")?.schedule.expr, "*/22 * * * *");

  const setMedium = await mode({ ...bindCtx, args: "medium" });
  assert.match(setMedium.text, /mode medium/i);
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-ralph")?.schedule.expr, "*/20 * * * *");
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-autoclaw")?.schedule.expr, "0 */4 * * *");

  const checkDemo = await mode({ ...bindCtx, args: "check this" });
  assert.match(checkDemo.text, /CHECK_OK/);

  const quickStatus = await cgsdStatus({ ...bindCtx, args: "" });
  assert.match(quickStatus.text, /Project demo/i);

  const quickCheck = await cgsdCheck({ ...bindCtx, args: "" });
  assert.match(quickCheck.text, /CHECK_OK|CHECK_FAIL/);

  const quickHigh = await cgsdHigh({ ...bindCtx, args: "" });
  assert.match(quickHigh.text, /mode high/i);
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-ralph")?.schedule.expr, "*/10 * * * *");

  const quickIntensity = await cgsdI80({ ...bindCtx, args: "" });
  assert.match(quickIntensity.text, /Intensity 80% mapped to mode=high/i);
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-autoclaw")?.schedule.expr, "0 */2 * * *");

  const quickPanel = await cgsdPanel({ ...bindCtx, args: "" });
  assert.match(quickPanel.text, /CGSD Control Dashboard/i);

  const addProject = await cgsd({ ...bindCtx, args: `add-project gamma ${gammaRoot}` });
  assert.match(addProject.text, /Registered project 'gamma'|Updated project 'gamma' root/i);
  const addedRegistry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
  assert.equal(addedRegistry.projects.gamma.projectRoot, gammaRoot);
  assert.equal(addedRegistry.projects.gamma.currentMode, "high");
  assert.equal(addedRegistry.projects.gamma.jobs.length, 0);

  const setAllOff = await cgsdAllOff({ ...bindCtx, args: "" });
  assert.match(setAllOff.text, /CHECK_OK|CHECK_FAIL/);
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-ralph")?.enabled, false);
  assert.equal(runtimeJobs.find((j) => j.id === "job-demo-autoclaw")?.enabled, false);
  assert.equal(runtimeJobs.find((j) => j.id === "job-alpha-ralph")?.enabled, false);
  assert.equal(runtimeJobs.find((j) => j.id === "job-badgeid-ralph")?.enabled, false);

  const savedRegistry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
  assert.equal(savedRegistry.projects.demo.currentMode, "off");
  assert.equal(savedRegistry.projects.alpha.currentMode, "off");
  assert.equal(savedRegistry.projects.badgeid.currentMode, "off");
  assert.equal(savedRegistry.projects.gamma.currentMode, "off");
  assert.equal(savedRegistry.projects.gamma.projectRoot, gammaRoot);
  assert.equal(savedRegistry.projects.gamma.jobs.length, 0);
  assert.equal(savedRegistry.channelProjectMap["chan-demo"], "demo");
  assert.equal(savedRegistry.channelProjectMap["thread-demo-1"], "demo");

  console.log("PASS: gsd project controls plugin test suite");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
