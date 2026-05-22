function App() {
  return (
    <div className="grid h-full grid-cols-2 grid-rows-[1fr_auto]">
      <div className="flex flex-col border-r border-base-850">
        <div className="flex items-center justify-between border-b border-base-850 px-3 py-1">
          <span className="text-xs text-base-400">JavaScript</span>
          <button
            type="button"
            className="bg-base-850 px-3 py-0.5 text-xs text-base-300 hover:text-base-200"
          >
            Run
          </button>
        </div>
        <div className="flex-1 overflow-auto" />
      </div>
      <div className="flex flex-col">
        <div className="border-b border-base-850 px-3 py-1">
          <span className="text-xs text-base-400">Lua</span>
        </div>
        <div className="flex-1 overflow-auto" />
      </div>
      <div className="col-span-2 flex flex-col border-t border-base-850">
        <div className="border-b border-base-850 px-3 py-1">
          <span className="text-xs text-base-400">Console</span>
        </div>
        <div className="flex-1 overflow-auto bg-base-950 p-3">
          <pre className="text-xs text-base-300" />
        </div>
      </div>
    </div>
  )
}

export default App
