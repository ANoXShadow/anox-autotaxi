--[[------------------------>FOR ASSISTANCE,SCRIPTS AND MORE JOIN OUR DISCORD<-------------------------------------
 ________   ________    ________      ___    ___      ________   _________   ___  ___   ________   ___   ________     
|\   __  \ |\   ___  \ |\   __  \    |\  \  /  /|  ||  |\   ____\ |\___   ___\|\  \|\  \ |\   ___ \ |\  \ |\   __  \    
\ \  \|\  \\ \  \\ \  \\ \  \|\  \   \ \  \/  / /  ||  \ \  \___|_\|___ \  \_|\ \  \\\  \\ \  \_|\ \\ \  \\ \  \|\  \   
 \ \   __  \\ \  \\ \  \\ \  \\\  \   \ \    / /   ||   \ \_____  \    \ \  \  \ \  \\\  \\ \  \ \\ \\ \  \\ \  \\\  \  
  \ \  \ \  \\ \  \\ \  \\ \  \\\  \   /     \/    ||    \|____|\  \    \ \  \  \ \  \\\  \\ \  \_\\ \\ \  \\ \  \\\  \ 
   \ \__\ \__\\ \__\\ \__\\ \_______\ /  /\   \    ||      ____\_\  \    \ \__\  \ \_______\\ \_______\\ \__\\ \_______\
    \|__|\|__| \|__| \|__| \|_______|/__/ /\ __\   ||     |\_________\    \|__|   \|_______| \|_______| \|__| \|_______|
                                     |__|/ \|__|   ||     \|_________|                                                 
------------------------------------->(https://discord.gg/gbJ5SyBJBv)---------------------------------------------------]]
Config = {}
Config.Debug = false -- Enable debug logs
Config.Framework = 'auto' -- 'esx', 'qb', 'qbx','auto'
Config.Language = 'en' -- 'en'

Config.UISystem = {
    Notify = 'ox',           -- 'ox'
    TextUI = 'ox',           -- 'ox'
    AlertDialog = 'ox',      -- 'ox'
}

Config.target = 'ox'

Config.Taxi = {
    MaxActiveTaxis = 5,                      
    Models = {                               
        'taxi'
    },
    DriverModels = {
        'a_m_y_stlat_01',
        'a_m_m_socenlat_01',
        'a_m_m_eastsa_01',
        'a_m_m_indian_01'
    },
    PlateFormat = 'TAXI####',               -- # = number, @ = letter
    SpawnRadius = 100.0,                     -- Radius to search for spawn point
    MaxSpawnAttempts = 10,                   -- Max attempts to find valid spawn
    DrivingStyle = 786475,                   -- Normal driving with traffic lights
    MaxSpeed = 200.0,                         -- Max speed in m/s (72 km/h)
    StuckCheckInterval = 5000,               -- Check if stuck every 5 seconds
    StuckThreshold = 3.0,                    -- Distance threshold for stuck detection
    ArrivalDistance = 10.0                   -- Distance to consider arrived
}

Config.Fare = {
    BaseFare = 5,                          -- Base fare for calling taxi
    PerKmRate = 25,                         -- Cost per kilometer
    Currency = 'bank',                      -- Money type (cash/bank)
    PaymentOnArrival = true,                -- Pay when arriving (true) or when entering (false)
    ShowFareEstimate = true                 -- Show estimated fare before confirmation
}

Config.Cooldown = {
    CancelCooldown = 60,                    -- Seconds cooldown after cancelling
    LeaveCooldown = 60,                     -- Seconds cooldown after leaving mid-ride
    CommandCooldown = 5                     -- Seconds between command uses
}

Config.Blips = {
    ShowTaxiBlip = true,                    
    ShowRouteBlip = true,                  
    TaxiBlip = {
        Sprite = 198,
        Color = 5,
        Scale = 0.8,
        Label = 'Auto Taxi'
    },
    DestinationBlip = {
        Sprite = 1,
        Color = 5,
        Scale = 0.8,
        Label = 'Taxi Destination'
    }
}

Config.BlacklistedAreas = {
    {coords = vector3(105.34, -1940.68, 20.80), radius = 100.0},
}
