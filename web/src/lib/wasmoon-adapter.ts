import { LuaFactory, type LuaEngine } from "wasmoon";

import ljsSource from "@ljs/src/ljs.lua?raw";
import ljsParserSource from "@ljs/src/ljs/parser.lua?raw";
import ljsTranspileSource from "@ljs/src/ljs/transpile.lua?raw";
import ljsCodegenSource from "@ljs/src/ljs/codegen.lua?raw";
import runtimeArraySource from "@ljs/src/ljs/runtime/array.lua?raw";
import runtimeConsoleSource from "@ljs/src/ljs/runtime/console.lua?raw";
import runtimeFunctionSource from "@ljs/src/ljs/runtime/function.lua?raw";
import runtimeObjectSource from "@ljs/src/ljs/runtime/object.lua?raw";
import runtimeProtoSource from "@ljs/src/ljs/runtime/proto.lua?raw";

import type { LuaVM } from "./ljs-core";

export class WasmoonAdapter implements LuaVM {
  private factory = new LuaFactory();
  private engine: LuaEngine | null = null;

  private async getEngine(): Promise<LuaEngine> {
    if (this.engine) return this.engine;

    const e = await this.factory.createEngine();

    await this.factory.mountFile("ljs.lua", ljsSource);
    await this.factory.mountFile("ljs/parser.lua", ljsParserSource);
    await this.factory.mountFile("ljs/transpile.lua", ljsTranspileSource);
    await this.factory.mountFile("ljs/codegen.lua", ljsCodegenSource);
    await this.factory.mountFile("ljs/runtime/array.lua", runtimeArraySource);
    await this.factory.mountFile("ljs/runtime/console.lua", runtimeConsoleSource);
    await this.factory.mountFile("ljs/runtime/function.lua", runtimeFunctionSource);
    await this.factory.mountFile("ljs/runtime/object.lua", runtimeObjectSource);
    await this.factory.mountFile("ljs/runtime/proto.lua", runtimeProtoSource);

    await e.doString('require("ljs")');

    this.engine = e;
    return this.engine;
  }

  async eval(luaCode: string): Promise<unknown> {
    const e = await this.getEngine();
    return e.doString(luaCode);
  }

  async setGlobal(name: string, value: unknown): Promise<void> {
    const e = await this.getEngine();
    e.global.set(name, value);
  }

  async overridePrint(): Promise<string[]> {
    const e = await this.getEngine();
    const logs: string[] = [];

    e.global.getTable("_G", (index: number) => {
      e.global.setField(index, "print", (...args: unknown[]) => {
        logs.push(args.map((a) => String(a)).join("\t"));
      });
    });

    return logs;
  }
}
