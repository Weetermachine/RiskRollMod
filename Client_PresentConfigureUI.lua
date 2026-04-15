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

    UI.CreateLabel(vert)
        .SetText('Max attacker dice (default: 3)')

    local attackDiceInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.MaxAttackDice) or 3)
        .SetWholeNumbers(true)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)

    UI.CreateLabel(vert)
        .SetText('Max defender dice (default: 2)')

    local defendDiceInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.MaxDefendDice) or 2)
        .SetWholeNumbers(true)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)

    UI.CreateLabel(vert)
        .SetText('Retreat Rules')
        .SetColor('#FFD700')

    local cbDiceParity = UI.CreateCheckBox(vert)
        .SetText('Retreat when attacker dice drops to defender dice (unless started at parity)')
        .SetIsChecked(Mod.Settings.RetreatOnDiceParity ~= false)

    local cbLossRatio = UI.CreateCheckBox(vert)
        .SetText('Retreat when attacker losses exceed defender losses by X% (after 3 rounds)')
        .SetIsChecked(Mod.Settings.RetreatOnLossRatio ~= false)

    UI.CreateLabel(vert)
        .SetText('Loss ratio threshold % (default: 100)')

    local lossRatioInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.RetreatLossRatioPct) or 100)
        .SetWholeNumbers(true)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(500)

    UI.CreateLabel(vert)
        .SetText('Minimum rounds before loss ratio retreat triggers (default: 3)')

    local minRoundsInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.RetreatMinRounds) or 3)
        .SetWholeNumbers(true)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)

    UI.CreateLabel(vert)
        .SetText('Overwhelming odds ratio: loss ratio retreat disabled if attacker has X times more armies than defender (default: 5)')

    local overwhelmingInput = UI.CreateNumberInputField(vert)
        .SetValue(tonumber(Mod.Settings.OverwhelmingOddsRatio) or 5)
        .SetWholeNumbers(true)
        .SetSliderMinValue(2)
        .SetSliderMaxValue(20)

    UI.CreateLabel(vert)
        .SetText('⚠ Compatibility: mods that read IsSuccessful from attack results may see inconsistent values when combined with this mod.')
        .SetColor('#FF8C00')

    _RiskMod_rbDefender      = rbDefender
    _RiskMod_rbAttacker      = rbAttacker
    _RiskMod_diceSidesInput  = diceSidesInput
    _RiskMod_attackDiceInput = attackDiceInput
    _RiskMod_defendDiceInput = defendDiceInput
    _RiskMod_cbDiceParity    = cbDiceParity
    _RiskMod_cbLossRatio     = cbLossRatio
    _RiskMod_lossRatioInput  = lossRatioInput
    _RiskMod_minRoundsInput     = minRoundsInput
    _RiskMod_overwhelmingInput  = overwhelmingInput
end
