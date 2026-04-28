-- store/gwent.lua
local GState  = require("engine.gwent.state")
local Phases  = require("engine.gwent.phases")
local GDecks  = require("data.gwent_decks")

local Store = {}
Store.__index = Store

function Store.new()
    local s = setmetatable({}, Store)
    s.match        = nil
    s.onUpdate     = nil
    s.aiDifficulty = "medium"
    return s
end

function Store:startMatch(playerFaction, opponentFaction, difficulty)
    local pd = GDecks[playerFaction]
    local od = GDecks[opponentFaction]
    if not pd then error("Unknown faction: " .. tostring(playerFaction)) end
    if not od then error("Unknown faction: " .. tostring(opponentFaction)) end
    self.match        = GState.newMatch(pd, od)
    self.aiDifficulty = difficulty or "medium"
    self:_notify()
end

-- ── Mulligan ──────────────────────────────────────────────────────────────────

function Store:resolveMulligan(playerId, instanceIds)
    if not self.match or self.match.phase ~= "mulligan" then return end
    Phases.resolveMulligan(self.match, playerId or "player", instanceIds or {})
    self:_notify()
end

-- ── Play actions ──────────────────────────────────────────────────────────────

function Store:playCard(instanceId, row, opts)
    if not self.match or self.match.phase ~= "play" then return false end
    local ok = Phases.playCard(self.match, instanceId, row, opts)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

function Store:playSpecial(instanceId, opts)
    if not self.match or self.match.phase ~= "play" then return false end
    local ok = Phases.playSpecial(self.match, instanceId, opts)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

-- ── Resolve pending actions ───────────────────────────────────────────────────

function Store:resolveAgility(chosenRow)
    if not self.match then return false end
    local ok = Phases.resolveAgility(self.match, chosenRow)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

function Store:resolveMedic(graveyardIndex)
    if not self.match then return false end
    local ok = Phases.resolveMedic(self.match, graveyardIndex)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

function Store:resolveDecoy(targetRow, targetIndex)
    if not self.match then return false end
    local ok = Phases.resolveDecoy(self.match, targetRow, targetIndex)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

function Store:resolveHorn(chosenRow)
    if not self.match then return false end
    local ok = Phases.resolveHorn(self.match, chosenRow)
    if ok and not self.match.pendingAction then
        Phases.endTurn(self.match)
        self:_checkHalfEnd()
    end
    self:_notify()
    return ok
end

-- ── Pass / Leader ─────────────────────────────────────────────────────────────

function Store:pass()
    if not self.match or self.match.phase ~= "play" then return end
    Phases.pass(self.match)
    self:_notify()
end

function Store:activateLeader(opts)
    if not self.match or self.match.phase ~= "play" then return false end
    local ok = Phases.activateLeader(self.match, self.match.activePlayer, opts)
    self:_notify()
    return ok
end

-- ── Internals ─────────────────────────────────────────────────────────────────

function Store:_checkHalfEnd()
    if not self.match then return end
    if self.match.phase == "play"
    and self.match.passed.player and self.match.passed.opponent then
        Phases.endHalf(self.match)
    end
end

function Store:_notify()
    if self.onUpdate then self.onUpdate(self.match) end
end

return Store
