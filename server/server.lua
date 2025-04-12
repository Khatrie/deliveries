local QBCore = exports['qb-core']:GetCoreObject()
local useDebug = false

RegisterServerEvent('sd-deliveryjob:server:startJob', function(item)
    local src = source
    exports.ox_inventory:AddItem(src, item, 1, nil)
end)


RegisterServerEvent('sd-deliveryjob:server:turnInFood', function(item, freelancing, company)
    local src = source
    if exports.ox_inventory:RemoveItem(src, item, 1, nil) then
	    local Player = QBCore.Functions.GetPlayer(src)
        local payment = math.random(Config.Payment.min,Config.Payment.max)
        if freelancing then
            payment = payment + Config.FreelanceBonus
        end
		Player.Functions.AddMoney("cash",payment , 'Delivery')
        TriggerClientEvent('QBCore:Notify', src, 'You got paid $'..payment, 'success' )
        exports['Renewed-Banking']:addAccountMoney(company, Config.CompanyMoney)
        if math.random(1,100) < Config.BonusChance then
            local bonus = math.random(Config.Bonus.min,Config.Bonus.max)
		    Player.Functions.AddMoney("cash", bonus , 'Delivery Bonus')
            TriggerClientEvent('QBCore:Notify', src, 'You also got a $'..bonus.. ' bonus!', 'success')
        end
    end
end)

QBCore.Commands.Add('debugdeliverymap',"Blips!", {}, true, function(source, args)
    TriggerClientEvent('sd-deliveryjob:client:debugMap', -1)
    end, 'dev')
    