-- Initializing global variables
LatestGameState = LatestGameState or {}
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
Game = "oPre75iYJzWPiNkk_7B6QwmDPBSJIn9Rqrvil1Gho7U"
CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Counter = 0

-- Function to register the bot with the game
function register()
    ao.send({ Target = Game, Action = "Register" })
end

-- Function to decide the next action
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local weakestPlayerId = nil
    local weakestPlayerHealth = 100

    -- Find the weakest player within range
    for playerId, playerState in pairs(LatestGameState.Players) do
        if playerId ~= ao.id then
            local dist = math.sqrt((player.x - playerState.x)^2 + (player.y - playerState.y)^2)
            if dist <= 1 and playerState.health < weakestPlayerHealth then
                weakestPlayerId = playerId
                weakestPlayerHealth = playerState.health
            end
        end
    end

    -- If a weak player is found, attack; otherwise, move randomly
    if weakestPlayerId then
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, Target = weakestPlayerId })
    else
        local directions = { "Up", "Down", "Left", "Right" }
        local randomDirection = directions[math.random(1, #directions)]
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = randomDirection })
    end
end

-- Handler to update the game state
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function (msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        decideNextAction()
    end
)

-- Handler to trigger game state updates
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function ()
        ao.send({ Target = Game, Action = "GetGameState" })
    end
)

-- Handler to automatically attack when hit by another player
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function (msg)
        local playerEnergy = LatestGameState.Players[ao.id].energy
        if playerEnergy and playerEnergy > 0 then
            ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
        end
    end
)

register()
