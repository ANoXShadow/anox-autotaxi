local QBXBridge = {}
QBXBridge.__index = QBXBridge

function QBXBridge:Init()
    if GetResourceState('qbx_core') ~= 'started' then
        return false
    end
    return true
end

function QBXBridge:GetPlayer(playerId)
    return exports.qbx_core:GetPlayer(playerId)
end

function QBXBridge:GetPlayerFromIdentifier(identifier)
    return exports.qbx_core:GetPlayerByCitizenId(identifier)
end

function QBXBridge:AddMoney(playerId, amount, moneyType)
    local Player = self:GetPlayer(playerId)
    if not Player then return false end
    
    moneyType = moneyType or 'cash'
    Player.Functions.AddMoney(moneyType, amount)
    return true
end

function QBXBridge:RemoveMoney(playerId, amount, moneyType)
    local Player = self:GetPlayer(playerId)
    if not Player then return false end
    
    moneyType = moneyType or 'cash'
    Player.Functions.RemoveMoney(moneyType, amount)
    return true
end

function QBXBridge:GetMoney(playerId, moneyType)
    local Player = self:GetPlayer(playerId)
    if not Player then return 0 end
    
    moneyType = moneyType or 'cash'
    return Player.PlayerData.money[moneyType] or 0
end

function QBXBridge:HasMoney(playerId, amount, moneyType)
    return self:GetMoney(playerId, moneyType) >= amount
end

function QBXBridge:GetPlayerIdentifier(playerId)
    local Player = self:GetPlayer(playerId)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

function QBXBridge:GetPlayerName(playerId)
    local Player = self:GetPlayer(playerId)
    if not Player then return "Unknown" end
    return Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
end

function QBXBridge:GetFramework()
    return 'qbx'
end

return QBXBridge