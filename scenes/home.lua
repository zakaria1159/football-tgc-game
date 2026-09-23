-- Home scene router: home menu → deck select → match, plus the card library.
-- All layout and drawing lives in ui/menu/*; the state machine is ui/menu/flow.lua.
-- keypressed / mousepressed return "start", deckKey | "quit" | nil (see main.lua).
local Flow       = require("ui.menu.flow")
local HomeMenu   = require("ui.menu.home")
local DeckSelect = require("ui.menu.deckselect")
local Library    = require("ui.menu.library")

local Home = {}

local flow = Flow.new(#DeckSelect.DECKS)
local mouseX, mouseY = -1, -1
local lastHover = nil

-- Map a Flow action to main.lua's contract.
local function result(action, arg)
    if action == "start" then return "start", DeckSelect.DECKS[arg].key end
    if action == "quit" then return "quit" end
    if action == "openLibrary" then Library.open() end
    return nil
end

function Home.reset()
    flow = Flow.new(#DeckSelect.DECKS)
    lastHover = nil
end

function Home.update(dt)
    if flow.screen == "home" then
        -- hovering a button moves the keyboard focus to it
        local i = HomeMenu.buttonAt(mouseX, mouseY)
        if i ~= lastHover then
            lastHover = i
            if i then flow.home:set(i) end
        end
        HomeMenu.update(dt, mouseX, mouseY, flow.home.index)
    elseif flow.screen == "decks" then
        DeckSelect.update(dt, mouseX, mouseY, flow.decks.index)
    else
        Library.update(dt, mouseX, mouseY)
    end
end

function Home.draw()
    if flow.screen == "home" then
        HomeMenu.draw()
    elseif flow.screen == "decks" then
        DeckSelect.draw(flow.decks.index)
    else
        Library.draw()
    end
end

function Home.keypressed(key)
    if flow.screen == "library" then
        if Library.keypressed(key) == "close" then flow:closeLibrary() end
        return nil
    end
    return result(flow:key(key))
end

function Home.mousepressed(x, y, button)
    if flow.screen == "library" then
        if Library.mousepressed(x, y, button) == "close" then flow:closeLibrary() end
        return nil
    end
    if button ~= 1 then return nil end
    if flow.screen == "home" then
        local i = HomeMenu.buttonAt(x, y)
        if i then return result(flow:activateHome(i)) end
        return nil
    end
    local hit = DeckSelect.hitAt(x, y)
    if hit == "back" then return result(flow:back()) end
    if hit == "kickoff" then return result(flow:kickOff()) end
    if hit then return result(flow:clickDeck(hit)) end
    return nil
end

function Home.mousemoved(x, y) mouseX, mouseY = x, y end

function Home.wheelmoved(x, y)
    if flow.screen == "library" then Library.wheelmoved(x, y) end
end

return Home
