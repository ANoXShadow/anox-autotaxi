local Bridge = require('bridge.loader'):Load()
local activeTaxis = {}

local function GetActiveTaxiCount()
    local count = 0
    for _, active in pairs(activeTaxis) do
        if active then count = count + 1 end
    end
    return count
end

local function RemoveActiveTaxi(source)
    activeTaxis[source] = nil
    Bridge.Debug('Removed active taxi for player ' .. source, 'info')
end

lib.callback.register('anox-autotaxi:server:requestTaxi', function(source)
    if activeTaxis[source] then
        return false
    end
    if GetActiveTaxiCount() >= Config.Taxi.MaxActiveTaxis then
        return false
    end
    activeTaxis[source] = true
    Bridge.Debug('Player ' .. source .. ' requested taxi', 'info')
    return true
end)

lib.callback.register('anox-autotaxi:server:checkFunds', function(source, amount)
    return Bridge:HasMoney(source, amount, Config.Fare.Currency)
end)

lib.callback.register('anox-autotaxi:server:payFare', function(source, fare)
    if type(fare) ~= 'number' or fare < Config.Fare.BaseFare or fare > 10000 then
        Bridge.Debug('Invalid fare from player ' .. source, 'warning')
        RemoveActiveTaxi(source)
        return false
    end
    if not activeTaxis[source] then
        Bridge.Debug('Player ' .. source .. ' tried to pay without active taxi', 'warning')
        return false
    end
    if Bridge:HasMoney(source, fare, Config.Fare.Currency) then
        Bridge:RemoveMoney(source, fare, Config.Fare.Currency)
        Bridge.Notify(source, 'Auto Taxi', _L('notifications.payment_successful'), 'success')
        Bridge.Debug('Player ' .. source .. ' paid ' .. fare .. ' for taxi', 'success')
        RemoveActiveTaxi(source)
        return true
    else
        Bridge.Notify(source, 'Auto Taxi', _L('notifications.insufficient_funds'), 'error')
        RemoveActiveTaxi(source)
        return false
    end
end)

lib.callback.register('anox-autotaxi:server:payPartialFare', function(source, fare)
    if type(fare) ~= 'number' or fare < 0 or fare > 10000 then
        Bridge.Debug('Invalid partial fare from player ' .. source, 'warning')
        RemoveActiveTaxi(source)
        return false
    end
    if not activeTaxis[source] then
        Bridge.Debug('Player ' .. source .. ' tried to pay partial fare without active taxi', 'warning')
        return false
    end
    local success = false
    if fare > 0 and Bridge:HasMoney(source, fare, Config.Fare.Currency) then
        Bridge:RemoveMoney(source, fare, Config.Fare.Currency)
        Bridge.Notify(source, 'Auto Taxi', _L('notifications.partial_fare_paid', fare), 'warning')
        Bridge.Debug('Player ' .. source .. ' paid partial fare ' .. fare, 'warning')
        success = true
    else
        Bridge.Debug('Player ' .. source .. ' has insufficient funds for partial fare ' .. fare, 'warning')
        success = false
    end
    RemoveActiveTaxi(source)
    return success
end)

lib.callback.register('anox-autotaxi:server:cancelTaxi', function(source)
    RemoveActiveTaxi(source)
    return true
end)

lib.callback.register('anox-autotaxi:server:taxiFailed', function(source)
    RemoveActiveTaxi(source)
    return true
end)

AddEventHandler('playerDropped', function()
    RemoveActiveTaxi(source)
end)