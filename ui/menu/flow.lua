-- Home-scene state machine: home menu → deck select → match, plus the card library.
-- Pure (unit-tested). Methods return an action for scenes/home.lua:
--   "quit" | "start", deckIndex | "openLibrary" | nil
-- Library keys/clicks are handled by ui/menu/library.lua; call closeLibrary when it closes.
local Nav = require("ui.menu.nav")

local Flow = {}
Flow.__index = Flow

Flow.HOME_ITEMS = { "play", "library", "quit" }

local ENTER = { ["return"] = true, kpenter = true, space = true }

function Flow.new(deckCount)
    return setmetatable({
        screen = "home",
        home   = Nav.new(#Flow.HOME_ITEMS, { wrap = true }),
        decks  = Nav.new(deckCount or 3),
    }, Flow)
end

-- Activate home item i (click, or Enter on the focused item).
function Flow:activateHome(i)
    self.home:set(i)
    local item = Flow.HOME_ITEMS[self.home.index]
    if item == "play" then
        self.screen = "decks"
        return nil
    elseif item == "library" then
        self.screen = "library"
        return "openLibrary"
    end
    return "quit"
end

-- Deck tile click: the first click selects, a click on the selected tile starts.
function Flow:clickDeck(i)
    if self.decks.index == i then return "start", i end
    self.decks:set(i)
    return nil
end

function Flow:kickOff()      return "start", self.decks.index end
function Flow:back()         self.screen = "home"; return nil end
function Flow:closeLibrary() self.screen = "home"; return nil end

function Flow:key(key)
    if self.screen == "home" then
        if key == "up" then self.home:move(-1)
        elseif key == "down" then self.home:move(1)
        elseif ENTER[key] then return self:activateHome(self.home.index)
        elseif key == "escape" then return "quit" end
    elseif self.screen == "decks" then
        if key == "left" then self.decks:move(-1)
        elseif key == "right" then self.decks:move(1)
        elseif ENTER[key] then return self:kickOff()
        elseif key == "escape" or key == "backspace" then return self:back() end
    end
    return nil
end

return Flow
