local QBXBridge = {}
QBXBridge.__index = QBXBridge

function QBXBridge:Init()
    if GetResourceState('qbx_core') ~= 'started' then
        return false
    end
    return true
end

function QBXBridge:GetPlayerData()
    return exports.qbx_core:GetPlayerData()
end

function QBXBridge:HasMoney(amount, moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    return playerData.money and playerData.money[moneyType] and playerData.money[moneyType] >= amount
end

function QBXBridge:GetMoney(moneyType)
    local playerData = self:GetPlayerData()
    moneyType = moneyType or 'cash'
    return playerData.money and playerData.money[moneyType] or 0
end

function QBXBridge:GetPlayerIdentifier()
    local playerData = self:GetPlayerData()
    return playerData.citizenid
end

function QBXBridge:GetPlayerName()
    local playerData = self:GetPlayerData()
    if playerData.charinfo then
        return playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
    end
    return "Unknown"
end

function QBXBridge:GetFramework()
    return 'qbx'
end

return QBXBridge