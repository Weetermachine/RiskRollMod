-- Client_PresentSettingsUI.lua

function Client_PresentSettingsUI(rootParent)
    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Risk Dice Rolls')
        .SetColor('#FFD700')

    local tieWinner = Mod.Settings.TieWinner or 'Defender'
    local diceSides = tonumber(Mod.Settings.DiceSides) or 6

    UI.CreateLabel(vert)
        .SetText('Replaces Warzone combat with Risk-style dice. Battles are fought to completion.\n\n'
                 .. '• Attacker rolls up to 3 dice, defender up to 2.\n'
                 .. '• Die sides: ' .. diceSides .. '\n'
                 .. '• Tie winner: ' .. tieWinner .. '\n'
                 .. '• Commanders count as 7 armies and die last.')
end
