-- Initializing global variables
local LatestGameState = LatestGameState or nil
local Game = "oPre75iYJzWPiNkk_7B6QwmDPBSJIn9Rqrvil1Gho7U"
local CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
local InAction = false
local BeingAttacked = false

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function inRange(x1, y1, x2, y2, range)
    return distance(x1, y1, x2, y2) <= range
end

local function getDirections(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local dirX, dirY = "", ""
    if dx > 0 then dirX = "Right" else dirX = "Left" end
    if dy > 0 then dirY = "Down" else dirY = "Up" end
    return dirX, dirY
end

local function randomDirection()
    local directions = { "Up", "Down", "Left", "Right" }
    return directions[math.random(1, #directions)]
end

-- Game state analysis
local function analyzeGameState()
    local player = LatestGameState.Players[ao.id]
    local targets = {}

    for id, state in pairs(LatestGameState.Players) do
        if id ~= ao.id then
            local dist = distance(player.x, player.y, state.x, state.y)
            table.insert(targets, { id = id, state = state, dist = dist })
        end
    end

    table.sort(targets, function(a, b) return a.dist < b.dist end)
    return targets
end

-- Strategy decision-making
local function decideBestStrategy()
    local player = LatestGameState.Players[ao.id]
    local targets = analyzeGameState()

    -- Attack the nearest target with lower health if within range
    for _, target in ipairs(targets) do
        if inRange(player.x, player.y, target.state.x, target.state.y, 1) and
            player.energy > target.state.energy then
            return "attack", target.id
        end
    end

    -- If being attacked and low on health, retreat from the attacker
    if player.health < 20 and BeingAttacked then
        local retreatDir
        for _, target in ipairs(targets) do
            if target.dist <= 2 then
                retreatDir = getDirections(target.state.x, target.state.y, player.x, player.y)
                break
            end
        end
        return "retreat", retreatDir
    end

    -- Move towards the nearest target with higher energy
    local strongestTarget = nil
    for _, target in ipairs(targets) do
        if not strongestTarget or target.state.energy > strongestTarget.state.energy then
            strongestTarget = target
        end
    end
    if strongestTarget then
        local moveDir = getDirections(player.x, player.y, strongestTarget.state.x, strongestTarget.state.y)
        return "move", table.concat(moveDir, "")
    end

    -- No targets, move randomly
    return "random"
end

-- Function to decide the next action
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local playerEnergy = player.energy
    local playerX = player.x
    local playerY = player.y

    -- Check if the bot's energy is less than or equal to 20
    if playerEnergy <= 20 then
        print("Bot's energy is less than or equal to 20.")
    end

    -- Check for weak enemies with energy less than 10 and at coordinates >=3
    for id, opponent in pairs(LatestGameState.Players) do
        if id ~= ao.id then
            if opponent.energy < 10 and opponent.x >= 3 then
                print("Weak enemy detected at coordinates: " .. opponent.x .. ", " .. opponent.y)
                -- Bot moves closer and attacks the weak enemy
                local deltaX = opponent.x - playerX
                local deltaY = opponent.y - playerY
                if math.abs(deltaX) > math.abs(deltaY) then
                    if deltaX > 0 then
                        print("Moving right")
                    else
                        print("Moving left")
                    end
                else
                    if deltaY > 0 then
                        print("Moving down")
                    else
                        print("Moving up")
                    end
                end
                print("Attacking the weak enemy.")
                return
            end
        end
    end
end

-- Event handlers
Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    decideNextAction()
end)

Handlers.add("ReturnAttack", Handlers.utils.hasMatchingTag("Action", "Hit"), function(msg)
    BeingAttacked = true
    decideBestStrategy()
end)

Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        ao.send({
            Target = ao.id,
            Action = "AutoPay"
        })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true
        ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then
        print("[PrintAnnouncements]Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end)

Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not InAction then
        InAction = true
        print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    else
        print("[GetGameStateOnTick]Previous action still in progress. Skipping.")
    end
end)

Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"), function(msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
end)

Handlers.add("Respawn", Handlers.utils.hasMatchingTag("Action", "Eliminated"), function(msg)
    print("Eliminated! " .. "Playing again!")
    ao.send({ Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game })
end)

-- Initial action to register with the game
Send({ Target = Game, Action = "Register" })