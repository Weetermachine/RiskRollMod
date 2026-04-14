-- Server_AdvanceTurn.lua
-- "Risk Dice Rolls" mod
--
-- Replaces Warzone's combat math with Risk-style dice by modifying the
-- order result in place. This lets Warzone handle captures, card awards,
-- elimination, and special unit death naturally.
--
-- We run our own dice simulation, then set:
--   orderResult.AttackingArmiesKilled
--   orderResult.DefendingArmiesKilled
--   orderResult.IsSuccessful
--   orderResult.DamageToSpecialUnits (for commanders)

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

-- Roll N dice, return sorted descending
local function rollDice(n)
    local rolls = {}
    for i = 1, n do rolls[i] = math.random(1, 6) end
    table.sort(rolls, function(a, b) return a > b end)
    return rolls
end

-- Simulate a full Risk battle.
-- Returns: attackRegularLost, attackCmdDmg, defendRegularLost, defendCmdDmg
-- where CmdDmg is cumulative damage dealt to the commander (7 = dead)
local function simulateBattle(attackRegular, attackHasCmd,
                               defendRegular, defendHasCmd,
                               tieGoesToAttacker)
    local aReg    = attackRegular
    local aCmdHP  = attackHasCmd and 7 or 0
    local dReg    = defendRegular
    local dCmdHP  = defendHasCmd and 7 or 0

    local aRegLost  = 0
    local aCmdDmg   = 0
    local dRegLost  = 0
    local dCmdDmg   = 0

    local function aTotal() return aReg + aCmdHP end
    local function dTotal() return dReg + dCmdHP end

    local function applyLossToAttacker()
        if aReg > 0 then
            aReg = aReg - 1
            aRegLost = aRegLost + 1
        elseif aCmdHP > 0 then
            aCmdHP = aCmdHP - 1
            aCmdDmg = aCmdDmg + 1
        end
    end

    local function applyLossToDefender()
        if dReg > 0 then
            dReg = dReg - 1
            dRegLost = dRegLost + 1
        elseif dCmdHP > 0 then
            dCmdHP = dCmdHP - 1
            dCmdDmg = dCmdDmg + 1
        end
    end

    while aTotal() > 0 and dTotal() > 0 do
        local aDice  = math.min(aTotal(), 3)
        local dDice  = math.min(dTotal(), 2)
        local aRolls = rollDice(aDice)
        local dRolls = rollDice(dDice)

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
            else
                applyLossToAttacker()
            end
        end
    end

    return aRegLost, aCmdDmg, dRegLost, dCmdDmg
end

-----------------------------------------------------------------------
-- Hook
-----------------------------------------------------------------------

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderAttackTransfer' then return end
    if not orderResult.IsAttack then return end

    local standing = game.ServerGame.LatestTurnStanding
    local playerID = order.PlayerID
    local toTerrID = order.To

    local defenderID = standing.Territories[toTerrID].OwnerPlayerID

    -- Attacking armies
    local attackRegular     = order.NumArmies.NumArmies
    local attackCommander   = findCommanderInArmies(order.NumArmies, playerID)
    local attackHasCmd      = attackCommander ~= nil

    -- Defending armies
    local defendStanding    = standing.Territories[toTerrID]
    local defendRegular     = defendStanding.NumArmies.NumArmies
    local defendCommander   = findCommanderInTerritory(standing, toTerrID, defenderID)
    local defendHasCmd      = defendCommander ~= nil

    local tieGoesToAttacker = (Mod.Settings.TieWinner == 'Attacker')

    -- Run Risk dice simulation
    local aRegLost, aCmdDmg, dRegLost, dCmdDmg =
        simulateBattle(attackRegular, attackHasCmd,
                       defendRegular, defendHasCmd,
                       tieGoesToAttacker)

    local attackerWon = (dRegLost >= defendRegular)
                        and (not defendHasCmd or dCmdDmg >= 7)

    -- DIAGNOSTIC: dump writable keys on orderResult
    local wk = orderResult.writableKeys
    local keys = ''
    if wk ~= nil then
        for _, k in ipairs(wk) do keys = keys .. k .. ',' end
    end
    error('RISK_DIAG | writableKeys=' .. keys)

    -- Build AttackingArmiesKilled armies object
    local attackCmdKilled = attackHasCmd and aCmdDmg >= 7
    local attackKilledSpecials = {}
    if attackCmdKilled then
        attackKilledSpecials[1] = attackCommander
    end
    orderResult.AttackingArmiesKilled = WL.Armies.Create(aRegLost, attackKilledSpecials)

    -- Build DefendingArmiesKilled armies object
    local defendCmdKilled = defendHasCmd and dCmdDmg >= 7
    local defendKilledSpecials = {}
    if defendCmdKilled then
        defendKilledSpecials[1] = defendCommander
    end
    orderResult.DefendingArmiesKilled = WL.Armies.Create(dRegLost, defendKilledSpecials)

    -- Handle partial commander damage via DamageToSpecialUnits
    -- (only needed if commander took damage but didn't die)
    local dmgTable = {}
    if attackHasCmd and aCmdDmg > 0 and not attackCmdKilled then
        dmgTable[attackCommander.ID] = aCmdDmg
    end
    if defendHasCmd and dCmdDmg > 0 and not defendCmdKilled then
        dmgTable[defendCommander.ID] = dCmdDmg
    end
    -- Per the rules: commander health resets if they survive, so we
    -- don't actually persist partial damage. Leave dmgTable empty for survivors.
    -- DamageToSpecialUnits is only set for killed commanders (handled above).
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
