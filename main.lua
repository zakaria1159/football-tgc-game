-- Football TCG — main.lua
math.randomseed(os.time())

local flux      = require("lib.flux")
local moonshine = require("lib.moonshine")
local Home      = require("scenes.home")
local Match     = require("scenes.match")
local GwentMatch = require("scenes.gwent_match")
local Store     = require("store.match")
local GwentStore = require("store.gwent")
local Decks     = require("data.presetDecks")
local Audio     = require("ui.audio")

local currentScene = "home"
local store        = Store.new()
local gwentStore   = GwentStore.new()
local fonts        = {}
local fxScene      = nil
local camera       = { x = 0, y = 0 }
Match._camera      = camera

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function startMatch(deckKey)
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

local function startGwentMatch(playerFaction, opponentFaction)
    gwentStore:startMatch(playerFaction, opponentFaction, "medium")
    GwentMatch.enter(gwentStore, "medium")
    Audio.playMusic("assets/audio/music/theme_match.ogg", 0.45)
    currentScene = "gwent_match"
end

-- ── Love2D callbacks ──────────────────────────────────────────────────────────

function love.load()
    local Fonts = require("ui.fonts")
    fonts.tiny   = Fonts.get(9)
    fonts.small  = Fonts.get(11)
    fonts.normal = Fonts.get(16)
    fonts.large  = Fonts.get(22)
    fonts.title  = Fonts.get(33)
    love.graphics.setFont(fonts.normal)
    fxScene = moonshine(moonshine.effects.vignette)
    fxScene.vignette.radius   = 0.85
    fxScene.vignette.opacity  = 0.28
    fxScene.vignette.softness = 0.50
    Audio.load()
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

function love.update(dt)
    flux.update(dt)
    if currentScene == "match" then
        Match.update(dt)
    elseif currentScene == "gwent_match" then
        GwentMatch.update(dt)
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(math.floor(camera.x), math.floor(camera.y))
    fxScene(function()
        love.graphics.clear(0.051, 0.008, 0.008, 1)
        if currentScene == "home" then
            Home.draw()
        elseif currentScene == "match" then
            Match.draw()
        elseif currentScene == "gwent_match" then
            GwentMatch.draw()
        end
    end)
    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    local cx = x - math.floor(camera.x)
    local cy = y - math.floor(camera.y)
    if currentScene == "home" then
        local action, mode, key = Home.mousepressed(cx, cy, button)
        if action == "start" then
            if mode == "gwent" then
                -- Opponent always uses the other faction
                local oppFaction = key == "northern_realms" and "monsters" or "northern_realms"
                startGwentMatch(key, oppFaction)
            else
                startMatch(key)
            end
        end
    elseif currentScene == "match" then
        local action = Match.mousepressed(cx, cy, button)
        if action == "home" then
            Home.reset(); currentScene = "home"
            Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
        end
    elseif currentScene == "gwent_match" then
        local action = GwentMatch.mousepressed(cx, cy, button)
        if action == "home" then
            Home.reset(); currentScene = "home"
            Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
        end
    end
end

function love.mousemoved(x, y)
    if currentScene == "match" then
        Match.mousemoved(x - math.floor(camera.x), y - math.floor(camera.y))
    end
end

function love.wheelmoved(x, y)
    if currentScene == "home" then Home.wheelmoved(x, y)
    elseif currentScene == "match" then Match.wheelmoved(x, y)
    elseif currentScene == "gwent_match" then GwentMatch.wheelmoved(x, y) end
end

function love.keypressed(key)
    if currentScene == "home" then
        local action, mode, deckKey = Home.keypressed(key)
        if action == "start" then
            if mode == "gwent" then
                local oppFaction = deckKey == "northern_realms" and "monsters" or "northern_realms"
                startGwentMatch(deckKey, oppFaction)
            else
                startMatch(deckKey)
            end
        end
    elseif currentScene == "match" then
        local action = Match.keypressed(key)
        if action == "home" or action == "restart" then
            Home.reset(); currentScene = "home"
            Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
        end
    elseif currentScene == "gwent_match" then
        local action = GwentMatch.keypressed(key)
        if action == "home" then
            Home.reset(); currentScene = "home"
            Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
        end
    end
end
