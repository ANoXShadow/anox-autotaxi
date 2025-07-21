local QBBridge = {}
QBBridge.__index = QBBridge
local QBCore = nil

function QBBridge:Init()
    QBCore = exports['qb-core']:GetCoreObject()
    if not QBCore then
        return false
    end
    return true
end

function QBBridge:GetPlayerData()
    return QBCore.Functions.GetPlayerData()
end

function QBBridge:HasMoney(amount, moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    return playerData.money and playerData.money[moneyType] and playerData.money[moneyType] >= amount
end

function QBBridge:GetMoney(moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    return playerData.money and playerData.money[moneyType] or 0
end

function QBBridge:GetPlayerIdentifier()
    local playerData = self:GetPlayerData()
    return playerData.citizenid
end

function QBBridge:GetPlayerName()
    local playerData = self:GetPlayerData()
    if playerData.charinfo then
        return playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
    end
    return "Unknown"
end

function QBBridge:GetFramework()
    return QBCore
end

return QBBridge