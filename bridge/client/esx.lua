local ESXBridge = {}
ESXBridge.__index = ESXBridge
local ESX = nil

function ESXBridge:Init()
    ESX = exports['es_extended']:getSharedObject()
    if not ESX then
        return false
    end
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        ESX.PlayerData = xPlayer
    end)
    RegisterNetEvent('esx:setJob', function(job)
        ESX.PlayerData.job = job
    end)
    return true
end

function ESXBridge:GetPlayerData()
    return ESX.GetPlayerData()
end

function ESXBridge:HasMoney(amount, moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    if moneyType == 'cash' then
        return playerData.money >= amount
    else
        for _, account in ipairs(playerData.accounts) do
            if account.name == moneyType then
                return account.money >= amount
            end
        end
    end
    return false
end

function ESXBridge:GetMoney(moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    if moneyType == 'cash' then
        return playerData.money or 0
    else
        for _, account in ipairs(playerData.accounts) do
            if account.name == moneyType then
                return account.money or 0
            end
        end
    end
    return 0
end

function ESXBridge:GetPlayerIdentifier()
    local playerData = self:GetPlayerData()
    return playerData.identifier
end

function ESXBridge:GetPlayerName()
    local playerData = self:GetPlayerData()
    return playerData.name or "Unknown"
end

function ESXBridge:GetFramework()
    return ESX
end

return ESXBridge