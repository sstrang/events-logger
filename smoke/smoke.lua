-- Factorio 2.1 API stub harness for events-logger smoke test
-- Loads control.lua + logger.lua and every event module in a shared mod
-- environment, then fires each registered handler with representative
-- EventData fakes and captures helpers.write_file / log output.
--
-- Usage: lua5.3 smoke/smoke.lua [repo-path]

local REPO = arg[1] or "/home/scott/projects/events-logger"
local OUT = "/tmp/el-smoke"

local captured_json = {}
local captured_log = {}
local failures = {}
local passes = 0

local function fail(msg)
    failures[#failures + 1] = msg
    print("  FAIL: " .. msg)
end

local function pass(name)
    passes = passes + 1
end

-- ---------------------------------------------------------------------------
-- minimal stand-in for helpers.table_to_json (shape-compatible, valid JSON
-- for the value types this mod emits)
-- ---------------------------------------------------------------------------
local function json_enc(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif v == nil then
        return "null"
    elseif t == "table" then
        local n = #v
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = json_enc(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local ks = {}
        for k in pairs(v) do ks[#ks + 1] = k end
        table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(ks) do
            parts[#parts + 1] = tostring(k) .. ":" .. json_enc(v[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        error("cannot encode type " .. t)
    end
end

-- ---------------------------------------------------------------------------
-- shared mod environment (Factorio gives one env per mod; globals flow
-- between required files)
-- ---------------------------------------------------------------------------
local interfaces = {}
local registered_libs = {}

local settings_global = {
    ["event-logger-enable-json-logging"] = { value = true },
    ["event-logger-enable-factorio-logging"] = { value = true },
}

local players_by_index = {
    [1] = { index = 1, name = "scott", online_time = 900000 },
    [2] = { index = 2, name = "wingman", online_time = 432000 },
}

local GAME = {
    tick = 123456,
    tick_paused = false,
    ticks_to_run = 60,
    players = { [1] = players_by_index[1], [2] = players_by_index[2] },
    surfaces = { ["nauvis"] = { name = "nauvis", index = 1 } },
    forces = {
        ["enemy"] = {
            get_evolution_factor = function(surface)
                assert(type(surface) == "string", "get_evolution_factor expected surface name")
                return 0.431
            end,
        },
    },
    get_player = function(i) return players_by_index[i] end,
}

local G = {
    defines = {
        events = {
            on_research_started = 30, on_research_finished = 31, on_research_cancelled = 32,
            on_post_entity_died = 40, on_entity_died = 41, on_built_entity = 42,
            on_cargo_pod_finished_ascending = 50, on_rocket_launch_ordered = 51, on_rocket_launched = 52,
            on_pre_player_died = 60, on_player_left_game = 61, on_player_joined_game = 62,
            on_player_banned = 63, on_player_unbanned = 64, on_character_corpse_expired = 65,
            on_picked_up_item = 66, on_player_repaired_entity = 67,
            on_achievement_gained = 70, on_trigger_fired_artillery = 71,
            on_console_chat = 72,
        },
        inventory = { cargo_unit = 52 },
        disconnect_reason = {
            quit = 0, dropped = 1, reconnect = 2, wrong_input = 3, desync_limit_reached = 4,
            cannot_keep_up = 5, afk = 6, kicked = 7, kicked_and_deleted = 8, banned = 9,
            switching_servers = 10,
        },
    },
    remote = {
        add_interface = function(name, tbl)
            interfaces[name] = tbl
        end,
    },
    log = function(msg) captured_log[#captured_log + 1] = msg end,
    settings = { global = settings_global },
    helpers = {
        write_file = function(path, data, append)
            captured_json[#captured_json + 1] = data
        end,
        table_to_json = json_enc,
    },
    game = GAME,
    storage = {},
}
setmetatable(G, { __index = _G })

local function fake_require(name)
    if name == "event_handler" then
        return {
            add_lib = function(lib)
                registered_libs[#registered_libs + 1] = lib
            end,
        }
    end
    local path = REPO .. "/" .. name:gsub("%.", "/") .. ".lua"
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local src = f:read("*a")
    f:close()
    local chunk = assert(load(src, "@" .. path, "t", G))
    local ok, result = pcall(chunk)
    if not ok then error("require(" .. name .. ") failed: " .. tostring(result)) end
    return result
end
G.require = fake_require

-- ---------------------------------------------------------------------------
-- load the mod (control.lua pulls in logger via event_handler)
-- ---------------------------------------------------------------------------
print("== loading control.lua ==")
local f = assert(io.open(REPO .. "/control.lua", "r"))
local src = f:read("*a")
f:close()
local chunk = assert(load(src, "@control.lua", "t", G))
local ok, err = pcall(chunk)
if not ok then
    fail("control.lua load: " .. tostring(err))
    os.exit(1)
end
pass("control.lua loaded")

if not registered_libs[1] then
    fail("logger lib not registered with event_handler")
    os.exit(1)
end
local logging = registered_libs[1]

-- simulate on_init
print("== on_init ==")
ok, err = pcall(logging.on_init)
if ok then pass("logger.on_init (storage.playerstats initialized)")
else fail("logger.on_init: " .. tostring(err)) end
if type(G.storage.playerstats) ~= "table" then
    fail("storage.playerstats missing after on_init")
end

local handlers = logging.events
local expected_handlers = {
    "on_research_started", "on_research_finished", "on_research_cancelled",
    "on_post_entity_died", "on_entity_died", "on_built_entity",
    "on_cargo_pod_finished_ascending", "on_rocket_launch_ordered", "on_rocket_launched",
    "on_pre_player_died", "on_player_left_game", "on_player_joined_game",
    "on_player_banned", "on_player_unbanned", "on_character_corpse_expired",
    "on_picked_up_item", "on_player_repaired_entity",
    "on_achievement_gained", "on_trigger_fired_artillery",
    "on_console_chat",
}
for _, evname in ipairs(expected_handlers) do
    if handlers[G.defines.events[evname]] then pass("handler registered: " .. evname)
    else fail("handler NOT registered: " .. evname) end
end

-- ---------------------------------------------------------------------------
-- fire handlers with fake EventData
-- ---------------------------------------------------------------------------
local function fire(evname, fake)
    local fn = handlers[G.defines.events[evname]]
    if not fn then fail("no handler for " .. evname) return end
    local ok2, err2 = pcall(fn, fake)
    if ok2 then pass(evname .. " (" .. tostring(fake.case or "") .. ")")
    else fail(evname .. " (" .. tostring(fake.case or "") .. "): " .. tostring(err2)) end
end

print("== firing event handlers ==")

-- research: new 2.1-commit code path (science packs), both ingredient forms
fire("on_research_started", {
    case = "mixed ingredient forms",
    tick = 100,
    research = {
        name = "mining-productivity-4", level = 14,
        research_unit_ingredients = {
            { name = "automation-science-pack", amount = 1 },
            { name = "logistic-science-pack", amount = 1 },
            { name = "chemical-science-pack", amount = 1 },
            { "production-science-pack", 2 },  -- positional form (mods)
        },
    },
})
fire("on_research_started", {
    case = "no ingredients field",
    tick = 110,
    research = { name = "artillery", level = 1 },
})
fire("on_research_finished", {
    case = "infinite tech",
    tick = 200,
    research = { name = "stronger-explosives-2", level = 2 },
})
fire("on_research_cancelled", {
    case = "basic",
    tick = 210,
    research = { name = "mining-productivity-4", level = 3 },
})

fire("on_post_entity_died", {
    case = "quality+force",
    tick = 300, name = 40,
    damage_type = { name = "impact" },
    quality = { name = "uncommon", type = "quality", color = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 }, level = 1 },
    force = { name = "enemy" },
})
fire("on_post_entity_died", { case = "no quality/force/damage", tick = 305, name = 40 })
fire("on_entity_died", {
    case = "entity+cause+force",
    tick = 310, name = 41,
    damage_type = { name = "physical" },
    entity = { name = "behemoth-biter", type = "unit", force = { name = "enemy" }, position = { x = 10.5, y = -3.25 } },
    force = { name = "enemy" },
    cause = { name = "character", type = "character" },
})
fire("on_entity_died", {
    case = "ambient, no cause",
    tick = 315, name = 41,
    entity = { name = "small-biter", type = "unit", force = { name = "enemy" }, position = { x = 1, y = 1 } },
})
fire("on_built_entity", {
    case = "first build by player",
    tick = 400, name = 42, player_index = 1,
    entity = { type = "assembling-machine" },
})
fire("on_built_entity", {
    case = "second build increments stats",
    tick = 410, name = 42, player_index = 1,
    entity = { type = "inserter" },
})

fire("on_cargo_pod_finished_ascending", {
    case = "with player + inventory",
    tick = 500, launched_by_rocket = true, player_index = 1,
    cargo_pod = {
        name = "cargo-pod", position = { x = 1.5, y = 2.5 },
        get_inventory = function(inv)
            assert(inv == G.defines.inventory.cargo_unit, "wrong inventory define")
            return { get_contents = function()
                return { { name = "space-science-pack", count = 200, quality = "normal" } } end }
        end,
    },
})
fire("on_cargo_pod_finished_ascending", {
    case = "no player, empty inventory",
    tick = 505, launched_by_rocket = false,
    cargo_pod = {
        name = "cargo-pod", position = { x = 1.5, y = 2.5 },
        get_inventory = function(inv)
            assert(inv == G.defines.inventory.cargo_unit, "wrong inventory define")
            return { get_contents = function() return {} end }
        end,
    },
})
fire("on_rocket_launch_ordered", {
    case = "by player",
    tick = 510, player_index = 1,
    rocket_silo = { name = "rocket-silo", position = { x = 0.5, y = 0.5 } },
})
fire("on_rocket_launched", {
    case = "with silo",
    tick = 520,
    rocket_silo = { name = "rocket-silo", position = { x = 0.5, y = 0.5 } },
})
fire("on_rocket_launched", {
    case = "no silo (nil rocket_silo must not crash factorio_log)",
    tick = 525,
    rocket_silo = nil,
})

fire("on_pre_player_died", { case = "ambient death", tick = 600, player_index = 2 })
fire("on_pre_player_died", { case = "PvE death", tick = 605, player_index = 2,
    cause = { name = "behemoth-biter", type = "unit" } })
fire("on_pre_player_died", { case = "PvP death", tick = 610, player_index = 2,
    cause = { type = "character", player = { index = 1 } } })

fire("on_player_left_game", { case = "quit", tick = 700, player_index = 2, reason = G.defines.disconnect_reason.quit })
fire("on_player_joined_game", { case = "join", tick = 800, player_index = 2 })
fire("on_player_banned", { case = "ban", tick = 810, player_name = "griefer", reason = "spamming", by_player = "admin" })
fire("on_player_unbanned", { case = "unban", tick = 815, player_name = "griefer", reason = "", by_player = "admin" })
fire("on_character_corpse_expired", {
    case = "corpse",
    tick = 900,
    corpse = { type = "character-corpse", name = "character-corpse", position = { x = 3, y = 4 } },
})
fire("on_picked_up_item", { case = "pickup", tick = 910, name = 66, player_index = 1,
    item_stack = { name = "iron-plate", count = 50 } })
fire("on_player_repaired_entity", { case = "repair", tick = 920, name = 67, player_index = 1,
    entity = { name = "stone-furnace", type = "furnace" } })
fire("on_achievement_gained", { case = "achievement", tick = 930, name = 70, player_index = 1,
    achievement = { name = "steam-all-the-way" } })
fire("on_trigger_fired_artillery", { case = "artillery", tick = 940,
    entity = { name = "artillery-turret" }, source = { name = "artillery-turret" } })

fire("on_console_chat", { case = "player chat", tick = 950, player_index = 1, message = "hello world" })
fire("on_console_chat", { case = "server console (nil player_index)", tick = 955, player_index = nil, message = "/command ran" })

-- ---------------------------------------------------------------------------
-- nth-tick paths
-- ---------------------------------------------------------------------------
print("== nth-tick paths ==")
ok, err = pcall(G.log_tick_over_time)
if ok then pass("log_tick_over_time") else fail("log_tick_over_time: " .. tostring(err)) end
ok, err = pcall(G.checkEvolution)
if ok then pass("checkEvolution") else fail("checkEvolution: " .. tostring(err)) end

local nkeys = 0
for _ in pairs(logging.on_nth_tick) do nkeys = nkeys + 1 end
if nkeys == 2 then pass("on_nth_tick has 2 distinct keys (no duplicate-key overwrite)")
else fail("on_nth_tick expected 2 distinct keys, got " .. nkeys) end

local before_json = #captured_json
ok, err = pcall(logging.on_nth_tick[60 * 60 * 10])
if ok then pass("10-min nth-tick (log_stats + checkEvolution)")
else fail("10-min nth-tick: " .. tostring(err)) end
ok, err = pcall(logging.on_nth_tick[60 * 60 * 10])
if ok then pass("10-min nth-tick idempotent second run")
else fail("10-min nth-tick second run: " .. tostring(err)) end
-- first run: scott has stats from on_built_entity (writes), wingman inits (writes),
-- plus one EVOLUTION line; second run: all deltas zero (only EVOLUTION line)
local wrote = #captured_json - before_json
if wrote == 4 then pass("nth-tick JSON volume as expected (3 stats/evolution + 1 evolution)")
else fail("nth-tick JSON volume: expected 4 lines, got " .. wrote) end

ok, err = pcall(G.on_console_chat, { tick = 999, player_index = 1, message = "hello" })
if ok then pass("on_console_chat callable and registered (CHAT events fire)")
else fail("on_console_chat: " .. tostring(err)) end

-- ---------------------------------------------------------------------------
-- remote interface
-- ---------------------------------------------------------------------------
print("== remote interface ==")
local ri = interfaces["events-logger"]
if not ri then fail("remote interface events-logger not registered")
else
    pass("remote interface registered")
    ok, err = pcall(ri.send_event, { event = "CUSTOM", tick = 1, data = { hello = "world" } })
    if ok then pass("send_event") else fail("send_event: " .. tostring(err)) end
    ok, err = pcall(ri.send_std_log, { event = "CUSTOM", message = "hi" })
    if ok then pass("send_std_log") else fail("send_std_log: " .. tostring(err)) end
    ok, err = pcall(ri.send_event, { tick = 1, data = {} })
    if not ok then pass("send_event rejects missing 'event' key") else fail("send_event accepted missing 'event' key") end
end

-- ---------------------------------------------------------------------------
-- dump artifacts + report
-- ---------------------------------------------------------------------------
os.execute("mkdir -p " .. OUT)
local jf = io.open(OUT .. "/game-events.jsonl", "w")
for _, line in ipairs(captured_json) do jf:write(line) end
jf:close()
local lf = io.open(OUT .. "/factorio-smoke.log", "w")
for _, line in ipairs(captured_log) do lf:write(line .. "\n") end
lf:close()

print(string.format("== summary: %d passed, %d failed, %d JSON lines, %d log lines ==",
    passes, #failures, #captured_json, #captured_log))
for _, msg in ipairs(failures) do print("  FAILED: " .. msg) end
os.exit(#failures == 0 and 0 or 1)
