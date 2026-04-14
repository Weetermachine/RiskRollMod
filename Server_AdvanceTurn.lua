-- Server_AdvanceTurn.lua
-- "Risk Dice Rolls" mod

function Server_AdvanceTurn_Start(game, addNewOrder)
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function findCommanderInArmies(armies, ownerID)
    local units = armies.SpecialUnits
    if units == nil then return nil end
    for _, unit in ipairs(units) do
        if unit.proxyType == 'Commander' and unit.OwnerID == ownerID then
            return unit
        end
    end
    return nil
end

local function findCommanderInTerritory(standing, terrID, ownerID)
    local ts = standing.Territories[terrID]
    if ts == nil then return nil end
    return findCommanderInArmies(ts.NumArmies, ownerID)
end

local _rollCounter = 0

local function rollDice(n, sides, seedBase)
    local rolls = {}
    for i = 1, n do
        _rollCounter = _rollCounter + 1
        local raw = math.random(1, 1000000)
        local mixed = (raw * seedBase + _rollCounter * 999983 + i * 49999)
        rolls[i] = (mixed % sides) + 1
    end
    table.sort(rolls, function(a, b) return a > b end)
    return rolls
end

local function joinNums(t)
    local s = ''
    for i, v in ipairs(t) do
        if i > 1 then s = s .. ', ' end
        s = s .. tostring(v)
    end
    return s
end

-- Simulate a full Risk battle, returning results and a verbose log.
local function simulateBattle(attackRegular, attackHasCmd,
                               defendRegular, defendHasCmd,
                               tieGoesToAttacker, diceSides, seedBase)
    local aReg   = attackRegular
    local aCmdHP = attackHasCmd and 7 or 0
    local dReg   = defendRegular
    local dCmdHP = defendHasCmd and 7 or 0

    local aRegLost = 0
    local aCmdDmg  = 0
    local dRegLost = 0
    local dCmdDmg  = 0
    local log      = {}

    local function aTotal() return aReg + aCmdHP end
    local function dTotal() return dReg + dCmdHP end

    local function applyLossToAttacker()
        if aReg > 0 then
            aReg = aReg - 1; aRegLost = aRegLost + 1
        elseif aCmdHP > 0 then
            aCmdHP = aCmdHP - 1; aCmdDmg = aCmdDmg + 1
        end
    end

    local function applyLossToDefender()
        if dReg > 0 then
            dReg = dReg - 1; dRegLost = dRegLost + 1
        elseif dCmdHP > 0 then
            dCmdHP = dCmdHP - 1; dCmdDmg = dCmdDmg + 1
        end
    end

    local round = 0
    while aTotal() > 0 and dTotal() > 0 do
        round = round + 1
        local aDice  = math.min(aTotal(), 3)
        local dDice  = math.min(dTotal(), 2)
        local aRolls = rollDice(aDice, diceSides, seedBase)
        local dRolls = rollDice(dDice, diceSides, seedBase)

        local aLostThisRound = 0
        local dLostThisRound = 0

        for i = 1, math.min(aDice, dDice) do
            local attackerWins
            if aRolls[i] > dRolls[i] then
                attackerWins = true
            elseif aRolls[i] == dRolls[i] then
                attackerWins = (tieGoesToAttacker == true)
            else
                attackerWins = false
            end
            if attackerWins then
                applyLossToDefender()
                dLostThisRound = dLostThisRound + 1
            else
                applyLossToAttacker()
                aLostThisRound = aLostThisRound + 1
            end
        end

        -- Build round log line
        -- Compact format: R1: A[6,2,1] D[3,3] -1a -1d (A:9 D:7)
        local line = 'R' .. round .. ': '
                  .. 'A[' .. joinNums(aRolls) .. '] '
                  .. 'D[' .. joinNums(dRolls) .. '] '
                  .. '-' .. aLostThisRound .. 'a '
                  .. '-' .. dLostThisRound .. 'd '
                  .. '(A:' .. aTotal() .. ' D:' .. dTotal() .. ')'
        log[#log + 1] = line
    end

    -- Trim to first 10 and last 10 rounds if log is long
    local trimmedLog
    if #log <= 20 then
        trimmedLog = log
    else
        trimmedLog = {}
        for i = 1, 10 do trimmedLog[#trimmedLog + 1] = log[i] end
        trimmedLog[#trimmedLog + 1] = '... (' .. (#log - 20) .. ' rounds omitted) ...'
        for i = #log - 9, #log do trimmedLog[#trimmedLog + 1] = log[i] end
    end

    return aRegLost, aCmdDmg, dRegLost, dCmdDmg, trimmedLog
end

-----------------------------------------------------------------------
-- Hook
-----------------------------------------------------------------------

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderAttackTransfer' then return end
    if not orderResult.IsAttack then return end

    local standing  = game.ServerGame.LatestTurnStanding
    local playerID  = order.PlayerID
    local toTerrID  = order.To
    local defenderID = standing.Territories[toTerrID].OwnerPlayerID

    local attackRegular   = order.NumArmies.NumArmies
    local attackCommander = findCommanderInArmies(order.NumArmies, playerID)
    local attackHasCmd    = attackCommander ~= nil

    local defendRegular   = standing.Territories[toTerrID].NumArmies.NumArmies
    local defendCommander = findCommanderInTerritory(standing, toTerrID, defenderID)
    local defendHasCmd    = defendCommander ~= nil

    local tieGoesToAttacker = (Mod.Settings.TieWinner == 'Attacker')
    local diceSides = tonumber(Mod.Settings.DiceSides) or 6
    if diceSides < 2 then diceSides = 2 end



    local seedBase = game.Game.NumberOfTurns * 1000000
                   + order.From * 7919
                   + toTerrID * 6271
                   + attackRegular * 1009
                   + defendRegular * 877

    local aRegLost, aCmdDmg, dRegLost, dCmdDmg, log =
        simulateBattle(attackRegular, attackHasCmd,
                       defendRegular, defendHasCmd,
                       tieGoesToAttacker, diceSides, seedBase)

    local attackCmdKilled  = attackHasCmd and aCmdDmg >= 7
    local defendCmdKilled  = defendHasCmd and dCmdDmg >= 7

    local attackKilledSpecials = {}
    if attackCmdKilled then attackKilledSpecials[1] = attackCommander end
    orderResult.AttackingArmiesKilled = WL.Armies.Create(aRegLost, attackKilledSpecials)

    local defendKilledSpecials = {}
    if defendCmdKilled then defendKilledSpecials[1] = defendCommander end
    orderResult.DefendingArmiesKilled = WL.Armies.Create(dRegLost, defendKilledSpecials)

    -- Build verbose message
    local attackerName = game.Game.Players[playerID].DisplayName(nil, false)
    local summary = '[Risk] ' .. attackerName .. ' '
                 .. attackRegular .. (attackHasCmd and '+C' or '') .. 'v'
                 .. defendRegular .. (defendHasCmd and '+C' or '') .. ':\n'
    local fullMsg = summary .. table.concat(log, '\n')

    -- Append commander death notes
    if attackCmdKilled then fullMsg = fullMsg .. '\n[Attacker CMD died]' end
    if defendCmdKilled then fullMsg = fullMsg .. '\n[Defender CMD died]' end

    local event = WL.GameOrderEvent.Create(playerID, fullMsg, { playerID, defenderID }, nil, nil, nil)
    addNewOrder(event, true)
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
