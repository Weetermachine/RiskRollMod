-- Client_SaveConfigureUI.lua

function Client_SaveConfigureUI(alert, addCard)
    if _RiskMod_rbAttacker ~= nil and _RiskMod_rbAttacker.GetIsChecked() then
        Mod.Settings.TieWinner = 'Attacker'
    else
        Mod.Settings.TieWinner = 'Defender'
    end

    local sides = math.floor(_RiskMod_diceSidesInput.GetValue())
    if sides < 2 then
        alert('Dice must have at least 2 sides.')
        return
    end
    Mod.Settings.DiceSides = sides
end
