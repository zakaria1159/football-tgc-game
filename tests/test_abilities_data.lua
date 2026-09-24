local T        = require("tests.t")
local Resolver = require("engine.cards.resolver")

local FIELD = { "strikers", "midfielders", "defenders", "keepers" }
local function all()
    local out = {}
    for _, f in ipairs(FIELD) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do out[#out + 1] = d end
    end
    return out
end

-- Spec §1 (owner-approved): card id → keyword.
local WANT = {
    ["str-clinical-finisher"] = "CLINICAL", ["str-target-man"] = "AERIAL",
    ["str-speed-demon"] = "PACE", ["str-complete-forward"] = "LINK_UP",
    ["str-fox-in-the-box"] = "INSTINCT", ["str-poacher"] = "OPPORTUNIST",
    ["str-pressing-forward"] = "PRESS", ["str-pacy-winger"] = "BEAT_THE_MAN",
    ["mid-box-to-box"] = "ENGINE", ["mid-deep-lying-playmaker"] = "METRONOME",
    ["mid-pressing-monster"] = "COUNTER_PRESS", ["mid-creative-playmaker"] = "THROUGH_BALL",
    ["mid-direct-support"] = "OVERLAP",
    ["def-the-rock"] = "IMMOVABLE", ["def-stopper"] = "LAST_MAN",
    ["def-catenaccio-anchor"] = "BOLT", ["def-destroyer"] = "HARD_TACKLE",
    ["def-pressing-back"] = "INTERCEPT", ["def-ball-playing"] = "BUILD_UP",
    ["def-libero"] = "SWEEPER",
    ["keeper-the-wall"] = "FORTRESS", ["keeper-iron-fists"] = "PUNCH_CLEAR",
    ["keeper-sweeper-keeper"] = "OFF_THE_LINE", ["keeper-reliable-hands"] = "SAFE_HANDS",
}

T.test("abilities data: every field card has its owner-approved keyword", function()
    local n = 0
    for _, d in ipairs(all()) do
        n = n + 1
        T.eq(d.keyword, WANT[d.id], d.id)
    end
    T.eq(n, 24)
end)

T.test("abilities data: display names and rules text", function()
    for _, d in ipairs(all()) do
        T.eq(d.keywordName, Resolver.NAMES[d.keyword], d.id .. " keywordName")
        T.ok(type(d.abilityText) == "string" and #d.abilityText >= 30, d.id .. " rules text")
    end
end)

T.test("abilities data: 24 distinct keywords, all in Resolver.ORDER", function()
    local seen = {}
    for _, d in ipairs(all()) do
        T.ok(not seen[d.keyword], "duplicate " .. tostring(d.keyword))
        seen[d.keyword] = true
    end
    local n = 0
    for _, kw in ipairs(Resolver.ORDER) do
        n = n + 1
        T.ok(seen[kw], "unused " .. kw)
    end
    T.eq(n, 24)
end)

T.test("abilities data: traps and strategies keep `ability` and get no keyword", function()
    for _, f in ipairs({ "traps", "strategies" }) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do
            T.eq(d.keyword, nil, d.id)
            T.ok(d.ability ~= nil, d.id .. " ability")
        end
    end
end)
