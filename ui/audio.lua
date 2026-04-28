local Audio = {}

local _sfx        = {}
local _music      = nil
local _muted      = false
local _musicVol   = 0.45

-- ── Load ──────────────────────────────────────────────────────────────────────

function Audio.load()
    local function sfx(name, path)
        local ok, src = pcall(love.audio.newSource, path, "static")
        if ok then _sfx[name] = src end
    end
    sfx("card_summon",        "assets/audio/sfx/card_summon.ogg")
    sfx("card_play_strategy", "assets/audio/sfx/card_play_strategy.ogg")
    sfx("attack",             "assets/audio/sfx/attack.ogg")
    sfx("destroy",            "assets/audio/sfx/destroy.ogg")
end

-- ── SFX ───────────────────────────────────────────────────────────────────────

-- Clone before play so rapid calls don't cut each other off.
function Audio.play(name, volume)
    local s = _sfx[name]
    if not s then return end
    local c = s:clone()
    if volume then c:setVolume(volume) end
    love.audio.play(c)
end

-- ── Music ─────────────────────────────────────────────────────────────────────

function Audio.playMusic(path, volume)
    if _music then
        _music:stop()
        _music:release()
        _music = nil
    end
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok then return end
    _musicVol = volume or 0.45
    _music = src
    _music:setLooping(true)
    _music:setVolume(_muted and 0 or _musicVol)
    _music:play()
end

function Audio.toggleMute()
    _muted = not _muted
    if _music then
        _music:setVolume(_muted and 0 or _musicVol)
    end
end

function Audio.isMuted()
    return _muted
end

function Audio.stopMusic()
    if _music then
        _music:stop()
        _music:release()
        _music = nil
    end
end

return Audio
