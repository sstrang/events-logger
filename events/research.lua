local function get_infinite_research_name(name)
    -- gets the name of infinite research (without numbers)
    return string.match(name, "^(.-)%-%d+$") or name
end

--- Extract the science packs consumed by a research, as tuples of
--- {science_pack_name, amount}.
--- science_pack_name is the internal Factorio item prototype name (e.g.
--- "automation-science-pack"); amount is the number of that pack consumed
--- per research unit (base game is always 1, but mods may differ).
---@param research LuaTechnology - The technology being researched.
---@return table - Array of tuples: {{name, amount}, ...}
local function get_science_packs(research)
    local packs = {}
    for _, ingredient in ipairs(research.research_unit_ingredients or {}) do
        local name = ingredient.name or ingredient[1]
        local amount = ingredient.amount or ingredient[2]
        table.insert(packs, {name, amount})
    end
    return packs
end

function on_research_started(event)
    local event_json = {}
    event_json["name"] = get_infinite_research_name(event.research.name)
    event_json["event"] = "RESEARCH_STARTED"
    event_json["level"] = (event.research.level or "no-level")
    event_json["science_packs"] = get_science_packs(event.research)
    event_json["tick"] = event.tick
    write_game_event_json(event_json)
    factorio_log(event_json["event"], event_json["name"] .. " " .. event_json["level"])
end

function on_research_finished(event)
    local event_json = {}
    event_json["name"] = get_infinite_research_name(event.research.name)
    event_json["event"] = "RESEARCH_FINISHED"
    event_json["level"] = (event.research.level or "no-level")
    event_json["tick"] = event.tick
    write_game_event_json(event_json)
    log("[RESEARCH FINISHED] " .. event_json["name"] .. " " .. event_json["level"])
end

function on_research_cancelled(event)
    local event_json = {}
    event_json["event"] = "RESEARCH_CANCELLED"
    event_json["tick"] = event.tick
    for k, _ in pairs(event.research) do
        event_json["name"] = get_infinite_research_name(k)
        event_json["level"] = k.level or "no-level"
        write_game_event_json(event_json)
        factorio_log(event_json["event"], event_json["name"])
    end
end

events[defines.events.on_research_started] = on_research_started
events[defines.events.on_research_finished] = on_research_finished
events[defines.events.on_research_cancelled] = on_research_cancelled