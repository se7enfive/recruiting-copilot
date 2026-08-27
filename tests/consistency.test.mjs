import test from "node:test";
import assert from "node:assert/strict";
import { lstatSync, readFileSync, readlinkSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = [
  "ask-viy",
  "recruit-init",
  "recruit-grill",
  "recruit-daily",
  "recruit-daily-51job",
  "51job-env-setup",
  "resume-review",
  "interview-schedule",
  "market-talent-mapping"
];
const ADAPTERS = [".agents", ".claude", ".qoder"];
const COMMANDS = {
  "ask-viy": "skills/ask-viy/SKILL.md",
  "recruit-init": "skills/recruit-init/SKILL.md",
  "recruit-grill": "skills/recruit-grill/SKILL.md",
  "recruit-daily": "skills/recruit-daily/SKILL.md",
  "recruit-daily-51job": "skills/recruit-daily-51job/SKILL.md",
  "51job-env-setup": "skills/51job-env-setup/SKILL.md",
  "resume-review": "skills/resume-review/SKILL.md",
  "interview-schedule": "skills/interview-schedule/SKILL.md",
  "recruit-mapping": "skills/market-talent-mapping/SKILL.md"
};

function readAdapterTarget(entry) {
  const stat = lstatSync(entry);
  if (stat.isSymbolicLink()) return readlinkSync(entry);
  // Windows checkouts without symlink privileges materialize Git link blobs as text files.
  return readFileSync(entry, "utf8").trim();
}

test("9 个 skill 都有实现，并且三个静态适配器入口都指向它们", () => {
  for (const skill of SKILLS) {
    assert.ok(lstatSync(path.join(ROOT, "skills", skill, "SKILL.md")), `missing skill: ${skill}`);
    for (const adapter of ADAPTERS) {
      const entry = path.join(ROOT, adapter, "skills", skill);
      assert.equal(readAdapterTarget(entry), `../../skills/${skill}`, `wrong ${adapter} entry for ${skill}`);
    }
  }
});

test("Claude Code 命令覆盖全部公开 skill，且 51job 有独立入口", () => {
  for (const [command, target] of Object.entries(COMMANDS)) {
    const content = readFileSync(path.join(ROOT, "commands", `${command}.md`), "utf8");
    assert.match(content, new RegExp(target.replaceAll("/", "\\/")), `command does not route to ${target}`);
  }
});

test("插件元数据版本一致，skills 目录没有漏报或多报", () => {
  const packageJson = JSON.parse(readFileSync(path.join(ROOT, "package.json"), "utf8"));
  const pluginJson = JSON.parse(readFileSync(path.join(ROOT, ".claude-plugin", "plugin.json"), "utf8"));
  const actual = readdirSync(path.join(ROOT, "skills"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && SKILLS.includes(entry.name))
    .map((entry) => entry.name)
    .sort();
  assert.equal(packageJson.version, pluginJson.version);
  assert.deepEqual(actual, [...SKILLS].sort());
  assert.match(packageJson.description, /51job/);
  assert.match(pluginJson.description, /51job/);
});

test("源码仓库和工作区模板都会隔离本地招聘数据", () => {
  const rootIgnore = readFileSync(path.join(ROOT, ".gitignore"), "utf8");
  const templateIgnore = readFileSync(path.join(ROOT, "skills", "recruit-init", "templates", ".gitignore"), "utf8");
  assert.ok(rootIgnore.split(/\r?\n/).includes(".workbuddy/"));
  assert.ok(rootIgnore.split(/\r?\n/).includes("runtime/"));
  assert.ok(templateIgnore.split(/\r?\n/).includes(".workbuddy/"));
  assert.ok(templateIgnore.split(/\r?\n/).includes("runtime/"));
});
