local T    = require("tests.t")
local Draw = require("ui.kit.draw")

T.test("roundedRectPoints stays inside the rect and touches all four sides", function()
    local pts = Draw.roundedRectPoints(10, 20, 100, 50, 8, 4)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #pts, 2 do
        minX = math.min(minX, pts[i]);   maxX = math.max(maxX, pts[i])
        minY = math.min(minY, pts[i+1]); maxY = math.max(maxY, pts[i+1])
    end
    T.near(minX, 10); T.near(maxX, 110); T.near(minY, 20); T.near(maxY, 70)
    T.eq(#pts, 4 * (4 + 1) * 2, "4 corners x (seg+1) points x 2 coords")
end)

T.test("roundedRectPoints clamps radius to half the short side", function()
    local pts = Draw.roundedRectPoints(0, 0, 20, 10, 50, 2)
    for i = 1, #pts, 2 do
        T.ok(pts[i] >= -1e-9 and pts[i] <= 20 + 1e-9)
        T.ok(pts[i+1] >= -1e-9 and pts[i+1] <= 10 + 1e-9)
    end
end)

T.test("lerpColor mixes channels", function()
    local c = Draw.lerpColor({ 0, 0, 0, 1 }, { 1, 0.5, 0, 0 }, 0.5)
    T.near(c[1], 0.5); T.near(c[2], 0.25); T.near(c[3], 0); T.near(c[4], 0.5)
end)

T.test("gradientT runs 0..1 for vertical and diagonal", function()
    T.near(Draw.gradientT("v", 0, 0, 100, 50, 30, 0), 0)
    T.near(Draw.gradientT("v", 0, 0, 100, 50, 30, 50), 1)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 0, 0), 0)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 100, 50), 1)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 50, 25), 0.5)
end)

T.test("fitSize shrinks until text fits, never below min", function()
    local measure = function(size, text) return #text * size * 0.5 end
    T.eq(Draw.fitSize("ABCDEFGHIJ", 60, 16, 8, measure), 12)   -- 10*12*0.5 = 60
    T.eq(Draw.fitSize("ABCDEFGHIJ", 10, 16, 8, measure), 8)
    T.eq(Draw.fitSize("AB", 100, 16, 8, measure), 16)
end)

T.test("clipLine clips a diagonal to the rect", function()
    local x1, y1, x2, y2 = Draw.clipLine(-10, -10, 110, 110, 0, 0, 100, 100)
    T.near(x1, 0); T.near(y1, 0); T.near(x2, 100); T.near(y2, 100)
    T.eq(Draw.clipLine(200, 0, 300, 50, 0, 0, 100, 100), nil, "fully outside")
end)

T.test("clipLine clips a vertical segment to the rect", function()
    local x1, y1, x2, y2 = Draw.clipLine(50, -10, 50, 110, 0, 0, 100, 100)
    T.near(x1, 50); T.near(y1, 0); T.near(x2, 50); T.near(y2, 100)
end)

T.test("clipLine handles a zero-length point inside and outside the rect", function()
    local x1, y1, x2, y2 = Draw.clipLine(50, 50, 50, 50, 0, 0, 100, 100)
    T.near(x1, 50); T.near(y1, 50); T.near(x2, 50); T.near(y2, 50)
    T.eq(Draw.clipLine(200, 200, 200, 200, 0, 0, 100, 100), nil, "point outside rect")
end)

T.test("starPoints has 10 points, the first at the top tip", function()
    local p = Draw.starPoints(50, 60, 20)
    T.eq(#p, 20)
    T.near(p[1], 50); T.near(p[2], 40)
    T.near(math.sqrt((p[3] - 50) ^ 2 + (p[4] - 60) ^ 2), 9)   -- inner radius 0.45 r
end)
