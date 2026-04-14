-- Client_PresentConfigureUI.lua

function Client_PresentConfigureUI(rootParent)
    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Risk Dice Rolls')
        .SetColor('#FFD700')

    UI.CreateLabel(vert)
        .SetText('Who wins on a tie roll?')

    local group = UI.CreateRadioButtonGroup(vert)

    local rbDefender = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Defender wins ties (default, classic Risk)')

    local rbAttacker = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Attacker wins ties')

    if Mod.Settings.TieWinner == 'Attacker' then
        rbAttacker.SetIsChecked(true)
    else
        rbDefender.SetIsChecked(true)
    end

    UI.CreateLabel(vert)
        .SetText('Number of sides on each die (default: 6)')

    local diceSidesInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.DiceSides) or 6)
        .SetWholeNumbers(true)
        .SetSliderMinValue(2)
        .SetSliderMaxValue(20)

    _RiskMod_rbDefender    = rbDefender
    _RiskMod_rbAttacker    = rbAttacker
    _RiskMod_diceSidesInput = diceSidesInput
end
