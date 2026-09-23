local Fonts = require("ui.fonts")

local Character = {}

local imgs   = {}
local loaded = false

local state   = "thinking"
local timer   = 0
local bounceY = 0

local LOW_LP = 1200

local DURATION = {
    attacking = 5.0,
    worried   = 3.0,
}

local LABEL = {
    attacking = "ATTACKING!",
    thinking  = "THINKING...",
    worried   = "WORRIED!",
}

local COLOR = {
    attacking = { 1.00, 0.40, 0.15, 1 },
    thinking  = { 0.45, 0.75, 1.00, 1 },
    worried   = { 1.00, 0.82, 0.20, 1 },
}

local function load()
    if loaded then return end
    imgs.attacking = love.graphics.newImage("assets/characters/1_attacking.png")
    imgs.thinking  = love.graphics.newImage("assets/characters/1_thinking.png")
    imgs.worried   = love.graphics.newImage("assets/characters/1_worried.png")
    loaded = true
end

function Character.reset()
    load()
    state   = "thinking"
    timer   = 0
    bounceY = 0
end

-- Set a new expression. Ignores if already in that state with time remaining.
function Character.setState(s)
    if state == s and timer > 0 then return end
    state   = s
    timer   = DURATION[s] or 0
    bounceY = -14
end

function Character.update(dt, playerLP)
    -- Bounce decay
    if bounceY < 0 then
        bounceY = math.min(0, bounceY + dt * 90)
    end

    -- Timer countdown → return to idle
    if timer > 0 then
        timer = timer - dt
        if timer <= 0 then
            timer = 0
            state = (playerLP and playerLP < LOW_LP) and "worried" or "thinking"
        end
    else
        -- Passive LP check while idle
        if playerLP then
            if playerLP < LOW_LP and state == "thinking" then
                state   = "worried"
                bounceY = -8
            elseif playerLP >= LOW_LP and state == "worried" then
                state = "thinking"
            end
        end
    end
end

-- Draw portrait in the combat overlay margin.
-- side: "left" (player attacking) or "right" (player defending, mirrored).
-- overrideState: optional, forces a specific expression for this draw only.
function Character.drawSide(side, screenW, screenH, overrideState)
    if not loaded then return end
    local img = imgs[overrideState or state] or imgs.thinking
    if not img then return end

    local charW  = 420
    local iw, ih = img:getDimensions()
    local scale  = charW / iw
    local charH  = ih * scale
    local clipW  = 400
    local clipH  = math.min(charH, screenH * 0.65)
    local clipY  = screenH - clipH

    if side == "left" then
        love.graphics.setScissor(0, clipY, clipW, clipH)
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.draw(img, -40, screenH - charH, 0, scale, scale)
    else
        -- Mirror horizontally so the character faces the action
        love.graphics.setScissor(screenW - clipW, clipY, clipW, clipH)
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.draw(img, screenW + 40, screenH - charH, 0, -scale, scale)
    end
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

function Character.draw(screenW, screenH)
    if not loaded then return end

    local img = imgs[state] or imgs.thinking
    if not img then return end

    local charW  = 420
    local iw, ih = img:getDimensions()
    local scale  = charW / iw
    local charH  = ih * scale

    local clipW  = 400           -- wide enough to show the full arm
    local clipH  = math.min(charH, screenH * 0.65)
    local clipY  = screenH - clipH
    local imgX   = -40
    local imgY   = screenH - charH + bounceY

    love.graphics.setScissor(0, clipY, clipW, clipH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, imgX, imgY, 0, scale, scale)
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Arcade match UI ───────────────────────────────────────────────────────────
-- Source-pixel regions in the 1408×768 character art.
local FACE    = { x = 490, y = 60, size = 320 }   -- square around the face (round avatar)
local BODY_CX = 585                               -- horizontal centre of the body (portrait crop)

-- Bottom-left portrait: art scaled to height h and cropped (quad, no scissor) to width w.
local _quads = {}
-- stateOverride forces an expression for this draw only (match-end screen).
function Character.drawPortrait(x, y, w, h, stateOverride)
    if not loaded then return end
    local img = imgs[stateOverride or state] or imgs.thinking
    local iw, ih = img:getDimensions()
    local s = h / ih
    local srcW = math.min(iw, w / s)
    local srcX = math.max(0, math.min(iw - srcW, BODY_CX - srcW / 2))
    local key = math.floor(srcX) .. ":" .. math.floor(srcW) .. ":" .. iw
    local q = _quads[key]
    if not q then
        q = love.graphics.newQuad(srcX, 0, srcW, ih, iw, ih)
        _quads[key] = q
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, q, x, y + bounceY * 0.6, 0, s, s)
end

-- Round face avatar (top bar): textured unit-circle fan mesh, cached per image.
local _avatarMeshes = {}
function Character.drawAvatar(cx, cy, r)
    if not loaded then return end
    local img = imgs[state] or imgs.thinking
    local mesh = _avatarMeshes[img]
    if not mesh then
        local iw, ih = img:getDimensions()
        local fcx, fcy, fr = FACE.x + FACE.size / 2, FACE.y + FACE.size / 2, FACE.size / 2
        local verts = { { 0, 0, fcx / iw, fcy / ih, 1, 1, 1, 1 } }
        local seg = 40
        for i = 0, seg do
            local a = i / seg * math.pi * 2
            local ux, uy = math.cos(a), math.sin(a)
            verts[#verts + 1] = { ux, uy, (fcx + ux * fr) / iw, (fcy + uy * fr) / ih, 1, 1, 1, 1 }
        end
        mesh = love.graphics.newMesh(verts, "fan", "static")
        mesh:setTexture(img)
        _avatarMeshes[img] = mesh
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh, cx, cy, 0, r, r)
end

return Character
