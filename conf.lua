function love.conf(t)
    t.window.title   = "Football TCG"
    t.window.width   = 1280
    t.window.height  = 800
    t.window.highdpi = true
    t.window.msaa    = 8      -- anti-alias shape edges (rotated hand cards, rounded corners, badges)
    t.window.resizable = false
    t.version = "11.4"
end
