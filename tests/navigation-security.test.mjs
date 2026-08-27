import test from "node:test";
import assert from "node:assert/strict";
import { BrowserMirror } from "../lib/index.js";

test("浏览器面板导航只允许 HTTP(S)，不把 CDP 浏览器当作本地协议跳板", async () => {
  const mirror = new BrowserMirror({ name: "test", port: 1, match: /x/ });
  const calls = [];
  mirror._command = (method, params) => {
    calls.push({ method, params });
    return Promise.resolve({ result: {} });
  };

  assert.equal((await mirror.navigate("file:///etc/passwd")).ok, false);
  assert.equal((await mirror.navigate("chrome://settings")).ok, false);
  assert.equal((await mirror.navigate("javascript:alert(1)")).ok, false);
  assert.equal(calls.length, 0);

  assert.deepEqual(await mirror.navigate("example.com"), { ok: true });
  assert.equal(calls[0].params.url, "https://example.com/");
});
