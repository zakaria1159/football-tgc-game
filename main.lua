-- Football TCG — main.lua
math.randomseed(os.time())

local flux      = require("lib.flux")
local Theme     = require("ui.theme")
local Fonts     = require("ui.fonts")
local Home      = require("scenes.home")
local Match     = require("scenes.match")
local Store     = require("store.match")
local Decks     = require("data.presetDecks")
local Audio     = require("ui.audio")

local currentScene = "home"
local store        = Store.new()
local camera       = { x = 0, y = 0 }
local lastDeckKey  = nil        -- PLAY AGAIN restarts with the same deck
Match._camera      = camera

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function startMatch(deckKey)
    lastDeckKey = deckKey
    local playerData   = Decks[deckKey]
    local opponentData = Decks.tikitaka
    store:startMatch(playerData.cards, opponentData.cards)
    store.onUpdate = function(match)
        if match and match.log and #match.log > 0 then
            local last = match.log[#match.log]
            if last.type == "lp_damage" then
                camera.x = 6; flux.to(camera, 0.35, { x = 0 }):ease("elasticout")
            elseif last.type == "defender_destroy" then
                camera.x = 3; flux.to(camera, 0.20, { x = 0 }):ease("elasticout")
                Audio.play("destroy")
            end
        end
    end
    Match.enter(store, "medium")
    Audio.playMusic("assets/audio/music/theme_match.ogg", 0.45)
    currentScene = "match"
end

local function goHome()
    Home.reset(); currentScene = "home"
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

-- Home scene result: "start", deckKey | "quit" | nil
local function onHome(action, deckKey)
    if action == "start" then startMatch(deckKey)
    elseif action == "quit" then love.event.quit() end
end

-- Match scene result: "home" | "restart" | nil
local function onMatch(action)
    if action == "home" then
        goHome()
    elseif action == "restart" then
        if lastDeckKey then startMatch(lastDeckKey) else goHome() end
    end
end

-- ── Love2D callbacks ──────────────────────────────────────────────────────────

function love.load()
    love.graphics.setFont(Fonts.get(16))
    Audio.load()
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

function love.update(dt)
    flux.update(dt)
    if currentScene == "home" then
        Home.update(dt)
    elseif currentScene == "match" then
        Match.update(dt)
    end
end

function love.draw()
    love.graphics.clear(Theme.ink[1], Theme.ink[2], Theme.ink[3], 1)
    love.graphics.push()
    love.graphics.translate(math.floor(camera.x), math.floor(camera.y))
    if currentScene == "home" then
        Home.draw()
    elseif currentScene == "match" then
        Match.draw()
    end
    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    local cx = x - math.floor(camera.x)
    local cy = y - math.floor(camera.y)
    if currentScene == "home" then
        onHome(Home.mousepressed(cx, cy, button))
    elseif currentScene == "match" then
        onMatch(Match.mousepressed(cx, cy, button))
    end
end

function love.mousemoved(x, y)
    local cx = x - math.floor(camera.x)
    local cy = y - math.floor(camera.y)
    if currentScene == "home" then
        Home.mousemoved(cx, cy)
    elseif currentScene == "match" then
        Match.mousemoved(cx, cy)
    end
end

function love.wheelmoved(x, y)
    if currentScene == "home" then Home.wheelmoved(x, y)
    elseif currentScene == "match" then Match.wheelmoved(x, y) end
end

function love.keypressed(key)
    if currentScene == "home" then
        onHome(Home.keypressed(key))
    elseif currentScene == "match" then
        onMatch(Match.keypressed(key))
    end
end
