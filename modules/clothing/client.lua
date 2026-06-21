if not lib then return end

-- Kleidungsslot-Konfiguration (muss mit server.lua übereinstimmen)
local WARDROBE_SLOTS = {
    hat        = 1,
    glasses    = 2,
    ear        = 3,
    watch      = 4,
    bracelet   = 5,
    mask       = 6,
    hair       = 7,
    torso      = 8,
    undershirt = 9,
    top        = 10,
    decal      = 11,
    legs       = 12,
    shoes      = 13,
    bag        = 14,
    accessory  = 15,
    armor      = 16,
}

-- GTA V Component-IDs pro Slot-Typ
local SLOT_TO_COMPONENT = {
    mask       = 1,
    hair       = 2,
    torso      = 3,
    legs       = 4,
    bag        = 5,
    shoes      = 6,
    accessory  = 7,
    undershirt = 8,
    armor      = 9,
    decal      = 10,
    top        = 11,
}

-- GTA V Prop-IDs pro Slot-Typ
local SLOT_TO_PROP = {
    hat      = 0,
    glasses  = 1,
    ear      = 2,
    watch    = 6,
    bracelet = 7,
}

-- Slot-Typ aus Item-Name ermitteln ('cloth_hat' → 'hat')
local function getSlotType(itemName)
    return itemName and itemName:match('^cloth_(.+)$')
end

-- Aktuell getragene Kleidung (slot_type → metadata)
local equippedClothing = {}

-- Prüft ob illenium-appearance läuft
local function hasIlleniumAppearance()
    return GetResourceState('illenium-appearance') == 'started'
end

-- Prüft ob fivem-appearance läuft
local function hasFivemAppearance()
    return GetResourceState('fivem-appearance') == 'started'
end

-- Kleidung per GTA-Natives anlegen (Component)
local function applyComponent(ped, componentId, drawable, texture, palette)
    palette = palette or 0
    drawable = drawable or 0
    texture  = texture  or 0
    if IsPedComponentVariationValid(ped, componentId, drawable, texture) then
        SetPedComponentVariation(ped, componentId, drawable, texture, palette)
        return true
    end
    -- Fallback auf Slot 0 wenn ungültig
    SetPedComponentVariation(ped, componentId, 0, 0, 0)
    return false
end

-- Kleidung per GTA-Natives anlegen (Prop)
local function applyProp(ped, propId, drawable, texture)
    if drawable == nil or drawable == -1 then
        ClearPedProp(ped, propId)
        return true
    end
    if SetPedPreloadPropData(ped, propId, drawable, texture or 0) then
        SetPedPropIndex(ped, propId, drawable, texture or 0, false)
        return true
    end
    return false
end

-- Appearance via illenium-appearance oder fivem-appearance anwenden
-- Fällt auf native GTA-Funktionen zurück wenn keine Appearance-Ressource läuft
local function applyAppearanceChange(slotType, metadata, remove)
    local ped = cache.ped

    -- Versuche illenium-appearance
    if hasIlleniumAppearance() then
        local ok, appearance = pcall(
            exports['illenium-appearance'].getPedAppearance,
            exports['illenium-appearance'], ped
        )

        if ok and type(appearance) == 'table' then
            if SLOT_TO_COMPONENT[slotType] then
                local compId = SLOT_TO_COMPONENT[slotType]
                if not appearance.components then appearance.components = {} end
                appearance.components[compId] = remove
                    and { drawable = 0, texture = 0, palette = 0 }
                    or  { drawable = metadata.drawable or 0,
                          texture  = metadata.texture  or 0,
                          palette  = metadata.palette  or 0 }

            elseif SLOT_TO_PROP[slotType] then
                local propId = SLOT_TO_PROP[slotType]
                if not appearance.props then appearance.props = {} end
                if remove then
                    appearance.props[propId] = nil
                else
                    appearance.props[propId] = {
                        drawable = metadata.drawable or 0,
                        texture  = metadata.texture  or 0,
                    }
                end
            end

            pcall(
                exports['illenium-appearance'].setPedAppearance,
                exports['illenium-appearance'], ped, appearance
            )
            return
        end
    end

    -- Versuche fivem-appearance
    if hasFivemAppearance() then
        local ok, appearance = pcall(
            exports['fivem-appearance'].getPedAppearance,
            exports['fivem-appearance'], ped
        )

        if ok and type(appearance) == 'table' then
            if SLOT_TO_COMPONENT[slotType] then
                local compId = SLOT_TO_COMPONENT[slotType]
                if not appearance.components then appearance.components = {} end
                appearance.components[compId] = remove
                    and { drawable = 0, texture = 0, palette = 0 }
                    or  { drawable = metadata.drawable or 0,
                          texture  = metadata.texture  or 0,
                          palette  = metadata.palette  or 0 }

            elseif SLOT_TO_PROP[slotType] then
                local propId = SLOT_TO_PROP[slotType]
                if not appearance.props then appearance.props = {} end
                if remove then
                    appearance.props[propId] = nil
                else
                    appearance.props[propId] = {
                        drawable = metadata.drawable or 0,
                        texture  = metadata.texture  or 0,
                    }
                end
            end

            pcall(
                exports['fivem-appearance'].setPedAppearance,
                exports['fivem-appearance'], ped, appearance
            )
            return
        end
    end

    -- Nativer Fallback (kein Appearance-Script vorhanden)
    if remove then
        if SLOT_TO_COMPONENT[slotType] then
            SetPedComponentVariation(ped, SLOT_TO_COMPONENT[slotType], 0, 0, 0)
        elseif SLOT_TO_PROP[slotType] then
            ClearPedProp(ped, SLOT_TO_PROP[slotType])
        end
    else
        if SLOT_TO_COMPONENT[slotType] then
            applyComponent(ped, SLOT_TO_COMPONENT[slotType],
                metadata.drawable, metadata.texture, metadata.palette)
        elseif SLOT_TO_PROP[slotType] then
            applyProp(ped, SLOT_TO_PROP[slotType], metadata.drawable, metadata.texture)
        end
    end
end

-- Kleidungsitem anziehen
local function equipClothing(itemName, metadata)
    if not metadata or metadata.drawable == nil then return end

    local slotType = getSlotType(itemName)
    if not slotType then
        return print(('[ox_inventory:clothing] Unbekannter Slot-Typ für %s'):format(itemName))
    end

    equippedClothing[slotType] = metadata
    applyAppearanceChange(slotType, metadata, false)
end

-- Kleidungsitem ausziehen
local function unequipClothing(itemName)
    local slotType = getSlotType(itemName)
    if not slotType then return end

    equippedClothing[slotType] = nil
    applyAppearanceChange(slotType, {}, true)
end

-- Server → Client: Kleidung anziehen
RegisterNetEvent('ox_inventory:clothing:equip', function(itemName, wardrobeSlot, metadata)
    equipClothing(itemName, metadata)
end)

-- Server → Client: Kleidung ausziehen
RegisterNetEvent('ox_inventory:clothing:unequip', function(itemName, wardrobeSlot, metadata)
    unequipClothing(itemName)
end)

-- Server → Client: Komplette Garderobe anwenden (z.B. nach Respawn)
RegisterNetEvent('ox_inventory:clothing:applyEquipped', function(equippedList)
    -- Kurze Wartezeit damit Ped vollständig gespawnt ist
    Wait(1000)
    for _, entry in ipairs(equippedList) do
        equipClothing(entry.name, entry.metadata)
        Wait(50)
    end
end)

-- Beim Spawn: Getragene Kleidung vom Server laden und anwenden
local function loadEquippedClothing()
    -- Warten bis der Ped verfügbar ist
    local attempts = 0
    repeat
        Wait(500)
        attempts = attempts + 1
    until cache.ped and cache.ped ~= 0 or attempts >= 20

    if not cache.ped or cache.ped == 0 then return end

    -- Weitere Wartezeit damit das Modell vollständig geladen ist
    Wait(1000)

    local equipped = lib.callback.await('ox_inventory:clothing:getEquipped', false)

    if equipped and #equipped > 0 then
        for _, entry in ipairs(equipped) do
            equipClothing(entry.name, entry.metadata)
            Wait(50)
        end
    end
end

-- Garderobe öffnen
local function openWardrobe()
    local success = lib.callback.await('ox_inventory:clothing:openWardrobe', false)
    if not success then
        lib.notify({
            title       = 'Garderobe',
            description = 'Garderobe konnte nicht geöffnet werden.',
            type        = 'error',
        })
    end
end

-- Spieler spawnt → Kleidung laden
AddEventHandler('playerSpawned', function()
    CreateThread(loadEquippedClothing)
end)

-- Fallback: Ressource startet während Spieler bereits eingeloggt ist
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    if LocalPlayer.state.isLoggedIn then
        CreateThread(loadEquippedClothing)
    end
end)

-- Befehl: /garderobe
RegisterCommand('garderobe', function()
    openWardrobe()
end, false)

-- Befehl: /wardrobe (Alias)
RegisterCommand('wardrobe', function()
    openWardrobe()
end, false)

-- Export: Garderobe öffnen (für andere Skripte nutzbar)
exports('openWardrobe', function()
    openWardrobe()
end)

-- Export: Aktuell getragene Kleidung abfragen
exports('getEquippedClothing', function()
    return equippedClothing
end)

-- Export: Kleidung manuell anlegen (ohne Inventar-System)
exports('applyClothingItem', function(slotType, metadata)
    if not SLOT_TO_COMPONENT[slotType] and not SLOT_TO_PROP[slotType] then
        return false, ('Unbekannter Kleidungsslot: %s'):format(tostring(slotType))
    end
    if not metadata or metadata.drawable == nil then
        return false, 'metadata.drawable fehlt'
    end
    equippedClothing[slotType] = metadata
    applyAppearanceChange(slotType, metadata, false)
    return true
end)

-- Export: Kleidung manuell ausziehen
exports('removeClothingItem', function(slotType)
    equippedClothing[slotType] = nil
    applyAppearanceChange(slotType, {}, true)
    return true
end)

print('^2[ox_inventory] Kleidungsmodul (Client) geladen^0')
