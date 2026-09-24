-- Runs every tests/test_*.lua file with plain Lua (no LÖVE).
-- Usage (from repo root): lua tests/run.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.t")
local p = io.popen("ls tests/test_*.lua 2>/dev/null")
local files = {}
for line in p:lines() do files[#files + 1] = line end
p:close()
table.sort(files)

for _, path in ipairs(files) do
    local mod = path:gsub("%.lua$", ""):gsub("/", ".")
    local ok, err = pcall(require, mod)
    if not ok then
        T.failed = T.failed + 1
        print("FAIL  " .. path .. " (load error)\n      " .. tostring(err))
    end
end
T.report()
