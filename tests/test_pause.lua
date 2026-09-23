local T     = require("tests.t")
local Pause = require("ui.menu.pause")

T.test("pause buttons sit centred inside the panel without overlapping", function()
    local P = Pause.PANEL
    local prev
    for i = 1, #Pause.ITEMS do
        local r = Pause.buttonRect(i)
        T.ok(r.x >= P.x and r.x + r.w <= P.x + P.w and r.y >= P.y and r.y + r.h <= P.y + P.h)
        T.near(r.x + r.w / 2, P.x + P.w / 2)
        if prev then T.ok(r.y >= prev.y + prev.h) end
        prev = r
    end
    T.near(P.x + P.w / 2, 640); T.near(P.y + P.h / 2, 400)
end)

T.test("actionAt maps button centres to actions", function()
    local want = { "resume", "library", "home" }
    for i = 1, 3 do
        local r = Pause.buttonRect(i)
        T.eq(Pause.actionAt(r.x + r.w / 2, r.y + r.h / 2), want[i])
    end
    T.eq(Pause.actionAt(10, 10), nil)
    T.eq(Pause.mousepressed(10, 10, 1), nil)
end)

T.test("keyboard: Esc resumes, arrows move focus (wrapping), Enter activates", function()
    Pause.open()
    T.eq(Pause.keypressed("escape"), "resume")
    T.eq(Pause.focus(), 1)
    Pause.keypressed("down"); T.eq(Pause.keypressed("return"), "library")
    Pause.keypressed("up"); Pause.keypressed("up"); T.eq(Pause.focus(), 3)
    T.eq(Pause.keypressed("kpenter"), "home")
end)
