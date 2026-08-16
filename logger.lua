events = {}
require("el_helpers")
require("custom_events.evolution")
require("custom_events.system")
require("events.achievements")
require("events.entities")
require("events.players")
require("events.research")
require("events.rockets")
require("events.weapons")

local function on_init ()
    storage.playerstats = {}
end

local logging = {
    write_game_event_json = write_game_event_json,
    factorio_log = factorio_log,
}
logging.events = events

logging.on_nth_tick = {
    [60 * 60 * 10] = function()
        -- every 10 minutes
        log_stats()
        checkEvolution()
    end,
    [60 * 60] = log_tick_over_time,
}

logging.on_init = on_init

return logging
