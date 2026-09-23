-- Minimal test framework for pure-Lua modules. Run via: lua tests/run.lua
local T = { passed = 0, failed = 0, current = "?" }

function T.test(name, fn)
    T.current = name
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        print("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for i, x in ipairs(v) do parts[i] = tostring(x) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "eq") .. ": expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.near(actual, expected, eps, msg)
    eps = eps or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        error((msg or "near") .. ": expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.ok(v, msg)
    if not v then error(msg or "expected truthy value", 2) end
end

function T.report()
    print(string.format("%d passed, %d failed", T.passed, T.failed))
    if T.failed > 0 then os.exit(1) end
end

return T
