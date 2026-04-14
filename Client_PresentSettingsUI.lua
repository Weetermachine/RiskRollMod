-- Client_PresentSettingsUI.lua

function Client_PresentSettingsUI(rootParent)
    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Risk Dice Rolls')
        .SetColor('#FFD700')

    local tieWinner          = Mod.Settings.TieWinner or 'Defender'
    local diceSides          = tonumber(Mod.Settings.DiceSides)          or 6
    local attackDice         = tonumber(Mod.Settings.MaxAttackDice)      or 3
    local defendDice         = tonumber(Mod.Settings.MaxDefendDice)      or 2
    local retreatDiceParity  = Mod.Settings.RetreatOnDiceParity  == true
    local retreatLossRatio   = Mod.Settings.RetreatOnLossRatio   == true
    local lossRatioPct       = tonumber(Mod.Settings.RetreatLossRatioPct) or 100
    local minRounds          = tonumber(Mod.Settings.RetreatMinRounds)      or 3

    UI.CreateLabel(vert)
        .SetText('Replaces Warzone combat with Risk-style dice. Battles are fought to completion.\n\n'
                 .. '• Max attacker dice: ' .. attackDice .. '\n'
                 .. '• Max defender dice: ' .. defendDice .. '\n'
                 .. '• Die sides: ' .. diceSides .. '\n'
                 .. '• Tie winner: ' .. tieWinner .. '\n'
                 .. '• Commanders count as 7 armies and die last.\n\n'
                 .. 'Retreat rules:\n'
                 .. '• Retreat on dice parity: ' .. (retreatDiceParity and 'On' or 'Off') .. '\n'
                 .. '• Retreat on loss ratio: ' .. (retreatLossRatio and ('On (' .. lossRatioPct .. '%, min ' .. minRounds .. ' rounds)') or 'Off'))

    UI.CreateLabel(vert)
        .SetText('⚠ Compatibility: mods that read IsSuccessful from attack results may see inconsistent values when combined with this mod.')
        .SetColor('#FF8C00')
end
