function on_cargo_pod_finished_ascending(event)
    local event_json = {}
    event_json["event"] = "CARGO_POD_FINISHED_ASCENDING"
    event_json["launched_by_rocket"] = event.launched_by_rocket
    if event.player_index then
        local player = game.get_player(event.player_index)
        event_json["player"] = { ["present"] = true,
                                 ["name"] = player.name
        }
    else
        event_json["player"] = { ["present"] = false }
    end

    event_json["cargo_pod"] = {
        ["name"] = event.cargo_pod.name,
        ["position"] = {
            ["x"] = event.cargo_pod.position.x,
            ["y"] = event.cargo_pod.position.y,
        },
    }

    local cargo_pod_inventory = event.cargo_pod.get_inventory(defines.inventory.cargo_unit)
    if cargo_pod_inventory then
        local cargo_pod_inventory_contents = cargo_pod_inventory.get_contents()
        event_json["inventory"] = {}
        for _, item in pairs(cargo_pod_inventory_contents) do
            table.insert(event_json["inventory"],
                    {
                        ["name"] = item.name,
                        ["count"] = item.count,
                        ["quality"] = item.quality
                    }
            )
        end
        event_json["tick"] = event.tick
        write_game_event_json(event_json)
        factorio_log(event_json["event"], " from " .. event_json["cargo_pod"]["name"] .. " at " .. event_json["cargo_pod"]["position"]["x"] .. ", " .. event_json["cargo_pod"]["position"]["y"])
    end
end

function on_rocket_launch_ordered(event)
    local event_json = {}
    event_json["event"] = "ROCKET_LAUNCH_ORDERED"
    if event.player_index then
        local player = game.get_player(event.player_index)
        event_json["player"] = { ["present"] = true,
                                 ["name"] = player.name
        }
    else
        event_json["player"] = { ["present"] = false }
    end
    event_json["silo"] = {
        ["name"] = event.rocket_silo.name,
        ["position"] = {
            ["x"] = event.rocket_silo.position.x,
            ["y"] = event.rocket_silo.position.y,
        },
    }
    event_json["tick"] = event.tick
    write_game_event_json(event_json)
    factorio_log(event_json["event"], " from " .. event_json["silo"]["name"] .. " at " .. event_json["silo"]["position"]["x"] .. ", " .. event_json["silo"]["position"]["y"])
end

function on_rocket_launched(event)
    local event_json = {}
    event_json["event"] = "ROCKET_LAUNCHED"
    if event.rocket_silo then
        event_json["silo"] = {
            ["name"] = event.rocket_silo.name,
            ["position"] = {
                ["x"] = event.rocket_silo.position.x,
                ["y"] = event.rocket_silo.position.y,
            },
        }
    end
    event_json["tick"] = event.tick
    write_game_event_json(event_json)
    if event.rocket_silo then
        factorio_log(event_json["event"], " from " .. event_json["silo"]["name"] .. " at " .. event_json["silo"]["position"]["x"] .. ", " .. event_json["silo"]["position"]["y"])
    else
        factorio_log(event_json["event"], " with no rocket silo recorded")
    end
end

events[defines.events.on_cargo_pod_finished_ascending] = on_cargo_pod_finished_ascending
events[defines.events.on_rocket_launch_ordered] = on_rocket_launch_ordered
events[defines.events.on_rocket_launched] = on_rocket_launched
