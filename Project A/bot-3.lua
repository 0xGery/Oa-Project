-- Initializing global variables to store the latest game state and game host process.
local WorldState = WorldState or nil
local Mana = Mana or "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
local BattleCount = BattleCount or 0

-- Define colors for console output
local Colors = {
    crimson = "\27[31m",
    emerald = "\27[32m",
    sapphire = "\27[34m",
    reset = "\27[0m",
}

-- Checks if two points are within a given range.
function isWithinRange(x1, y1, x2, y2, range)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) <= range
end

-- Finds the closest foe to the hero.
function findClosestFoe(hero)
    local closestFoe = nil
    local minDistance = math.huge

    for foe, state in pairs(WorldState.Players) do
        if foe ~= hero.id then
            local dist = math.sqrt((hero.x - state.x) ^ 2 + (hero.y - state.y) ^ 2)
            if dist < minDistance then
                minDistance = dist
                closestFoe = state
            end
        end
    end

    return closestFoe
end

-- Decides the next action based on hero's health, mana levels, and foe positions.
function decideNextMove()
    local hero = WorldState.Players[ao.id]
    local foeInRange = false

    -- Check if any foe is within attack range
    for foe, state in pairs(WorldState.Players) do
        if foe ~= ao.id and isWithinRange(hero.x, hero.y, state.x, state.y, 1) then
            foeInRange = true
            break
        end
    end

    if foeInRange then
        -- Attack if a foe is nearby
        print(Colors.crimson .. "Foe in range. Attacking..." .. Colors.reset)
        ao.send({ Target = "Game", Action = "PlayerAttack", AttackEnergy = tostring(hero.energy) })
    else
        -- Move strategically based on health and foe positions
        local moveDir = makeStrategicMove(hero)
        print(Colors.sapphire .. "Moving strategically in direction: " .. moveDir .. Colors.reset)
        ao.send({ Target = "Game", Action = "PlayerMove", Direction = moveDir })
    end
end

-- Makes a strategic move decision based on foe positions, energy levels, and health.
function makeStrategicMove(hero)
    -- If health is low, move away from the closest foe; otherwise, move towards the predicted future position of the foe
    local closestFoe = findClosestFoe(hero)
    local moveDir = ""

    if hero.health < 30 then
        -- If health is low, move away from the closest foe
        moveDir = getOppositeDirection(hero.x, hero.y, closestFoe.x, closestFoe.y)
    elseif hero.energy > 50 then
        -- If energy is high, move towards the predicted future position of the foe
        moveDir = predictFoeMovement(hero, closestFoe)
    else
        -- If health and energy are moderate, gather resources
        moveDir = gatherResources(hero)
    end

    return moveDir
end

-- Predicts the future movement of the closest foe.
function predictFoeMovement(hero, foe)
    -- Calculate the current distance between the hero and the foe
    local currentDistance = math.sqrt((hero.x - foe.x) ^ 2 + (hero.y - foe.y) ^ 2)

    -- Calculate the speed of the foe
    local foeSpeed = 1.0 

    -- Calculate the time it will take for the hero to reach the current position of the foe
    local timeToReachCurrentPosition = currentDistance / hero.speed

    -- Predict the future position of the foe after a certain time
    local futureX = foe.x + foeSpeed * timeToReachCurrentPosition * math.cos(math.atan2(hero.y - foe.y, hero.x - foe.x))
    local futureY = foe.y + foeSpeed * timeToReachCurrentPosition * math.sin(math.atan2(hero.y - foe.y, hero.x - foe.x))

    -- Determine the direction to move towards the predicted future position of the foe
    local dx = futureX - hero.x
    local dy = futureY - hero.y

    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and "Right" or "Left"
    else
        return dy > 0 and "Down" or "Up"
    end
end

-- Returns the opposite direction of the given direction.
function getOppositeDirection(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1

    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and "Left" or "Right"
    else
        return dy > 0 and "Up" or "Down"
    end
end

-- Moves towards the nearest resource to gather it.
function gatherResources(hero)
    local nearestResource = nil
    local minDistance = math.huge

    for _, resource in pairs(WorldState.Resources) do
        local dist = math.sqrt((hero.x - resource.x) ^ 2 + (hero.y - resource.y) ^ 2)
        if dist < minDistance then
            minDistance = dist
            nearestResource = resource
        end
    end

    if nearestResource then
        local dx = nearestResource.x - hero.x
        local dy = nearestResource.y - hero.y

        if math.abs(dx) > math.abs(dy) then
            return dx > 0 and "Right" or "Left"
        else
            return dy > 0 and "Down" or "Up"
        end
    else
        -- No resources found, move randomly
        local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
        local randomIndex = math.random(#directionMap)
        return directionMap[randomIndex]
    end
end

-- Handlers to update game state and trigger actions.
Handlers.add(
    "UpdateWorldState",
    Handlers.utils.hasMatchingTag("Action", "WorldState"),
    function(msg)
        local json = require("json")
        WorldState = json.decode(msg.Data)
        decideNextMove() -- Make a decision based on the updated game state
    end
)

Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        decideNextMove() -- Make a decision after being attacked
    end
)

Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        -- Print game announcements
        print(Colors.emerald .. msg.Event .. ": " .. msg.Data .. Colors.reset)
    end
)

-- Start the game by retrieving the initial game state
ao.send({ Target = "Game", Action = "GetWorldState" })

local CharacterName = "0xGery"
Prompt = function() return CharacterName .. "> " end
