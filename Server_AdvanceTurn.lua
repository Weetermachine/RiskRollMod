-- Server_AdvanceTurn.lua
-- "Risk Dice Rolls" mod
--
-- Replaces Warzone's combat system with Risk-style dice:
--   Attacker rolls up to 3 dice, defender rolls up to 2 dice.
--   Highest vs highest, second vs second. Defender wins ties.
--   Battle repeats until one side is completely wiped out.
--
-- Commanders count as 7 armies, die last (regular armies absorb losses first).
-- If a commander survives the attack, their health resets next turn.
-- Commander only participates if explicitly committed to the attack.

function Server_AdvanceTurn_Start(game, addNewOrder)
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function findCommander(specialUnits, ownerID)
    if specialUnits == nil then return nil end
    for _, unit in ipairs(specialUnits) do
        if unit.proxyType == 'Commander' and unit.OwnerID == ownerID then
            return unit
        end
    end
    return nil
end

-- Roll N dice, return sorted descending array
local function rollDice(n)
    local rolls = {}
    for i = 1, n do
        rolls[i] = math.random(1, 6)
    end
    table.sort(rolls, function(a, b) return a > b end)
    return rolls
end

-- Simulate one full Risk battle to completion.
-- Returns: attackerLosses, defenderLosses, attackerCommanderDied, defenderCommanderDied
local function simulateBattle(attackArmies, attackHasCommander,
                               defendArmies, defendHasCommander,
                               tieGoesToAttacker)
    local attackRegular  = attackArmies
    local attackCmdHP    = attackHasCommander and 7 or 0
    local defendRegular  = defendArmies
    local defendCmdHP    = defendHasCommander and 7 or 0

    local function attackTotal() return attackRegular + (attackCmdHP > 0 and attackCmdHP or 0) end
    local function defendTotal() return defendRegular + (defendCmdHP > 0 and defendCmdHP or 0) end

    -- Apply N losses to a side, regular armies die first, then commander HP
    local function applyLosses(losses, regularRef, cmdHPRef)
        local reg = regularRef
        local cmd = cmdHPRef
        local remaining = losses
        if reg >= remaining then
            reg = reg - remaining
            remaining = 0
        else
            remaining = remaining - reg
            reg = 0
            cmd = cmd - remaining
            if cmd < 0 then cmd = 0 end
        end
        return reg, cmd
    end

    local totalAttackLosses  = 0
    local totalDefendLosses  = 0

    while attackTotal() > 0 and defendTotal() > 0 do
        local aDice = math.min(attackTotal(), 3)
        local dDice = math.min(defendTotal(), 2)

        local aRolls = rollDice(aDice)
        local dRolls = rollDice(dDice)

        local comparisons = math.min(aDice, dDice)
        for i = 1, comparisons do
            local attackerWinsComparison
            if aRolls[i] > dRolls[i] then
                attackerWinsComparison = true
            elseif aRolls[i] == dRolls[i] then
                attackerWinsComparison = (tieGoesToAttacker == true)
            else
                attackerWinsComparison = false
            end

            if attackerWinsComparison then
                -- Attacker wins this comparison, defender loses 1
                local newReg, newCmd = applyLosses(1, defendRegular, defendCmdHP)
                local lost = (defendRegular - newReg) + (defendCmdHP - newCmd)
                totalDefendLosses = totalDefendLosses + lost
                defendRegular = newReg
                defendCmdHP   = newCmd
            else
                -- Defender wins, attacker loses 1
                local newReg, newCmd = applyLosses(1, attackRegular, attackCmdHP)
                local lost = (attackRegular - newReg) + (attackCmdHP - newCmd)
                totalAttackLosses = totalAttackLosses + lost
                attackRegular = newReg
                attackCmdHP   = newCmd
            end
        end
    end

    local attackerCommanderDied = attackHasCommander and attackCmdHP <= 0
    local defenderCommanderDied = defendHasCommander and defendCmdHP <= 0

    -- Surviving regular armies (commander health doesn't map back to armies)
    local attackSurvivors = attackRegular
    local defendSurvivors = defendRegular

    return attackSurvivors, defendSurvivors,
           attackerCommanderDied, defenderCommanderDied,
           totalAttackLosses, totalDefendLosses
end

-----------------------------------------------------------------------
-- Hook
-----------------------------------------------------------------------

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderAttackTransfer' then return end
    if not orderResult.IsAttack then return end

    local standing   = game.ServerGame.LatestTurnStanding
    local playerID   = order.PlayerID
    local fromTerrID = order.From
    local toTerrID   = order.To

    local fromStanding = standing.Territories[fromTerrID]
    local toStanding   = standing.Territories[toTerrID]

    -- Attacking armies committed by the player
    local attackArmies      = order.NumArmies.NumArmies
    local attackSpecialUnits = order.NumArmies.SpecialUnits
    local attackCommander   = findCommander(attackSpecialUnits, playerID)
    local attackHasCommander = attackCommander ~= nil

    -- Defending armies
    local defendArmies      = toStanding.NumArmies.NumArmies
    local defendSpecialUnits = toStanding.NumArmies.SpecialUnits
    local defenderID        = toStanding.OwnerPlayerID
    local defendCommander   = findCommander(defendSpecialUnits, defenderID)
    local defendHasCommander = defendCommander ~= nil

    -- Run the Risk battle simulation
    local tieGoesToAttacker = (Mod.Settings.TieWinner == 'Attacker')

    local attackSurvivors, defendSurvivors,
          attackerCommanderDied, defenderCommanderDied,
          attackLosses, defendLosses =
        simulateBattle(attackArmies, attackHasCommander,
                       defendArmies, defendHasCommander,
                       tieGoesToAttacker)

    local attackerWon = defendSurvivors <= 0 and not (defendHasCommander and not defenderCommanderDied)

    -- Skip Warzone's built-in combat resolution
    skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage)

    -- Build territory modifications to reflect the battle outcome
    local mods = {}

    if attackerWon then
        -- Attacker captures the territory
        -- Source territory: remove the committed armies (and commander if died)
        local sourceMod = WL.TerritoryModification.Create(fromTerrID)
        sourceMod.AddArmies = -attackArmies
        if attackHasCommander then
            sourceMod.RemoveSpecialUnitsOpt = { attackCommander.ID }
        end
        mods[#mods + 1] = sourceMod

        -- Destination territory: change owner, set surviving armies
        local destMod = WL.TerritoryModification.Create(toTerrID)
        destMod.SetOwnerOpt = playerID
        destMod.SetArmiesTo = attackSurvivors

        -- Remove defender's commander if they died
        if defendHasCommander and defenderCommanderDied then
            destMod.RemoveSpecialUnitsOpt = { defendCommander.ID }
        end

        -- Move attacker's commander to captured territory if they survived
        if attackHasCommander and not attackerCommanderDied then
            destMod.AddSpecialUnits = { WL.Commander.Create(playerID) }
            -- Remove from source (already handled above)
        end

        mods[#mods + 1] = destMod
    else
        -- Attacker failed — update source territory (remove dead attackers)
        local sourceMod = WL.TerritoryModification.Create(fromTerrID)
        sourceMod.AddArmies = -attackLosses
        if attackHasCommander and attackerCommanderDied then
            sourceMod.RemoveSpecialUnitsOpt = { attackCommander.ID }
        end
        mods[#mods + 1] = sourceMod

        -- Update destination territory (remove dead defenders)
        local destMod = WL.TerritoryModification.Create(toTerrID)
        destMod.AddArmies = -defendLosses
        if defendHasCommander and defenderCommanderDied then
            destMod.RemoveSpecialUnitsOpt = { defendCommander.ID }
        end
        mods[#mods + 1] = destMod
    end

    -- Build result message
    local attackerName = game.Game.Players[playerID].DisplayName(nil, false)
    local msg
    if attackerWon then
        msg = attackerName .. ' attacked with Risk dice and captured the territory! '
              .. '(Attacker lost ' .. attackLosses .. ', Defender lost ' .. defendLosses .. ')'
    else
        msg = attackerName .. ' attacked with Risk dice but failed. '
              .. '(Attacker lost ' .. attackLosses .. ', Defender lost ' .. defendLosses .. ')'
    end

    if attackerCommanderDied then
        msg = msg .. ' Attacker\'s commander was killed!'
    end
    if defenderCommanderDied then
        msg = msg .. ' Defender\'s commander was killed!'
    end

    local event = WL.GameOrderEvent.Create(playerID, msg, nil, mods, nil, nil)
    addNewOrder(event)
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
