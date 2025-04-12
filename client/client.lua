local QBCore = exports['qb-core']:GetCoreObject()
local useDebug = false

local OnRun = false
local RunType = ''
local Blip = nil
local LocationBlip = nil
local CurrentCompany = nil
local Entities = {}

-- For FeedStars
local PickingUp = false
local PickupLocation = ''
local Freelancing = false

AddEventHandler('onResourceStop', function (resource)
   if resource ~= GetCurrentResourceName() then return end
   for i, entity in pairs(Entities) do
       print('deleting', entity)
       if DoesEntityExist(entity) then
          DeleteEntity(entity)
       end
    end
end)

local function getDeliveryLocationByDistance()
    local chance = math.random(1,10)
    if chance > 1 then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closest = math.random(1,#Config.DeliverySpots)
        for i = 2, 60, 1 do
            local nextLocation = Config.DeliverySpots[math.random(1,#Config.DeliverySpots)]
            local distance = GetDistanceBetweenCoords(playerCoords, nextLocation.coords) 
            if distance < Config.MaxDistance then
                closest = nextLocation
            end
        end
        return closest
    else
        return Config.DeliverySpots[math.random(1, #Config.DeliverySpots)]
    end
end

local function deliverItem(spot, item, prop)
    exports['qb-target']:RemoveZone('delivery')
    TriggerEvent('animations:client:EmoteCommandStart', {"pickup"})
    Wait(500)
    local bagEntity = CreateObject(prop, spot.coords.x, spot.coords.y, spot.coords.z, false,  false, true)
    SetEntityHeading(bagEntity, math.random(1,180))
    FreezeEntityPosition(bagEntity, true)
    SetEntityAsMissionEntity(bagEntity)
    PlaceObjectOnGroundProperly(bagEntity)
    SetEntityCollision(bagEntity, false, true)
    SetEntityCanBeDamaged(bagEntity, false)
    SetEntityInvincible(bagEntity, true)

    SetTimeout(Config.BagRemovalTime, function()
        DeleteObject(bagEntity)
        if RunType == 'bag' then
            exports['qb-phone']:PhoneNotification("FeedStars", 'Good job! ♥ 🍪', 'fas fa-star', '#eec64e', 5000)
        else
            exports['qb-phone']:PhoneNotification("FeedStars", 'Package marked as recieved', 'fas fa-star', '#eec64e', 5000)
        end
    end)

    TriggerServerEvent('sd-deliveryjob:server:turnInFood', item, Freelancing, CurrentCompany)
    RemoveBlip(Blip)
    OnRun = false
    Freelancing = false
    exports["mz-skills"]:UpdateSkill("Food Delivery", 1)
    CurrentCompany = nil
end

local function createDeliveryBox(spot, item, prop)
    CreateThread(function()
        if OnRun then
            exports['qb-target']:AddBoxZone('delivery', spot.coords, 1.5, 1.5, {
                name = 'delivery-',
                heading = 0,
                debugPoly = useDebug,
                minZ = spot.coords.z - 0.5,
                maxZ = spot.coords.z + 0.5,
            }, {
                options = {{
                    type = 'client',
                    label = "Put down the delivery",
                    icon = "fas fa-box",
                    action = function()
                        deliverItem(spot, item, prop)
                    end,
                }},
                distance = 2.0
            })
        else
            TerminateThisThread()
        end
    end)
end

local function takeDeliveryObject(startingCoords, item, prop, entity)
    DeleteEntity(entity)
    if LocationBlip then
        RemoveBlip(LocationBlip)
    end
    PickingUp = false
    PickupLocation = ''
    local spot = getDeliveryLocationByDistance()
    Blip = AddBlipForCoord(spot.coords)
    SetBlipRoute(Blip, true)
    SetBlipRouteColour(Blip, 5)
    SetBlipSprite(Blip, 304)
    SetBlipColour(Blip, 5)
    TriggerServerEvent('sd-deliveryjob:server:startJob', item)
    OnRun = true
    createDeliveryBox(spot, item, prop)
    exports['qb-phone']:PhoneNotification("FeedStars", 'Marking delivery location on your GPS', 'fas fa-star', '#eec64e', 5000)
end

local function createPickupEntity(location)
    local prop = Config.Props.box
    local label = "Grab FeedStars Box"
    RunType = 'box'

    if location.item == 'deliverybag' then
        prop = Config.Props.bag
        RunType = 'bag'
        label = "Grab FeedStars Bab"
    end

    CurrentCompany = location.job


    local bagEntity = CreateObject(prop, location.coords.x, location.coords.y, location.coords.z, false,  false, true)
    SetEntityHeading(bagEntity, location.heading)
    FreezeEntityPosition(bagEntity, true)
    SetEntityAsMissionEntity(bagEntity)
    SetEntityCanBeDamaged(bagEntity, false)
    SetEntityInvincible(bagEntity, true)

    Entities[#Entities+1] = bagEntity
    exports['qb-target']:AddTargetEntity(bagEntity, {
        options = {{
            type = 'client',
            label = label,
            icon = "fas fa-star",
            action = function(entity)
                takeDeliveryObject(location.coords, location.item, location.prop, bagEntity)
            end,
            canInteract = function ()
                local Player = QBCore.Functions.GetPlayerData()
                return (PickingUp and PickupLocation == location.job) and not OnRun
            end,
        }},
        distance = 2.0
    })
end

local markers = {}
RegisterNetEvent('sd-deliveryjob:client:debugMap', function()
    if #markers > 0 then
        print('removing markers')
        for i, marker in pairs(markers) do
            RemoveBlip(marker)
        end
        markers = {}
    else
        print('adding markers')
        for i, location in pairs(Config.DeliverySpots) do
            markers[#markers+1] = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(markers[#markers], 304)
            SetBlipColour(markers[#markers], 5)
        end
    end
end)

local function mergedJobs()
    local mergedTable = {}
    local PlayerJob = QBCore.Functions.GetPlayerData().job
    if PlayerJob.onduty then
        for k,v in pairs(Config.Jobs.Food) do if PlayerJob.name == v.job then mergedTable[#mergedTable+1] = v end end
        for k,v in pairs(Config.Jobs.Mechanic) do if PlayerJob.name == v.job then mergedTable[#mergedTable+1] = v end end 
    end
    if #mergedTable == 0 then
        for k,v in pairs(Config.Jobs.Food) do mergedTable[#mergedTable+1] = v end 
        for k,v in pairs(Config.Jobs.Mechanic) do mergedTable[#mergedTable+1] = v end 
    end
    return mergedTable
end

-- For FeedStars
function acceptJob()
    if not PickingUp and not OnRun then
        local mergedtables = mergedJobs()

        local location = nil
        local location = mergedtables[math.random(1, #mergedtables)]
        
        local text = "The food is ready. Head over to the location and grab the bag."
        local readableLocation = Config.JobMap[PickupLocation]

        if location.item == 'deliverybag' then
            RunType = 'bag'
            if readableLocation then
                text = "A delivery from "..readableLocation.." has been requested. Hurry up!"
            end
        else
            RunType = 'box'
            text = "Box Request! Head over to the location and grab the box."
            if readableLocation then
                text = "Box Request from "..readableLocation.."! Head over to the location and grab the box."
            end
        end
        PickupLocation = location.job
        createPickupEntity(location)
    
        PickingUp = true
        Freelancing = true
        LocationBlip = AddBlipForCoord(location.coords)
        SetBlipRoute(LocationBlip, true)
        SetBlipRouteColour(LocationBlip, 5)
        SetBlipSprite(LocationBlip, 304)
        SetBlipColour(LocationBlip, 5)
        exports['qb-phone']:PhoneNotification("FeedStars", text, 'fas fa-star', '#eec64e', 5000)
    else
        exports['qb-phone']:PhoneNotification("FeedStars", 'You are already on a job 🙄', 'fas fa-star', '#eec64e', 5000)
    end

end exports('acceptJob', acceptJob)


function cancelJob()
    if not PickingUp and not OnRun then
        exports['qb-phone']:PhoneNotification("FeedStars", 'You are not on a job.', 'fas fa-star', '#eec64e', 5000)
    elseif PickingUp and not OnRun then
        PickingUp = false
        Freelancing = false
        RemoveBlip(LocationBlip)
        exports['qb-phone']:PhoneNotification("FeedStars", 'Job canceled. This will affect your FeedBag Rating.', 'fas fa-star', '#eec64e', 5000)
        exports["mz-skills"]:UpdateSkill("Food Delivery", -2)
        Wait(2000)
        for i, entity in pairs(Entities) do
            print('deleting', entity)
            if DoesEntityExist(entity) then
               DeleteEntity(entity)
            end
        end
    else
        exports['qb-phone']:PhoneNotification("FeedStars", 'You can not cancel a job after you have picked up the goods.', 'fas fa-star', '#eec64e', 5000)
    end
end exports('cancelJob', cancelJob)

function isOnJob()
    return OnRun or PickingUp
end exports('isOnJob', isOnJob)
