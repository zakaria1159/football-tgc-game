-- Arcade drawing primitives. No scissor/stencil anywhere: rounded gradients and
-- cropped images are triangle-fan meshes, so everything works inside canvases
-- and under rotation transforms.
-- Animate size with love.graphics.scale/rotate rather than by passing changing
-- w/h — meshes are cached by (rounded) size.
-- alpha / alphaMul fades each layer separately, so stacked layers (border under
-- fill, shadow under text) show through at partial alpha; fade whole cards via
-- a canvas instead.
local Theme = require("ui.theme")
local Fonts = require("ui.fonts")

local Draw = {}

-- ── Pure helpers (unit-tested) ────────────────────────────────────────────────

-- Flat {x1,y1,x2,y2,...} outline of a rounded rect, clockwise from top-left arc.
function Draw.roundedRectPoints(x, y, w, h, r, seg)
    seg = seg or 6
    r = math.max(0, math.min(r, w / 2, h / 2))
    local pts = {}
    local corners = {
        { x + w - r, y + r,     -math.pi / 2 },   -- top-right
        { x + w - r, y + h - r, 0 },              -- bottom-right
        { x + r,     y + h - r, math.pi / 2 },    -- bottom-left
        { x + r,     y + r,     math.pi },        -- top-left
    }
    for _, c in ipairs(corners) do
        for i = 0, seg do
            local a = c[3] + (math.pi / 2) * (i / seg)
            pts[#pts + 1] = c[1] + math.cos(a) * r
            pts[#pts + 1] = c[2] + math.sin(a) * r
        end
    end
    return pts
end

function Draw.lerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    }
end

-- Gradient parameter at point (px,py) inside rect: "v" top→bottom, "d" top-left→bottom-right.
function Draw.gradientT(dir, x, y, w, h, px, py)
    if dir == "d" then
        return math.max(0, math.min(1, ((px - x) / w + (py - y) / h) / 2))
    end
    return math.max(0, math.min(1, (py - y) / h))
end

-- Largest integer size in [minSize, size] where measure(size, text) <= maxW.
function Draw.fitSize(text, maxW, size, minSize, measure)
    size = math.floor(size)
    while size > minSize and measure(size, text) > maxW do size = size - 1 end
    return math.max(size, minSize)
end

-- Liang–Barsky: clip segment to rect; returns clipped coords or nil if outside.
function Draw.clipLine(x1, y1, x2, y2, rx, ry, rw, rh)
    local dx, dy = x2 - x1, y2 - y1
    local t0, t1 = 0, 1
    local p = { -dx, dx, -dy, dy }
    local q = { x1 - rx, rx + rw - x1, y1 - ry, ry + rh - y1 }
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then return nil end
        else
            local t = q[i] / p[i]
            if p[i] < 0 then
                if t > t1 then return nil end
                if t > t0 then t0 = t end
            else
                if t < t0 then return nil end
                if t < t1 then t1 = t end
            end
        end
    end
    return x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy
end

-- ── Color / mesh helpers ──────────────────────────────────────────────────────

function Draw.setColor(c, alphaMul)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alphaMul or 1))
end

local function isGradient(fill) return type(fill[1]) == "table" end

local _meshCache, _meshCount = {}, 0

-- Filled rounded rect with a gradient (or flat) fill; optional image = cover-cropped texture.
local function roundedMesh(x, y, w, h, r, c1, c2, dir, image)
    w = math.floor(w + 0.5)
    h = math.floor(h + 0.5)
    r = math.floor(r + 0.5)
    if w <= 0 or h <= 0 then return end
    local key = table.concat({ w, h, r, dir or "v",
        c1[1], c1[2], c1[3], c1[4] or 1, c2[1], c2[2], c2[3], c2[4] or 1,
        image and tostring(image) or "-" }, "|")
    local mesh = _meshCache[key]
    if not mesh then
        local pts = Draw.roundedRectPoints(0, 0, w, h, r, 6)
        local iw, ih = 1, 1
        local u0, v0, us, vs = 0, 0, 1, 1
        if image then
            iw, ih = image:getDimensions()
            local scale = math.max(w / iw, h / ih)       -- cover
            us, vs = w / (iw * scale), h / (ih * scale)
            u0, v0 = (1 - us) / 2, (1 - vs) / 2
        end
        local function vert(px, py)
            local c = Draw.lerpColor(c1, c2, Draw.gradientT(dir, 0, 0, w, h, px, py))
            return { px, py, u0 + (px / w) * us, v0 + (py / h) * vs, c[1], c[2], c[3], c[4] }
        end
        local verts = { vert(w / 2, h / 2) }
        for i = 1, #pts, 2 do verts[#verts + 1] = vert(pts[i], pts[i + 1]) end
        verts[#verts + 1] = vert(pts[1], pts[2])
        mesh = love.graphics.newMesh(verts, "fan", "static")
        if image then mesh:setTexture(image) end
        if _meshCount > 600 then
            for _, m in pairs(_meshCache) do m:release() end
            _meshCache, _meshCount = {}, 0
        end
        _meshCache[key] = mesh
        _meshCount = _meshCount + 1
    end
    love.graphics.draw(mesh, x, y)
end

-- fill: a color {r,g,b,a} or a gradient {c1, c2}. dir: "v" (default) or "d".
function Draw.roundedFill(x, y, w, h, r, fill, dir, alphaMul)
    alphaMul = alphaMul or 1
    if isGradient(fill) then
        love.graphics.setColor(1, 1, 1, alphaMul)
        roundedMesh(x, y, w, h, r, fill[1], fill[2], dir)
    else
        Draw.setColor(fill, alphaMul)
        love.graphics.rectangle("fill", x, y, w, h, r, r, 8)
    end
end

-- Image cover-cropped into a rounded rect.
function Draw.roundedImage(image, x, y, w, h, r, alphaMul)
    love.graphics.setColor(1, 1, 1, alphaMul or 1)
    roundedMesh(x, y, w, h, r, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, "v", image)
end

-- True when the fill (flat color or gradient) has any alpha < 1, so a full-rect
-- border drawn under it would show through as a muddy overlap instead of a crisp edge.
local function isTranslucentFill(fill)
    if not fill then return false end
    if isGradient(fill) then
        return (fill[1][4] or 1) < 1 or (fill[2][4] or 1) < 1
    end
    return (fill[4] or 1) < 1
end

-- ── Sticker (the core arcade shape) ───────────────────────────────────────────
-- opts: r, fill (color|gradient), dir, border (px), borderColor, shadow (px), shadowColor, alpha
function Draw.sticker(x, y, w, h, opts)
    opts = opts or {}
    local r      = opts.r or 12
    local b      = opts.border or 4
    local sh     = opts.shadow or 5
    local a      = opts.alpha or 1
    if sh > 0 then
        Draw.setColor(opts.shadowColor or Theme.ink, a)
        love.graphics.rectangle("fill", x, y + sh, w, h, r, r, 8)
    end
    local translucent = b > 0 and isTranslucentFill(opts.fill)
    if b > 0 and not translucent then
        Draw.setColor(opts.borderColor or Theme.white, a)
        love.graphics.rectangle("fill", x, y, w, h, r, r, 8)
    end
    Draw.roundedFill(x + b, y + b, w - 2 * b, h - 2 * b, math.max(0, r - b),
        opts.fill or Theme.white, opts.dir, a)
    if translucent then
        Draw.setColor(opts.borderColor or Theme.white, a)
        love.graphics.setLineWidth(b)
        love.graphics.rectangle("line", x + b / 2, y + b / 2, w - b, h - b, r - b / 2, r - b / 2, 8)
        love.graphics.setLineWidth(1)
    end
end

-- Glow rings around a rounded rect (selection, rarity, targets).
function Draw.glow(x, y, w, h, r, color, strength, alphaMul)
    strength = strength or 1
    local a = alphaMul or 1
    for i = 3, 1, -1 do
        Draw.setColor(color, 0.16 * i * strength * a)
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", x - i * 2, y - i * 2, w + i * 4, h + i * 4, r + i * 2, r + i * 2, 8)
    end
    love.graphics.setLineWidth(1)
end

function Draw.ring(x, y, w, h, r, color, width, alphaMul)
    Draw.setColor(color, alphaMul)
    love.graphics.setLineWidth(width or 4)
    love.graphics.rectangle("line", x, y, w, h, r, r, 8)
    love.graphics.setLineWidth(1)
end

-- ── Text ──────────────────────────────────────────────────────────────────────

local function measureDisplay(size, text) return Fonts.get(size):getWidth(text) end
local function measureBody(size, text) return Fonts.body(size):getWidth(text) end

-- Text with a hard drop shadow (and optional outline). Auto-shrinks to fit w when opts.fit.
-- opts: size, color, shadowColor, shadowY, outline (px), outlineColor, body (bool), fit (bool), minSize
function Draw.text(text, x, y, w, align, opts)
    opts = opts or {}
    local size = opts.size or 16
    if opts.fit then
        size = Draw.fitSize(text, w, size, opts.minSize or 7, opts.body and measureBody or measureDisplay)
    end
    local font = opts.body and Fonts.body(size) or Fonts.get(size)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    local a = opts.alpha or 1
    local o = opts.outline or 0
    if o > 0 then
        Draw.setColor(opts.outlineColor or Theme.ink, a)
        for ox = -o, o, o do
            for oy = -o, o, o do
                if ox ~= 0 or oy ~= 0 then love.graphics.printf(text, x + ox, y + oy, w, align) end
            end
        end
    end
    local sy = opts.shadowY or 0
    if sy > 0 then
        Draw.setColor(opts.shadowColor or Theme.ink, a)
        love.graphics.printf(text, x, y + sy, w, align)
    end
    Draw.setColor(opts.color or Theme.white, a)
    love.graphics.printf(text, x, y, w, align)
    love.graphics.setFont(prev)
    return size, font
end

-- ── Pills, badges, ribbons ────────────────────────────────────────────────────

-- Pill with centered text. opts: fill, textColor, size, border, shadow, body, alpha
function Draw.pill(x, y, w, h, text, opts)
    opts = opts or {}
    Draw.sticker(x, y, w, h, {
        r = h / 2, fill = opts.fill or Theme.white, border = opts.border or 2,
        shadow = opts.shadow or 3, alpha = opts.alpha, dir = "v",
    })
    local size = opts.size or math.floor(h * 0.62)
    Draw.text(text, x + h * 0.3, y + (h - size) / 2 - size * 0.08, w - h * 0.6, "center", {
        size = size, color = opts.textColor or Theme.inkText, body = opts.body, fit = true,
        minSize = 6, alpha = opts.alpha,
    })
end

-- Shield outline points (flat top, pointed bottom) centered at cx,cy.
local function shieldPoints(cx, cy, s)
    local hw, top, mid, bot = s * 0.5, cy - s * 0.5, cy + s * 0.12, cy + s * 0.55
    return {
        cx - hw, top, cx + hw, top, cx + hw, mid,
        cx + hw * 0.55, cy + s * 0.38, cx, bot, cx - hw * 0.55, cy + s * 0.38, cx - hw, mid,
    }
end

-- maxW: widest the number may be (circle interiors are narrower than shields).
local function badgeNumber(value, cx, cy, s, alpha, maxW)
    local str = tostring(value)
    local size = Draw.fitSize(str, maxW or s * 0.86, s * 0.40, 6, measureDisplay)
    Draw.text(str, cx - s, cy - size * 0.58, s * 2, "center", {
        size = size, color = Theme.white, shadowY = math.max(1, math.floor(s * 0.05)), alpha = alpha,
    })
end

-- Red ATK circle. s = diameter.
function Draw.atkBadge(cx, cy, s, value, alpha)
    alpha = alpha or 1
    local r = s / 2
    local sh = math.max(2, s * 0.08)
    Draw.setColor(Theme.ink, alpha);  love.graphics.circle("fill", cx, cy + sh, r, 24)
    Draw.setColor(Theme.white, alpha); love.graphics.circle("fill", cx, cy, r, 24)
    local b = math.max(2, s * 0.08)
    Draw.setColor(Theme.grad.atk[2], alpha); love.graphics.circle("fill", cx, cy, r - b, 24)
    Draw.setColor(Theme.grad.atk[1], alpha); love.graphics.circle("fill", cx, cy - (r - b) * 0.18, (r - b) * 0.82, 24)
    badgeNumber(value, cx, cy, s, alpha, s * 0.72)
end

-- Blue DEF shield. s = width. bonus > 0 adds a green "+N" tag above it.
function Draw.defBadge(cx, cy, s, value, bonus, alpha)
    alpha = alpha or 1
    local sh = math.max(2, s * 0.08)
    local b  = math.max(2, s * 0.08)
    love.graphics.push()
    love.graphics.translate(0, sh)
    Draw.setColor(Theme.ink, alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    love.graphics.pop()
    Draw.setColor(Theme.white, alpha);       love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    Draw.setColor(Theme.grad.def[2], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s))
    Draw.setColor(Theme.grad.def[1], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy - s * 0.08, s * 0.8))
    badgeNumber(value, cx, cy, s, alpha)
    if bonus and bonus > 0 then
        local tw, th = s * 1.1, s * 0.42
        Draw.pill(cx - tw / 2, cy - s * 0.5 - th - 2, tw, th, "+" .. bonus, {
            fill = Theme.grad.bonus, textColor = Theme.white, border = 2, shadow = 2, alpha = alpha,
        })
    end
end

-- Green "+N" ATK bonus tag (for strikers boosted by a midfielder).
function Draw.bonusTag(cx, bottomY, s, bonus, alpha)
    local tw, th = s * 1.1, s * 0.42
    Draw.pill(cx - tw / 2, bottomY - th, tw, th, "+" .. bonus, {
        fill = Theme.grad.bonus, textColor = Theme.white, border = 2, shadow = 2, alpha = alpha,
    })
end

-- Banner ribbon centered on cx. opts: fill, textColor, size, alpha
function Draw.ribbon(cx, y, w, h, text, opts)
    opts = opts or {}
    local x = cx - w / 2
    local a = opts.alpha or 1
    Draw.sticker(x, y, w, h, { r = h * 0.2, fill = opts.fill or Theme.white, border = 3, shadow = 4, alpha = a })
    local size = opts.size or math.floor(h * 0.6)
    Draw.text(text, x + 8, y + (h - size) / 2 - size * 0.08, w - 16, "center", {
        size = size, color = opts.textColor or Theme.inkText, fit = true, alpha = a,
        shadowY = opts.textShadow and 2 or 0,
    })
end

-- Diagonal stripes clipped to a rect (used for card backs and placeholders).
function Draw.stripes(x, y, w, h, spacing, width, color, alphaMul)
    if spacing <= 0 then return end
    Draw.setColor(color, alphaMul)
    love.graphics.setLineWidth(width)
    for o = -h, w, spacing do
        local x1, y1, x2, y2 = Draw.clipLine(x + o, y, x + o + h, y + h, x, y, w, h)
        if x1 then love.graphics.line(x1, y1, x2, y2) end
    end
    love.graphics.setLineWidth(1)
end

-- Full-screen vertical gradient background.
local _bgMesh
function Draw.background(W, H)
    if not _bgMesh then
        local t, b = Theme.bg.top, Theme.bg.bottom
        _bgMesh = love.graphics.newMesh({
            { 0, 0, 0, 0, t[1], t[2], t[3], 1 }, { W, 0, 1, 0, t[1], t[2], t[3], 1 },
            { W, H, 1, 1, b[1], b[2], b[3], 1 }, { 0, H, 0, 1, b[1], b[2], b[3], 1 },
        }, "fan", "static")
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(_bgMesh)
end

-- Five-point star outline {x1,y1,...}, first point at the top tip. Pure (unit-tested).
function Draw.starPoints(cx, cy, r)
    local p = {}
    for i = 0, 9 do
        local a = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and r or r * 0.45
        p[#p + 1] = cx + math.cos(a) * rad
        p[#p + 1] = cy + math.sin(a) * rad
    end
    return p
end

-- Star is concave: fill it as a fan of triangles around its centre.
local function fillStar(cx, cy, r)
    local p = Draw.starPoints(cx, cy, r)
    for i = 1, #p, 2 do
        local nx = i + 2
        if nx > #p then nx = 1 end
        love.graphics.polygon("fill", cx, cy, p[i], p[i + 1], p[nx], p[nx + 1])
    end
end

-- Star with white outline + ink drop shadow (midfield crown, summons bonus).
function Draw.star(cx, cy, r, color, alphaMul)
    local sh = math.max(1, math.floor(r * 0.15))
    Draw.setColor(Theme.ink, alphaMul);   fillStar(cx, cy + sh, r + 2)
    Draw.setColor(Theme.white, alphaMul); fillStar(cx, cy, r + 2)
    Draw.setColor(color or Theme.highlight.selected, alphaMul); fillStar(cx, cy, r)
end

-- ── Menus & overlays ──────────────────────────────────────────────────────────

-- n-spike burst outline {x1,y1,...}: alternating outer/inner radius, first point at
-- angle rot (default: straight up). Pure (unit-tested).
function Draw.burstPoints(cx, cy, rOuter, rInner, n, rot)
    rot = rot or -math.pi / 2
    local p = {}
    for i = 0, n * 2 - 1 do
        local a = rot + i * math.pi / n
        local rad = (i % 2 == 0) and rOuter or rInner
        p[#p + 1] = cx + math.cos(a) * rad
        p[#p + 1] = cy + math.sin(a) * rad
    end
    return p
end

-- Concave outline filled as a fan of triangles around (cx, cy).
local function fillFan(cx, cy, p)
    for i = 1, #p, 2 do
        local nx = i + 2
        if nx > #p then nx = 1 end
        love.graphics.polygon("fill", cx, cy, p[i], p[i + 1], p[nx], p[nx + 1])
    end
end

-- Starburst ("CLASH!") with a white rim and a hard ink shadow; rot spins it.
function Draw.burst(cx, cy, rOuter, rInner, n, color, alphaMul, rot)
    local sh = math.max(2, math.floor(rOuter * 0.06))
    Draw.setColor(Theme.ink, alphaMul)
    fillFan(cx, cy + sh, Draw.burstPoints(cx, cy + sh, rOuter + 5, rInner + 5, n, rot))
    Draw.setColor(Theme.white, alphaMul)
    fillFan(cx, cy, Draw.burstPoints(cx, cy, rOuter + 5, rInner + 5, n, rot))
    Draw.setColor(color or Theme.highlight.selected, alphaMul)
    fillFan(cx, cy, Draw.burstPoints(cx, cy, rOuter, rInner, n, rot))
end

-- Solid triangle arrow (the fonts have no ▶ / ◀). dir: 1 = right, -1 = left.
function Draw.arrow(cx, cy, size, dir, color, alphaMul)
    local h = size / 2
    Draw.setColor(color or Theme.white, alphaMul)
    love.graphics.polygon("fill", cx - dir * h * 0.8, cy - h, cx + dir * h, cy, cx - dir * h * 0.8, cy + h)
end

-- ✕ glyph (the fonts have none): two thick strokes.
function Draw.cross(cx, cy, size, color, width, alphaMul)
    local h = size / 2
    Draw.setColor(color or Theme.white, alphaMul)
    love.graphics.setLineWidth(width or math.max(3, size * 0.22))
    love.graphics.line(cx - h, cy - h, cx + h, cy + h)
    love.graphics.line(cx - h, cy + h, cx + h, cy - h)
    love.graphics.setLineWidth(1)
end

-- "CLICK OR SPACE ▶" style hint pill centred on cx; the arrow is drawn, not typed.
function Draw.hintPill(cx, y, text, alpha)
    local size, h = 18, 34
    local w = Fonts.get(size):getWidth(text) + 64
    local x = cx - w / 2
    Draw.sticker(x, y, w, h, { r = h / 2, fill = Theme.white, border = 2, shadow = 3, alpha = alpha })
    Draw.text(text, x + 18, y + (h - size) / 2 - 2, w - 58, "center", {
        size = size, color = Theme.inkText, alpha = alpha,
    })
    Draw.arrow(x + w - 24, y + h / 2, 14, 1, Theme.inkText, alpha)
end

return Draw
