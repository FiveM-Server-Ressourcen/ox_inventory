if not lib then return end

local WARDROBE_SLOTS = {
    hat        = 1, glasses    = 2, ear        = 3,
    watch      = 4, bracelet   = 5, mask       = 6,
    hair       = 7, torso      = 8, undershirt = 9,
    top        = 10, decal     = 11, legs       = 12,
    shoes      = 13, bag       = 14, accessory  = 15,
    armor      = 16,
}

local SLOT_TO_COMPONENT = {
    mask = 1, hair = 2, torso = 3, legs = 4, bag = 5,
    shoes = 6, accessory = 7, undershirt = 8, armor = 9, decal = 10, top = 11,
}

local SLOT_TO_PROP = {
    hat = 0, glasses = 1, ear = 2, watch = 6, bracelet = 7,
}

local function getSlotType(itemName)
    return itemName and itemName:match('^cloth_(.+)$')
end

local equippedClothing = {}

local function hasIlleniumAppearance()
    return GetResourceState('illenium-appearance') == 'started'
end

local function hasFivemAppearance()
    return GetResourceState('fivem-appearance') == 'started'
end

local function applyAppearanceChange(slotType, metadata, remove)
    local ped = cache.ped

    if hasIlleniumAppearance() then
        local ok, appearance = pcall(exports['illenium-appearance'].getPedAppearance, exports['illenium-appearance'], ped)
        if ok and type(appearance) == 'table' then
            if SLOT_TO_COMPONENT[slotType] then
                local id = SLOT_TO_COMPONENT[slotType]
                if not appearance.components then appearance.components = {} end
                appearance.components[id] = remove
                    and { drawable = 0, texture = 0, palette = 0 }
                    or  { drawable = metadata.drawable or 0, texture = metadata.texture or 0, palette = metadata.palette or 0 }
            elseif SLOT_TO_PROP[slotType] then
                local id = SLOT_TO_PROP[slotType]
                if not appearance.props then appearance.props = {} end
                if remove then appearance.props[id] = nil
                else appearance.props[id] = { drawable = metadata.drawable or 0, texture = metadata.texture or 0 } end
            end
            pcall(exports['illenium-appearance'].setPedAppearance, exports['illenium-appearance'], ped, appearance)
            return
        end
    end

    if hasFivemAppearance() then
        local ok, appearance = pcall(exports['fivem-appearance'].getPedAppearance, exports['fivem-appearance'], ped)
        if ok and type(appearance) == 'table' then
            if SLOT_TO_COMPONENT[slotType] then
                local id = SLOT_TO_COMPONENT[slotType]
                if not appearance.components then appearance.components = {} end
                appearance.components[id] = remove
                    and { drawable = 0, texture = 0, palette = 0 }
                    or  { drawable = metadata.drawable or 0, texture = metadata.texture or 0, palette = metadata.palette or 0 }
            elseif SLOT_TO_PROP[slotType] then
                local id = SLOT_TO_PROP[slotType]
                if not appearance.props then appearance.props = {} end
                if remove then appearance.props[id] = nil
                else appearance.props[id] = { drawable = metadata.drawable or 0, texture = metadata.texture or 0 } end
            end
            pcall(exports['fivem-appearance'].setPedAppearance, exports['fivem-appearance'], ped, appearance)
            return
        end
    end

    -- Nativer Fallback
    if remove then
        if SLOT_TO_COMPONENT[slotType] then SetPedComponentVariation(ped, SLOT_TO_COMPONENT[slotType], 0, 0, 0)
        elseif SLOT_TO_PROP[slotType] then ClearPedProp(ped, SLOT_TO_PROP[slotType]) end
    else
        if SLOT_TO_COMPONENT[slotType] then
            local id = SLOT_TO_COMPONENT[slotType]
            local d, t, p = metadata.drawable or 0, metadata.texture or 0, metadata.palette or 0
            if IsPedComponentVariationValid(ped, id, d, t) then
                SetPedComponentVariation(ped, id, d, t, p)
            else
                SetPedComponentVariation(ped, id, 0, 0, 0)
            end
        elseif SLOT_TO_PROP[slotType] then
            local id = SLOT_TO_PROP[slotType]
            local d, t = metadata.drawable, metadata.texture or 0
            if d == nil or d == -1 then ClearPedProp(ped, id)
            elseif SetPedPreloadPropData(ped, id, d, t) then SetPedPropIndex(ped, id, d, t, false) end
        end
    end
end

local function sendWardrobeToUI(wardrobeData)
    SendNUIMessage({ action = 'updateWardrobeItems', data = wardrobeData or {} })
end

local function sendWardrobeSlotToUI(slotType, item)
    SendNUIMessage({ action = 'updateWardrobeSlot', data = { slotType = slotType, item = item } })
end

local function equipClothing(itemName, metadata, slotTypeOverride)
    local slotType = slotTypeOverride or getSlotType(itemName)
    if not slotType or not metadata or metadata.drawable == nil then return end
    equippedClothing[slotType] = { name = itemName, metadata = metadata, slotType = slotType, slot = WARDROBE_SLOTS[slotType] }
    applyAppearanceChange(slotType, metadata, false)
    sendWardrobeSlotToUI(slotType, equippedClothing[slotType])
end

local function unequipClothing(itemName, slotTypeOverride)
    local slotType = slotTypeOverride or getSlotType(itemName)
    if not slotType then return end
    equippedClothing[slotType] = nil
    applyAppearanceChange(slotType, {}, true)
    sendWardrobeSlotToUI(slotType, nil)
end

-- Garderobe öffnen (muss vor RegisterCommand definiert sein)
local function openWardrobe()
    local success = lib.callback.await('ox_inventory:clothing:openWardrobe', false)
    if not success then
        lib.notify({ title = 'Garderobe', description = 'Konnte nicht geöffnet werden.', type = 'error' })
    end
end

-- Server → Client
RegisterNetEvent('ox_inventory:clothing:equip', function(itemName, wardrobeSlot, metadata)
    equipClothing(itemName, metadata)
end)

RegisterNetEvent('ox_inventory:clothing:unequip', function(itemName, wardrobeSlot, metadata)
    unequipClothing(itemName)
end)

RegisterNetEvent('ox_inventory:clothing:applyEquipped', function(equippedList)
    Wait(1000)
    local wardrobeData = {}
    for _, entry in ipairs(equippedList) do
        local slotType = getSlotType(entry.name)
        if slotType and entry.metadata and entry.metadata.drawable ~= nil then
            equippedClothing[slotType] = { name = entry.name, metadata = entry.metadata, slotType = slotType, slot = WARDROBE_SLOTS[slotType] }
            wardrobeData[slotType]     = equippedClothing[slotType]
            applyAppearanceChange(slotType, entry.metadata, false)
            Wait(50)
        end
    end
    sendWardrobeToUI(wardrobeData)
end)

-- NUI → Server
RegisterNUICallback('clothing:equipFromInventory', function(data, cb)
    if not data.fromSlot or not data.slotType then cb({ ok = false }) return end
    TriggerServerEvent('ox_inventory:clothing:equipFromInventory', data.fromSlot, data.slotType)
    cb({ ok = true })
end)

RegisterNUICallback('clothing:unequipToInventory', function(data, cb)
    if not data.slotType then cb({ ok = false }) return end
    TriggerServerEvent('ox_inventory:clothing:unequipToInventory', data.slotType)
    cb({ ok = true })
end)

-- Beim Öffnen des Inventars: Garderobe an UI senden
AddEventHandler('ox_inventory:opened', function()
    local wardrobeData = {}
    for slotType, entry in pairs(equippedClothing) do
        wardrobeData[slotType] = entry
    end
    sendWardrobeToUI(wardrobeData)
end)

-- Spawn: Kleidung laden
local function loadEquippedClothing()
    local attempts = 0
    repeat Wait(500); attempts = attempts + 1
    until (cache.ped and cache.ped ~= 0) or attempts >= 20
    if not cache.ped or cache.ped == 0 then return end
    Wait(1000)

    local equipped = lib.callback.await('ox_inventory:clothing:getEquipped', false)
    if not equipped then return end

    local wardrobeData = {}
    for _, entry in ipairs(equipped) do
        local slotType = getSlotType(entry.name)
        if slotType and entry.metadata and entry.metadata.drawable ~= nil then
            equippedClothing[slotType] = { name = entry.name, metadata = entry.metadata, slotType = slotType, slot = WARDROBE_SLOTS[slotType] }
            wardrobeData[slotType]     = equippedClothing[slotType]
            applyAppearanceChange(slotType, entry.metadata, false)
            Wait(50)
        end
    end
    sendWardrobeToUI(wardrobeData)
end

AddEventHandler('playerSpawned', function()
    CreateThread(loadEquippedClothing)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    if LocalPlayer.state.isLoggedIn then CreateThread(loadEquippedClothing) end
end)

-- Befehle (openWardrobe bereits definiert oben)
RegisterCommand('garderobe', function() openWardrobe() end, false)
RegisterCommand('wardrobe',  function() openWardrobe() end, false)

-- Exports
exports('openWardrobe',        function() openWardrobe() end)
exports('getEquippedClothing', function() return equippedClothing end)
exports('applyClothingItem',   function(slotType, metadata)
    if not SLOT_TO_COMPONENT[slotType] and not SLOT_TO_PROP[slotType] then
        return false, 'Unbekannter Slot: ' .. tostring(slotType)
    end
    if not metadata or metadata.drawable == nil then return false, 'Kein drawable' end
    equipClothing('cloth_' .. slotType, metadata, slotType)
    return true
end)
exports('removeClothingItem', function(slotType)
    unequipClothing('cloth_' .. slotType, slotType)
    return true
end)

print('^2[ox_inventory] Kleidungsmodul (Client) geladen^0')
