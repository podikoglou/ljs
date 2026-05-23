import { describe, it, expect, beforeEach } from "vitest";
import { transpile, emit, getPreamble, run, setVM, type LuaVM, type RunResult } from "./ljs-core";

class StubVM implements LuaVM {
  evalResult: unknown = null;
  evalError: Error | null = null;
  evalCalls: string[] = [];
  globals: Record<string, unknown> = {};
  logs: string[] = [];

  async eval(luaCode: string): Promise<unknown> {
    this.evalCalls.push(luaCode);
    if (this.evalError) throw this.evalError;
    return this.evalResult;
  }

  async setGlobal(name: string, value: unknown): Promise<void> {
    this.globals[name] = value;
  }

  async overridePrint(): Promise<string[]> {
    return this.logs;
  }
}

describe("transpile", () => {
  let stub: StubVM;

  beforeEach(() => {
    stub = new StubVM();
    setVM(stub);
  });

  it("returns code on success", async () => {
    stub.evalResult = { code: "local x = 1" };
    const result = await transpile("let x = 1");
    expect(result).toEqual({ code: "local x = 1", error: null });
    expect(stub.globals["__ljs_input"]).toBe("let x = 1");
  });

  it("returns structured error when transpile fails", async () => {
    stub.evalResult = {
      code: null,
      error: { message: "parse error: Unexpected token }", line: 1, col: 5 },
    };
    const result = await transpile("bad {");
    expect(result.code).toBeNull();
    expect(result.error).toEqual({
      message: "parse error: Unexpected token }",
      line: 1,
      col: 5,
    });
  });

  it("returns fallback error when eval throws", async () => {
    stub.evalError = new Error("vm crash");
    const result = await transpile("x");
    expect(result).toEqual({
      code: null,
      error: { message: "vm crash", line: 0, col: 0 },
    });
  });
});

describe("run", () => {
  let stub: StubVM;

  beforeEach(() => {
    stub = new StubVM();
    setVM(stub);
  });

  it("returns output and result on success", async () => {
    stub.evalResult = { result: 42 };
    stub.logs = ["hello", "world"];
    const result: RunResult = await run('console.log("hello")');
    expect(result).toEqual({ output: ["hello", "world"], result: 42, error: null });
    expect(stub.globals["__ljs_input"]).toBe('console.log("hello")');
  });

  it("returns structured error when run fails", async () => {
    stub.evalResult = {
      result: null,
      error: { message: "runtime error: boom", line: 0, col: 0 },
    };
    stub.logs = ["before crash"];
    const result = await run("throw 1");
    expect(result.output).toEqual(["before crash"]);
    expect(result.result).toBeNull();
    expect(result.error).toEqual({
      message: "runtime error: boom",
      line: 0,
      col: 0,
    });
  });

  it("returns fallback error when eval throws", async () => {
    stub.evalError = new Error("vm crash");
    stub.logs = [];
    const result = await run("x");
    expect(result.output).toEqual([]);
    expect(result.error).toEqual({ message: "vm crash", line: 0, col: 0 });
  });
});

describe("getPreamble", () => {
  let stub: StubVM;

  beforeEach(() => {
    stub = new StubVM();
    setVM(stub);
  });

  it("returns preamble string", async () => {
    stub.evalResult = "local _ljs_object_prototype = {}";
    const result = await getPreamble();
    expect(result).toBe("local _ljs_object_prototype = {}");
    expect(stub.evalCalls[0]).toContain("preamble()");
  });
});

describe("emit", () => {
  let stub: StubVM;

  beforeEach(() => {
    stub = new StubVM();
    setVM(stub);
  });

  it("returns user code on success", async () => {
    stub.evalResult = { code: "local x = 1" };
    const result = await emit("let x = 1");
    expect(result).toEqual({ code: "local x = 1", error: null });
    expect(stub.evalCalls[0]).toContain("ljs.emit");
  });

  it("returns structured error when parse fails", async () => {
    stub.evalResult = {
      code: null,
      error: { message: "Unexpected token ;", line: 1, col: 5 },
    };
    const result = await emit("let x = ;");
    expect(result.code).toBeNull();
    expect(result.error).toEqual({
      message: "Unexpected token ;",
      line: 1,
      col: 5,
    });
  });

  it("returns fallback error when eval throws", async () => {
    stub.evalError = new Error("vm crash");
    const result = await emit("x");
    expect(result).toEqual({
      code: null,
      error: { message: "vm crash", line: 0, col: 0 },
    });
  });
});
