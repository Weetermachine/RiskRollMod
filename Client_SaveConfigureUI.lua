-- Client_SaveConfigureUI.lua

function Client_SaveConfigureUI(alert, addCard)
    if _RiskMod_rbAttacker ~= nil and _RiskMod_rbAttacker.GetIsChecked() then
        Mod.Settings.TieWinner = 'Attacker'
    else
        Mod.Settings.TieWinner = 'Defender'
    end
end
