local Bridge = {}
Bridge.__index = Bridge
local isClient = IsDuplicityVersion() == false
local isServer = not isClient

function Bridge.Debug(msg, level)
    if not Config or not Config.Debug then return end
    local prefix = '^3[anox-autotaxi]^7'
    local levelColors = {
        info = '^7',
        success = '^2',
        warning = '^3',
        error = '^1'
    }
    local color = levelColors[level] or '^7'
    print(prefix .. ' ' .. color .. msg .. '^7')
end

local UIPresets = {
    notify = {
        default = {
            backgroundColor = '#1E1E2F',
            boxShadow = '0 0 12px rgba(96, 165, 250, 0.4)',
            color = '#A0A0FF',
            position = 'center-right',
            duration = 6000,
            icon = 'taxi'
        },
        error = {
            backgroundColor = '#2F1E1E',
            boxShadow = '0 0 12px rgba(250, 96, 96, 0.4)',
            color = '#FF5C5C',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-exclamation'
        },
        success = {
            backgroundColor = '#1E2F1E',
            boxShadow = '0 0 12px rgba(132, 250, 96, 0.4)',
            color = '#6CFF7F',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-check'
        },
        info = {
            backgroundColor = '#1E1E2F',
            boxShadow = '0 0 12px rgba(96, 165, 250, 0.4)',
            color = '#58C5FF',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-info'
        },
        warning = {
            backgroundColor = '#2F2A1E',
            boxShadow = '0 0 12px rgba(250, 227, 96, 0.4)',
            color = '#FFD966',
            position = 'center-right',
            duration = 6000,
            icon = 'triangle-exclamation'
        }
    },
    textUI = {
        default = {
            backgroundColor = '#1E1E2F',
            position = 'top-center',
            icon = 'info-circle',
            iconColor = '#A0A0FF'
        },
        taxi = {
            backgroundColor = '#2F2A1E',
            position = 'top-center',
            icon = 'taxi',
            iconColor = '#FFD966'
        }
    }
}

function Bridge.Notify(source, title, description, type, duration)
    local success, err = pcall(function()
        local notifyType = type or 'info'
        local notifyStyle = UIPresets.notify[notifyType] or UIPresets.notify.default
        local msgTitle = title or 'Notification'
        local msgDesc = tostring(description or '')
        local notifyDuration = duration or notifyStyle.duration or 6000
        local style = {
            backgroundColor = notifyStyle.backgroundColor or '#000000',
            color = notifyStyle.color or '#FFD700',
            borderRadius = 14,
            fontSize = '16px',
            fontWeight = 'bold',
            textAlign = 'left',
            padding = '14px 20px',
            border = '1px solid ' .. (notifyStyle.color or '#FFD700'),
            letterSpacing = '0.5px'
        }
        if not source then
            style.boxShadow = notifyStyle.boxShadow
        end
        if Config.UISystem.Notify == 'ox' then
            local notifyData = {
                title = msgTitle,
                description = msgDesc,
                type = notifyType,
                icon = notifyStyle.icon,
                style = style,
                position = notifyStyle.position or 'top-right',
                duration = notifyDuration
            }
            if source then
                TriggerClientEvent('ox_lib:notify', source, notifyData)
            else
                lib.notify(notifyData)
            end
        else
            if isClient and not source then
                BeginTextCommandThefeedPost('STRING')
                AddTextComponentSubstringPlayerName(msgTitle .. '\n' .. msgDesc)
                EndTextCommandThefeedPostTicker(false, false)
            else
                Bridge.Debug('NOTIFY: ' .. msgTitle .. ' - ' .. msgDesc, 'info')
            end
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.Notify: ' .. tostring(err), 'error')
    end
end

function Bridge.ShowTextUI(text, options)
    if not isClient then return end
    local success, err = pcall(function()
        options = options or {}
        local styleKey = options.style or 'default'
        local textUIStyle = UIPresets.textUI[styleKey] or UIPresets.textUI.default
        if Config.UISystem.TextUI == 'ox' then
            local resourceName = GetInvokingResource() or GetCurrentResourceName()
            lib.showTextUI(text, {
                position = textUIStyle.position or 'top-center',
                icon = options.icon or textUIStyle.icon,
                iconColor = options.iconColor or textUIStyle.iconColor or '#ffffff',
                iconAnimation = options.iconAnimation or 'beat',
                style = {
                    backgroundColor = textUIStyle.backgroundColor or '#000000',
                    color = textUIStyle.iconColor or '#ffffff',
                    borderRadius = 6,
                    border = '1px solid ' .. (textUIStyle.iconColor or '#ffffff'),
                    fontSize = '15px',
                    fontWeight = '600',
                    padding = '8px 16px',
                    letterSpacing = '0.5px',
                }
            })
        else
            Bridge.Debug('TextUI: ' .. text, 'info')
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.ShowTextUI: ' .. tostring(err), 'error')
    end
end

function Bridge.HideTextUI()
    if not isClient then return end
    local success, err = pcall(function()
        if Config.UISystem.TextUI == 'ox' then
            lib.hideTextUI()
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.HideTextUI: ' .. tostring(err), 'error')
    end
end

function Bridge.AlertDialog(options)
    if not isClient then return 'confirm' end
    local success, result = pcall(function()
        options = options or {}
        if Config.UISystem.AlertDialog == 'ox' then
            return lib.alertDialog({
                header = options.header or 'Alert',
                content = options.content or '',
                centered = options.centered ~= nil and options.centered or true,
                cancel = options.cancel ~= nil and options.cancel or true,
                labels = options.labels or {
                    confirm = 'Yes',
                    cancel = 'No'
                }
            })
        else
            Bridge.Debug('AlertDialog: ' .. (options.header or 'Alert'), 'info')
            return 'confirm'
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.AlertDialog: ' .. tostring(result), 'error')
    end
    return result or 'confirm'
end

function Bridge.Load()
    if not Config then
        Bridge.Debug('Config not found', 'error')
        return nil
    end
    local framework = nil
    local frameworkMap = {
        ['esx'] = 'esx',
        ['qb'] = 'qb', 
        ['qbx'] = 'qbx'
    }
    if Config.Framework and Config.Framework ~= 'auto' and Config.Framework ~= 'autodetect' then
        framework = frameworkMap[string.lower(Config.Framework)]
        if not framework then
            Bridge.Debug('Unknown framework specified: ' .. Config.Framework, 'error')
            return nil
        end
    else
        if GetResourceState('es_extended') == 'started' then
            framework = 'esx'
        elseif GetResourceState('qbx_core') == 'started' then
            framework = 'qbx'
        elseif GetResourceState('qb-core') == 'started' then
            framework = 'qb'
        else
            Bridge.Debug('No supported framework detected', 'error')
            return nil
        end
    end
    local context = isClient and 'client' or 'server'
    local bridgePath = ('bridge/%s/%s'):format(context, framework)
    local success, frameworkBridge = pcall(require, bridgePath)
    if not success or not frameworkBridge then
        Bridge.Debug('Failed to load bridge module: ' .. bridgePath, 'error')
        return nil
    end
    if frameworkBridge.Init and type(frameworkBridge.Init) == 'function' then
        if not frameworkBridge:Init() then
            Bridge.Debug('Failed to initialize ' .. framework .. ' bridge', 'error')
            return nil
        end
        Bridge.Debug('Successfully initialized ' .. framework .. ' bridge', 'success')
    else
        Bridge.Debug('Loaded ' .. framework .. ' bridge', 'success')
    end
    return setmetatable({
        Notify = Bridge.Notify,
        ShowTextUI = Bridge.ShowTextUI,
        HideTextUI = Bridge.HideTextUI,
        AlertDialog = Bridge.AlertDialog,
        Debug = Bridge.Debug,
        Framework = framework,
        IsClient = isClient,
        IsServer = isServer
    }, {
        __index = function(t, k)
            return frameworkBridge[k] or Bridge[k]
        end
    })
end

return Bridge