local Bridge = require('bridge.loader'):Load()
local activeTaxi = nil
local taxiDriver = nil
local taxiBlip = nil
local destinationBlip = nil
local isInTaxi = false
local tripStarted = false
local tripDistance = 0.0
local lastPosition = nil
local stuckCounter = 0
local lastStuckCheck = 0
local cooldownTime = 0
local awaitingDestination = false
local tripCost = 0
local pickupLocation = nil
local lastWaypointCoords = nil
local hasShownDestinationMessage = false
local taxiSpawnTime = 0
local taxiArrivalTimeout = 120000
local lastTeleportTime = 0
local teleportCooldown = 30000

local textUIState = {
    active = false,
    currentText = nil
}

local function ShowTaxiTextUI(text)
    if not textUIState.active or textUIState.currentText ~= text then
        textUIState.active = true
        textUIState.currentText = text
        Bridge.ShowTextUI(text, {style = 'taxi'})
    end
end

local function HideTaxiTextUI()
    if textUIState.active then
        textUIState.active = false
        textUIState.currentText = nil
        Bridge.HideTextUI()
    end
end

local function GeneratePlate()
    local plate = Config.Taxi.PlateFormat
    plate = plate:gsub('#', function() return tostring(math.random(0, 9)) end)
    plate = plate:gsub('@', function() return string.char(math.random(65, 90)) end)
    return plate
end

local function GetGroundZ(coords)
    local success, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    return success and z or coords.z
end

local function IsInBlacklistedArea(coords)
    for _, area in ipairs(Config.BlacklistedAreas) do
        if #(coords - area.coords) <= area.radius then
            return true
        end
    end
    return false
end

local function FindSafeSpawnPoint(playerCoords)
    if IsInBlacklistedArea(playerCoords) then
        return nil
    end
    for attempt = 1, Config.Taxi.MaxSpawnAttempts do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(50, Config.Taxi.SpawnRadius)
        local x = playerCoords.x + math.cos(angle) * distance
        local y = playerCoords.y + math.sin(angle) * distance
        local success, roadCoords, heading = GetClosestVehicleNodeWithHeading(x, y, playerCoords.z, 1, 3.0, 0)
        if success then
            roadCoords = vector3(roadCoords.x, roadCoords.y, GetGroundZ(roadCoords))
            if IsPointOnRoad(roadCoords.x, roadCoords.y, roadCoords.z, 0) and
               not IsInBlacklistedArea(roadCoords) and 
               #(playerCoords - roadCoords) > 30.0 and
               #(playerCoords - roadCoords) < Config.Taxi.SpawnRadius and
               not IsAnyVehicleNearPoint(roadCoords.x, roadCoords.y, roadCoords.z, 5.0) then
                return {coords = roadCoords, heading = heading}
            end
        end
    end
    return nil
end

local function TeleportTaxiToPlayer()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return false end
    local currentTime = GetGameTimer()
    if currentTime - lastTeleportTime < teleportCooldown then return false end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local newSpawnPoint = FindSafeSpawnPoint(playerCoords)
    if newSpawnPoint then
        ClearPedTasks(taxiDriver)
        SetEntityCoords(activeTaxi, newSpawnPoint.coords.x, newSpawnPoint.coords.y, newSpawnPoint.coords.z, false, false, false, true)
        SetEntityHeading(activeTaxi, newSpawnPoint.heading)
        SetVehicleOnGroundProperly(activeTaxi)
        TaskVehicleDriveToCoordLongrange(
            taxiDriver, activeTaxi, 
            playerCoords.x, playerCoords.y, playerCoords.z,
            Config.Taxi.MaxSpeed, Config.Taxi.DrivingStyle, 10.0
        )
        lastTeleportTime = currentTime
        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_relocated'), 'info')
        return true
    end
    return false
end

local function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        if #(coords - vehicleCoords) <= radius then
            table.insert(vehicles, vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return vehicles
end

local function CheckTaxiArrival()
    if not activeTaxi or not DoesEntityExist(activeTaxi) or isInTaxi or tripStarted then return end
    local currentTime = GetGameTimer()
    local timeSinceSpawn = currentTime - taxiSpawnTime
    local playerCoords = GetEntityCoords(PlayerPedId())
    local taxiCoords = GetEntityCoords(activeTaxi)
    local distanceToPlayer = #(playerCoords - taxiCoords)
    local taxiSpeed = GetEntitySpeed(activeTaxi)
    local isAtTrafficLight = IsVehicleStoppedAtTrafficLights(activeTaxi)
    local forwardVector = GetEntityForwardVector(activeTaxi)
    local frontCoords = taxiCoords + forwardVector * 15.0
    local vehiclesAhead = GetVehiclesInArea(frontCoords, 10.0)
    local isWaitingInTraffic = #vehiclesAhead > 1
    local isLegitimateStop = isAtTrafficLight or isWaitingInTraffic
    if taxiSpeed > 5.0 or isLegitimateStop then
        return
    end
    if timeSinceSpawn > taxiArrivalTimeout then
        if distanceToPlayer > 100.0 then
            if TeleportTaxiToPlayer() then
                taxiSpawnTime = currentTime
                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_taking_too_long'), 'warning')
            end
        end
    elseif timeSinceSpawn > (taxiArrivalTimeout / 2) and distanceToPlayer > 200.0 then
        if taxiSpeed < 1.0 then
            TeleportTaxiToPlayer()
        end
    end
end

local function CreateBlip(entity, coords, config)
    local blip = entity and AddBlipForEntity(entity) or AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, config.Sprite)
    SetBlipColour(blip, config.Color)
    SetBlipScale(blip, config.Scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(config.Label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function CleanupTaxi()
    if taxiBlip then RemoveBlip(taxiBlip) end
    if destinationBlip then RemoveBlip(destinationBlip) end
    if taxiDriver and DoesEntityExist(taxiDriver) then DeleteEntity(taxiDriver) end
    if activeTaxi and DoesEntityExist(activeTaxi) then DeleteEntity(activeTaxi) end
    taxiBlip = nil
    destinationBlip = nil
    taxiDriver = nil
    activeTaxi = nil
    isInTaxi = false
    tripStarted = false
    tripDistance = 0.0
    lastPosition = nil
    stuckCounter = 0
    lastStuckCheck = 0
    awaitingDestination = false
    tripCost = 0
    pickupLocation = nil
    lastWaypointCoords = nil
    hasShownDestinationMessage = false
    taxiSpawnTime = 0
    lastTeleportTime = 0
    HideTaxiTextUI()
end

local function CalculateFare(distance)
    local distanceKm = distance / 1000
    return math.floor(Config.Fare.BaseFare + (distanceKm * Config.Fare.PerKmRate))
end

local function HandleStuckTaxi()
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    local currentTime = GetGameTimer()
    if currentTime - lastStuckCheck < Config.Taxi.StuckCheckInterval then return end
    lastStuckCheck = currentTime
    local taxiCoords = GetEntityCoords(activeTaxi)
    if lastPosition then
        local distance = #(taxiCoords - lastPosition)
        local taxiSpeed = GetEntitySpeed(activeTaxi)
        local isAtTrafficLight = IsVehicleStoppedAtTrafficLights(activeTaxi)
        local isWaitingInTraffic = false
        local forwardVector = GetEntityForwardVector(activeTaxi)
        local frontCoords = taxiCoords + forwardVector * 15.0
        local vehiclesAhead = GetVehiclesInArea(frontCoords, 10.0)
        if #vehiclesAhead > 1 then
            isWaitingInTraffic = true
        end
        local isLegitimateStop = isAtTrafficLight or isWaitingInTraffic
        local isStuck = distance < Config.Taxi.StuckThreshold and 
                       taxiSpeed < 1.5 and 
                       not isLegitimateStop and
                       not IsVehicleOnAllWheels(activeTaxi) == false 
        if isStuck then
            stuckCounter = stuckCounter + 1
            if stuckCounter >= 8 then
                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.stuck_message'), 'info')
                ClearPedTasks(taxiDriver)
                Wait(500)
                SetVehicleForwardSpeed(activeTaxi, -8.0)
                Wait(2000)
                if tripStarted and destinationBlip then
                    local destination = GetBlipCoords(destinationBlip)
                    TaskVehicleDriveToCoordLongrange(
                        taxiDriver, activeTaxi, 
                        destination.x, destination.y, destination.z,
                        Config.Taxi.MaxSpeed, Config.Taxi.DrivingStyle, 
                        Config.Taxi.ArrivalDistance
                    )
                elseif not tripStarted then
                    TeleportTaxiToPlayer()
                end
                stuckCounter = 0
            end
        else
            stuckCounter = math.max(0, stuckCounter - 1)
        end
    end
    lastPosition = taxiCoords
end

local function EnsureTaxiUnlocked()
    if activeTaxi and DoesEntityExist(activeTaxi) then
        SetVehicleDoorsLocked(activeTaxi, 0)
        SetVehicleDoorsLockedForAllPlayers(activeTaxi, false)
        SetVehicleDoorsLockedForPlayer(activeTaxi, PlayerId(), false)
        SetVehicleNeedsToBeHotwired(activeTaxi, false)
        SetVehicleHasBeenOwnedByPlayer(activeTaxi, false)
    end
end

local function SpawnTaxi(spawnPoint)
    local model = Config.Taxi.Models[math.random(#Config.Taxi.Models)]
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end
    activeTaxi = CreateVehicle(modelHash, spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, spawnPoint.heading, true, true)
    SetModelAsNoLongerNeeded(modelHash)
    SetVehicleNumberPlateText(activeTaxi, GeneratePlate())
    SetVehicleOnGroundProperly(activeTaxi)
    SetEntityAsMissionEntity(activeTaxi, true, true)
    SetVehicleEngineOn(activeTaxi, true, true, false)
    SetVehicleDoorsLocked(activeTaxi, 0)
    SetVehicleDoorsLockedForAllPlayers(activeTaxi, false)
    SetVehicleDoorsLockedForPlayer(activeTaxi, PlayerId(), false)
    SetVehicleNeedsToBeHotwired(activeTaxi, false)
    SetVehicleHasBeenOwnedByPlayer(activeTaxi, false)
    if GetResourceState('qb-vehiclekeys') == 'started' then
    TriggerEvent('qb-vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(activeTaxi))
    end
    local driverModel = Config.Taxi.DriverModels[math.random(#Config.Taxi.DriverModels)]
    local driverHash = GetHashKey(driverModel)
    RequestModel(driverHash)
    while not HasModelLoaded(driverHash) do Wait(10) end
    taxiDriver = CreatePedInsideVehicle(activeTaxi, 26, driverHash, -1, true, true)
    SetModelAsNoLongerNeeded(driverHash)
    SetEntityAsMissionEntity(taxiDriver, true, true)
    SetBlockingOfNonTemporaryEvents(taxiDriver, true)
    SetPedCanBeDraggedOut(taxiDriver, false)
    SetPedConfigFlag(taxiDriver, 251, true)
    SetPedAlertness(taxiDriver, 0)
    if Config.Blips.ShowTaxiBlip then
        taxiBlip = CreateBlip(activeTaxi, nil, Config.Blips.TaxiBlip)
    end
    local playerCoords = GetEntityCoords(PlayerPedId())
    TaskVehicleDriveToCoordLongrange(
        taxiDriver, activeTaxi, 
        playerCoords.x, playerCoords.y, playerCoords.z,
        Config.Taxi.MaxSpeed, Config.Taxi.DrivingStyle, 10.0
    )
    taxiSpawnTime = GetGameTimer()
    CreateThread(function()
        while activeTaxi and DoesEntityExist(activeTaxi) do
            EnsureTaxiUnlocked()
            Wait(1000)
        end
    end)
    CreateThread(function()
        while activeTaxi and DoesEntityExist(activeTaxi) and not isInTaxi do
            CheckTaxiArrival()
            Wait(5000)
        end
    end)
    return true
end

local function StartTaxiTrip(destination)
    if not activeTaxi or not DoesEntityExist(activeTaxi) then return end
    tripStarted = true
    lastPosition = GetEntityCoords(activeTaxi)
    local found, roadCoords = GetClosestVehicleNode(destination.x, destination.y, destination.z, 1, 3.0, 0)
    local roadDestination = found and vector3(roadCoords.x, roadCoords.y, roadCoords.z) or destination
    destinationBlip = CreateBlip(nil, roadDestination, Config.Blips.DestinationBlip)
    if Config.Blips.ShowRouteBlip then
        SetBlipRoute(destinationBlip, true)
        SetBlipRouteColour(destinationBlip, Config.Blips.DestinationBlip.Color)
    end
    TaskVehicleDriveToCoordLongrange(
        taxiDriver, activeTaxi, 
        roadDestination.x, roadDestination.y, roadDestination.z,
        Config.Taxi.MaxSpeed, Config.Taxi.DrivingStyle, 
        Config.Taxi.ArrivalDistance
    )
    CreateThread(function()
        while tripStarted and activeTaxi and DoesEntityExist(activeTaxi) do
            Wait(1000)
            if not isInTaxi then
                local partialFare = CalculateFare(tripDistance)
                if partialFare > Config.Fare.BaseFare then
                    lib.callback('anox-autotaxi:server:payPartialFare', false, function(success)
                        if not success and pickupLocation then
                            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.insufficient_funds'), 'error')
                            SetTimeout(500, function()
                                SetEntityCoords(PlayerPedId(), pickupLocation.x, pickupLocation.y, pickupLocation.z, false, false, false, true)
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.teleported_back'), 'warning')
                            end)
                        elseif success then
                            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.left_taxi_early'), 'info')
                        end
                        cooldownTime = GetGameTimer() + (Config.Cooldown.LeaveCooldown * 1000)
                    end, partialFare)
                else
                    lib.callback('anox-autotaxi:server:checkFunds', false, function(hasFunds)
                        if not hasFunds and pickupLocation then
                            SetTimeout(500, function()
                                SetEntityCoords(PlayerPedId(), pickupLocation.x, pickupLocation.y, pickupLocation.z, false, false, false, true)
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.teleported_back'), 'warning')
                            end)
                        end
                    end, Config.Fare.BaseFare)
                end
                SetTimeout(1000, function()
                    CleanupTaxi()
                end)
                break
            end
            local currentPos = GetEntityCoords(activeTaxi)
            if lastPosition then
                tripDistance = tripDistance + #(currentPos - lastPosition)
            end
            lastPosition = currentPos
            tripCost = CalculateFare(tripDistance)
            ShowTaxiTextUI(_L('ui.trip_cost_distance', tripCost, tripDistance / 1000))
            HandleStuckTaxi()
            if #(currentPos - roadDestination) < Config.Taxi.ArrivalDistance then
                tripStarted = false
                TaskVehiclePark(taxiDriver, activeTaxi, roadDestination.x, roadDestination.y, roadDestination.z, GetEntityHeading(activeTaxi), 1, 20.0, false)
                HideTaxiTextUI()
                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.trip_complete', tripCost), 'success')
                lib.callback('anox-autotaxi:server:payFare', false, function(success)
                    if not success and pickupLocation then
                        SetEntityCoords(PlayerPedId(), pickupLocation.x, pickupLocation.y, pickupLocation.z, false, false, false, true)
                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.teleported_back'), 'warning')
                    end
                end, tripCost)
                SetTimeout(5000, CleanupTaxi)
                break
            end
        end
    end)
end

CreateThread(function()
    while true do
        Wait(1000)
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle ~= 0 and vehicle == activeTaxi then
            if not isInTaxi then
                local inBackSeat = GetPedInVehicleSeat(vehicle, 1) == playerPed or GetPedInVehicleSeat(vehicle, 2) == playerPed
                if not inBackSeat then
                    TaskLeaveVehicle(playerPed, vehicle, 0)
                    Bridge.Notify(nil, 'Auto Taxi', _L('notifications.enter_back_seat'), 'error')
                else
                    isInTaxi = true
                    hasShownDestinationMessage = false
                    pickupLocation = pickupLocation or GetEntityCoords(playerPed)
                    if not tripStarted and awaitingDestination and not hasShownDestinationMessage then
                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.mark_destination'), 'info')
                        hasShownDestinationMessage = true
                    end
                end
            end
        elseif isInTaxi then
            isInTaxi = false
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        if awaitingDestination and isInTaxi and not tripStarted then
            local waypoint = GetFirstBlipInfoId(8)
            if DoesBlipExist(waypoint) then
                local waypointCoords = GetBlipInfoIdCoord(waypoint)
                if not lastWaypointCoords or #(vector3(waypointCoords.x, waypointCoords.y, 0) - vector3(lastWaypointCoords.x, lastWaypointCoords.y, 0)) > 5.0 then
                    lastWaypointCoords = waypointCoords
                    local destination = vector3(waypointCoords.x, waypointCoords.y, GetGroundZ(vector3(waypointCoords.x, waypointCoords.y, 100.0)))
                    local content = _L('dialogs.confirm_destination_content')
                    if Config.Fare.ShowFareEstimate then
                        local estimatedDistance = #(GetEntityCoords(PlayerPedId()) - destination)
                        local estimatedFare = CalculateFare(estimatedDistance)
                        content = _L('dialogs.confirm_destination_with_fare', _L('notifications.estimated_fare', estimatedFare))
                    end
                    local result = Bridge.AlertDialog({
                        header = _L('dialogs.confirm_destination_header'),
                        content = content,
                        labels = {
                            confirm = _L('dialogs.confirm_yes'),
                            cancel = _L('dialogs.confirm_no')
                        }
                    })
                    if result == 'confirm' then
                        awaitingDestination = false
                        lastWaypointCoords = nil
                        StartTaxiTrip(destination)
                        SetWaypointOff()
                    else
                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.mark_different_destination'), 'info')
                    end
                end
            else
                lastWaypointCoords = nil
            end
        else
            lastWaypointCoords = nil
            Wait(1000)
        end
    end
end)

RegisterCommand('autotaxi', function()
    if cooldownTime > GetGameTimer() then
        local remaining = math.ceil((cooldownTime - GetGameTimer()) / 1000)
        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.on_cooldown', remaining), 'error')
        return
    end
    if activeTaxi and DoesEntityExist(activeTaxi) then
        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.already_have_taxi'), 'error')
        return
    end
    cooldownTime = GetGameTimer() + (Config.Cooldown.CommandCooldown * 1000)
    lib.callback('anox-autotaxi:server:requestTaxi', false, function(canSpawn)
        if not canSpawn then
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.max_taxis_reached'), 'error')
            return
        end
        local playerCoords = GetEntityCoords(PlayerPedId())
        if IsInBlacklistedArea(playerCoords) then
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.cannot_call_here'), 'error')
            lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
            return
        end
        local spawnPoint = FindSafeSpawnPoint(playerCoords)
        if not spawnPoint then
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.no_spawn_location'), 'error')
            lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
            return
        end
        if SpawnTaxi(spawnPoint) then
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_called'), 'success')
            awaitingDestination = true
            pickupLocation = playerCoords
            CreateThread(function()
                while activeTaxi and DoesEntityExist(activeTaxi) and not isInTaxi do
                    Wait(1000)
                    if #(playerCoords - GetEntityCoords(activeTaxi)) < 20.0 then
                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_arrived'), 'success')
                        break
                    end
                end
            end)
        else
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.failed_to_spawn'), 'error')
            lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
        end
    end)
end, false)

RegisterCommand('canceltaxi', function()
    if activeTaxi and DoesEntityExist(activeTaxi) then
        if tripStarted then
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.cannot_cancel_during_trip'), 'error')
        else
            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_cancelled'), 'info')
            cooldownTime = GetGameTimer() + (Config.Cooldown.CancelCooldown * 1000)
            lib.callback('anox-autotaxi:server:cancelTaxi', false, function() end)
            CleanupTaxi()
        end
    end
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupTaxi()
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        HideTaxiTextUI()
    end
end)

local phoneModels = { "p_phonebox_03", "p_phonebox_02_s", "prop_phonebox_04", "prop_phonebox_01a", "prop_phonebox_02" } 
local phoneModelHashes = {} for _, name in ipairs(phoneModels) do
    phoneModelHashes[#phoneModelHashes+1] = joaat(name)
end

local phoneOptionsOx = {
    name = "phone_interaction",
    icon = "fas fa-phone",
    label = "Use Phone",
    distance = 2.5,
    canInteract = function(entity, distance, coords, name)
        return not IsPedInAnyVehicle(PlayerPedId(), true)
    end,
    onSelect = function(data)
        lib.registerContext({
            id = 'call_menu',
            title = 'Who would you like to call?',
            options = {
                {
                    title = 'Taxi',
                    description = 'Call a taxi service',
                    icon = 'fa-solid fa-taxi',
                    onSelect = function()
                        if cooldownTime > GetGameTimer() then
                            local remaining = math.ceil((cooldownTime - GetGameTimer()) / 1000)
                            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.on_cooldown', remaining), 'error')
                            return
                        end
                        if activeTaxi and DoesEntityExist(activeTaxi) then
                            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.already_have_taxi'), 'error')
                            return
                        end
                        cooldownTime = GetGameTimer() + (Config.Cooldown.CommandCooldown * 1000)
                        lib.callback('anox-autotaxi:server:requestTaxi', false, function(canSpawn)
                            if not canSpawn then
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.max_taxis_reached'), 'error')
                                return
                            end
                            local playerCoords = GetEntityCoords(PlayerPedId())
                            if IsInBlacklistedArea(playerCoords) then
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.cannot_call_here'), 'error')
                                lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                                return
                            end
                            local spawnPoint = FindSafeSpawnPoint(playerCoords)
                            if not spawnPoint then
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.no_spawn_location'), 'error')
                                lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                                return
                            end
                            if SpawnTaxi(spawnPoint) then
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_called'), 'success')
                                awaitingDestination = true
                                pickupLocation = playerCoords
                                CreateThread(function()
                                    while activeTaxi and DoesEntityExist(activeTaxi) and not isInTaxi do
                                        Wait(1000)
                                        if #(playerCoords - GetEntityCoords(activeTaxi)) < 20.0 then
                                            Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_arrived'), 'success')
                                            break
                                        end
                                    end
                                end)
                            else
                                Bridge.Notify(nil, 'Auto Taxi', _L('notifications.failed_to_spawn'), 'error')
                                lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                            end
                        end)
                    end, false}
                }})
                lib.showContext('call_menu')
            end
}

local phoneOptionsQB = {
    options = {
        {
            name = "phone_interaction",
            icon = "fas fa-phone",
            label = "Use Phone",
            action = function(entity)
                lib.registerContext({
                    id = 'call_menu',
                    title = 'Who would you like to call?',
                    options = {
                        {
                            title = 'Taxi',
                            description = 'Call a taxi service',
                            icon = 'fa-solid fa-taxi',
                            onSelect = function()
                                if cooldownTime > GetGameTimer() then
                                    local remaining = math.ceil((cooldownTime - GetGameTimer()) / 1000)
                                    Bridge.Notify(nil, 'Auto Taxi', _L('notifications.on_cooldown', remaining), 'error')
                                    return
                                end
                                if activeTaxi and DoesEntityExist(activeTaxi) then
                                    Bridge.Notify(nil, 'Auto Taxi', _L('notifications.already_have_taxi'), 'error')
                                    return
                                end
                                cooldownTime = GetGameTimer() + (Config.Cooldown.CommandCooldown * 1000)
                                lib.callback('anox-autotaxi:server:requestTaxi', false, function(canSpawn)
                                    if not canSpawn then
                                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.max_taxis_reached'), 'error')
                                        return
                                    end
                                    local playerCoords = GetEntityCoords(PlayerPedId())
                                    if IsInBlacklistedArea(playerCoords) then
                                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.cannot_call_here'), 'error')
                                        lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                                        return
                                    end
                                    local spawnPoint = FindSafeSpawnPoint(playerCoords)
                                    if not spawnPoint then
                                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.no_spawn_location'), 'error')
                                        lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                                        return
                                    end
                                    if SpawnTaxi(spawnPoint) then
                                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_called'), 'success')
                                        awaitingDestination = true
                                        pickupLocation = playerCoords
                                        CreateThread(function()
                                            while activeTaxi and DoesEntityExist(activeTaxi) and not isInTaxi do
                                                Wait(1000)
                                                if #(playerCoords - GetEntityCoords(activeTaxi)) < 20.0 then
                                                    Bridge.Notify(nil, 'Auto Taxi', _L('notifications.taxi_arrived'), 'success')
                                                    break
                                                end
                                            end
                                        end)
                                    else
                                        Bridge.Notify(nil, 'Auto Taxi', _L('notifications.failed_to_spawn'), 'error')
                                        lib.callback('anox-autotaxi:server:taxiFailed', false, function() end)
                                    end
                                end)
                            end
                        }
                    }
                })
                lib.showContext('call_menu')
            end,
            canInteract = function(entity, distance, data)
                return not IsPedInAnyVehicle(PlayerPedId(), true)
            end
        }
    },
    distance = 2.5
}

CreateThread(function()
if Config.target == "ox" then
    while GetResourceState('ox_target') ~= 'started' do Wait(100) end
    exports.ox_target:addModel(phoneModels, phoneOptionsOx)
elseif Config.target == "qb" then
        while GetResourceState('qb-target') ~= 'started' do Wait(100) end
        exports['qb-target']:AddTargetModel(phoneModels, phoneOptionsQB)
    end
end)
