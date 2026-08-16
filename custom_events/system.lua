function on_console_chat(event)
    local event_json = {}
    event_json["event"] = "CHAT"
    event_json["tick"] = event.tick
    if ( event.player_index ~= nul and event.player_index ~= '' ) then
        local player = game.get_player(event.player_index)
        event_json["name"] = player.name
        event_json["message"] = event.message
        write_game_event_json(event_json)
        factorio_log(event_json["event"], event_json["name"] .. ": " .. event_json["message"])
    else
        event_json["name"] = "Console"
        event_json["message"] = event.message
        write_game_event_json(event_json)
        factorio_log(event_json["event"], event_json["name"] .. ": " .. event_json["message"])
    end
end

function log_stats()
    local event_json = {}
    event_json["event"] = "STATS"
    -- log built entities and playtime of players
    for _, p in pairs(game.players)
    do
        event_json["name"] = p.name
        local pdat = storage.playerstats[event_json["name"]]
        if (pdat == nil) then
            -- format of array: {entities placed, ticks played}
            event_json["stats"] = {
                ["online_time"] = p.online_time
            }
            write_game_event_json(event_json)
            factorio_log(event_json["event"], event_json["name"] .. " " .. 0 .. " " .. event_json["stats"]["online_time"])
            storage.playerstats[event_json["name"]] = { 0, event_json["stats"]["online_time"] }
        else
            event_json["stats"] = {
                ["online_time"] = p.online_time,
                [pdat[1]] = (p.online_time - pdat[2])
            }
            if (pdat[1] ~= 0 or (p.online_time - pdat[2]) ~= 0) then
                write_game_event_json(event_json)
                factorio_log(event_json["event"], event_json["name"] .. " " .. pdat[1] .. " " .. event_json["stats"][pdat[1]])
            end
            -- update the data
            storage.playerstats[event_json["name"]] = { 0, p.online_time }
        end
    end
end

function log_tick_over_time()
    local event_json = {}
    event_json["event"] = "TICK"
    event_json["played_ticks"] = game.tick or "no-tick"
    event_json["tick_paused"] = game.tick_paused or "no-tick"
    event_json["ticks_to_run"] = game.ticks_to_run or "no-tick"
    write_game_event_json(event_json)
    factorio_log(event_json["event"], "played_ticks: " .. event_json["played_ticks"])
    factorio_log(event_json["event"], "tick_paused: " .. event_json["tick_paused"])
    factorio_log(event_json["event"], "ticks_to_run: " .. event_json["ticks_to_run"])
end