-- Client_PresentConfigureUI.lua

function Client_PresentConfigureUI(rootParent)
    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Risk Dice Rolls')
        .SetColor('#FFD700')

    UI.CreateLabel(vert)
        .SetText('Replaces Warzone combat with Risk-style dice. Battles are fought to completion.\n\nWho wins on a tie roll?')

    local group = UI.CreateRadioButtonGroup(vert)

    local rbDefender = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Defender wins ties (default, classic Risk)')

    local rbAttacker = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Attacker wins ties')

    -- Restore saved setting
    if Mod.Settings.TieWinner == 'Attacker' then
        rbAttacker.SetIsChecked(true)
    else
        rbDefender.SetIsChecked(true)
    end

    _RiskMod_rbDefender = rbDefender
    _RiskMod_rbAttacker = rbAttacker
end
