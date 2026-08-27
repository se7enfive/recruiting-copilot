import test from "node:test";
import assert from "node:assert/strict";
import { createRouteSession, makeRouteHandler } from "../lib/index.js";

const HOST = "127.0.0.1:3081";

function makeRequest({ method = "GET", url, headers = {}, body } = {}) {
  const listeners = new Map();
  const req = {
    method,
    url,
    headers,
    on(event, handler) {
      listeners.set(event, handler);
      return this;
    },
    destroy() {
      listeners.get("close")?.();
    }
  };
  const response = {
    statusCode: null,
    headers: null,
    chunks: [],
    ended: false,
    writeHead(status, responseHeaders) {
      this.statusCode = status;
      this.headers = responseHeaders;
    },
    write(chunk) {
      this.chunks.push(chunk);
      return true;
    },
    end(chunk) {
      if (chunk !== undefined) this.chunks.push(chunk);
      this.ended = true;
    },
    on() {
      return this;
    },
    get writableEnded() {
      return this.ended;
    }
  };
  return {
    req,
    response,
    emitBody() {
      if (body === undefined) return;
      listeners.get("data")?.(Buffer.from(JSON.stringify(body)));
      listeners.get("end")?.();
    }
  };
}

async function call(handler, request) {
  const pending = handler(request.req, request.response);
  request.emitBody();
  await pending;
  return request.response;
}

function mirrorStub() {
  const calls = [];
  return {
    calls,
    name: "boss",
    state: {
      name: "boss",
      connected: false,
      pages: [],
      risk: null
    },
    setWatch(on) {
      calls.push({ action: "watch", on });
    },
    dispatchInput() {
      calls.push({ action: "input" });
      return 1;
    },
    setTarget(pageId) {
      calls.push({ action: "set-target", pageId });
    }
  };
}

function sameOriginHeaders(cookie) {
  return {
    host: HOST,
    "sec-fetch-site": "same-origin",
    "x-rcp-client-nonce": "client-nonce-1234",
    ...(cookie ? { cookie } : {})
  };
}

test("没有来源证明的请求不能读取招聘浏览器状态", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const response = await call(handler, makeRequest({ url: "/plugins/recruiting-view/state.json" }));
  assert.equal(response.statusCode, 403);
  assert.match(response.chunks[0].toString(), /cross-origin/);
});

test("非 loopback host 不能访问招聘浏览器路由", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const response = await call(handler, makeRequest({
    url: "/plugins/recruiting-view/state.json",
    headers: {
      host: "192.168.1.10:3081",
      "sec-fetch-site": "same-origin",
      "x-rcp-client-nonce": "client-nonce-1234"
    }
  }));
  assert.equal(response.statusCode, 403);
});

test("跨站请求即使带有会话 cookie 也不能控制浏览器", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const response = await call(handler, makeRequest({
    method: "POST",
    url: "/plugins/recruiting-view/control?source=boss",
    headers: {
      host: HOST,
      cookie: "rcp_session=route-test-token-1234",
      origin: "https://evil.example",
      "sec-fetch-site": "cross-site"
    },
    body: { action: "watch", on: true }
  }));
  assert.equal(response.statusCode, 403);
  assert.deepEqual(mirror.calls, []);
});

test("同源 state 请求首次建立 HttpOnly 会话 cookie，响应不泄露秘密", async () => {
  const session = createRouteSession("route-test-token-1234");
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], session);
  const response = await call(handler, makeRequest({
    url: "/plugins/recruiting-view/state.json",
    headers: sameOriginHeaders()
  }));
  assert.equal(response.statusCode, 200);
  assert.match(response.headers["set-cookie"], /^rcp_session=route-test-token-1234;/);
  assert.match(response.headers["set-cookie"], /HttpOnly/);
  assert.match(response.headers["set-cookie"], /SameSite=Strict/);
  assert.doesNotMatch(response.chunks[0].toString(), /route-test-token-1234/);
});

test("没有有效 cookie 的同源 POST 不能执行控制动作", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const response = await call(handler, makeRequest({
    method: "POST",
    url: "/plugins/recruiting-view/control?source=boss",
    headers: sameOriginHeaders(),
    body: { action: "watch", on: true }
  }));
  assert.equal(response.statusCode, 401);
  assert.deepEqual(mirror.calls, []);
});

test("有效会话可以执行 POST 控制动作，但 GET 不能触发 action", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const cookie = "rcp_session=route-test-token-1234";

  const getResponse = await call(handler, makeRequest({
    url: "/plugins/recruiting-view/control?source=boss&action=watch",
    headers: sameOriginHeaders(cookie)
  }));
  assert.equal(getResponse.statusCode, 405);
  assert.deepEqual(mirror.calls, []);

  const postResponse = await call(handler, makeRequest({
    method: "POST",
    url: "/plugins/recruiting-view/control?source=boss",
    headers: sameOriginHeaders(cookie),
    body: { action: "watch", on: true }
  }));
  assert.equal(postResponse.statusCode, 200);
  assert.deepEqual(mirror.calls, [{ action: "watch", on: true }]);
});

test("直接 set-target 也只接受带会话的 POST", async () => {
  const mirror = mirrorStub();
  const handler = makeRouteHandler([mirror], createRouteSession("route-test-token-1234"));
  const cookie = "rcp_session=route-test-token-1234";

  const getResponse = await call(handler, makeRequest({
    url: "/plugins/recruiting-view/set-target?pageId=secret",
    headers: sameOriginHeaders(cookie)
  }));
  assert.equal(getResponse.statusCode, 405);
  assert.deepEqual(mirror.calls, []);

  const postResponse = await call(handler, makeRequest({
    method: "POST",
    url: "/plugins/recruiting-view/set-target",
    headers: sameOriginHeaders(cookie),
    body: { pageId: "page-1" }
  }));
  assert.equal(postResponse.statusCode, 200);
  assert.deepEqual(mirror.calls, [{ action: "set-target", pageId: "page-1" }]);
});
