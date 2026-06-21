if not lib then return end

local Inventory

-- Verzögert laden – genau wie modules/items/server.lua
CreateThread(function()
    Inventory = require 'modules.inventory.server'
end)

-- Wardrobe-Slot-Konfiguration (muss mit client.lua übereinstimmen)
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

local WARDROBE_SLOT_COUNT = 16
local WARDROBE_MAX_WEIGHT = 100000

local CLOTHING_ITEMS = {
    'cloth_hat', 'cloth_glasses', 'cloth_ear', 'cloth_watch', 'cloth_bracelet',
    'cloth_mask', 'cloth_hair', 'cloth_torso', 'cloth_undershirt', 'cloth_top',
    'cloth_decal', 'cloth_legs', 'cloth_shoes', 'cloth_bag', 'cloth_accessory',
    'cloth_armor',
}

local CLOTHING_ITEM_SET = {}
for _, v in ipairs(CLOTHING_ITEMS) do
    CLOTHING_ITEM_SET[v] = true
end

-- Slot-Typ aus Item-Daten ermitteln
local function getSlotType(itemName)
    -- 'cloth_hat' → 'hat', 'cloth_top' → 'top', etc.
    local suffix = itemName:match('^cloth_(.+)$')
    return suffix
end

-- Garderobe für einen Spieler registrieren
local function registerWardrobe(owner)
    if not owner then return end
    exports.ox_inventory:RegisterStash({
        id     = 'wardrobe',
        label  = 'Garderobe',
        slots  = WARDROBE_SLOT_COUNT,
        weight = WARDROBE_MAX_WEIGHT,
        owner  = owner,
    })
end

-- Callback: Garderobe öffnen
lib.callback.register('ox_inventory:clothing:openWardrobe', function(source)
    if not Inventory then return false end

    local inv = Inventory(source)
    if not inv?.owner then return false end

    registerWardrobe(inv.owner)
    Wait(100)

    inv:openInventory({
        id    = 'wardrobe',
        owner = inv.owner,
        type  = 'stash',
    })

    return true
end)

-- Callback: Spieler fragt beim Spawn nach seiner getragenen Kleidung
lib.callback.register('ox_inventory:clothing:getEquipped', function(source)
    if not Inventory then return {} end

    local inv = Inventory(source)
    if not inv?.owner then return {} end

    -- Garderobe sicherstellen und laden
    registerWardrobe(inv.owner)
    Wait(100)

    local wardrobeId = ('wardrobe:%s'):format(inv.owner)
    local wardrobeInv = Inventory(wardrobeId)
    if not wardrobeInv then return {} end

    local equipped = {}
    for slot = 1, WARDROBE_SLOT_COUNT do
        local item = wardrobeInv.items[slot]
        if item and item.name and CLOTHING_ITEM_SET[item.name] then
            equipped[#equipped + 1] = {
                name     = item.name,
                slot     = slot,
                metadata = item.metadata or {},
            }
        end
    end

    return equipped
end)

-- Hook: Validierung für Garderobe
-- Erlaubt nur Kleidungsitems und erzwingt den richtigen Slot
local wardrobeHookId = exports.ox_inventory:registerHook('swapItems', function(payload)
    local toInvId  = tostring(payload.toInventory  or '')
    local fromInvId = tostring(payload.fromInventory or '')

    local toWardrobe   = toInvId:find('^wardrobe:')
    local fromWardrobe = fromInvId:find('^wardrobe:')

    -- Nur Wardrobe-Transaktionen prüfen
    if not toWardrobe and not fromWardrobe then return true end

    local item     = payload.item
    local itemName = type(item) == 'table' and item.name or tostring(item or '')

    -- Nicht-Kleidungsitems in Garderobe verweigern
    if toWardrobe and not CLOTHING_ITEM_SET[itemName] then
        return false
    end

    -- Slot-Typ prüfen: Item muss in den richtigen Slot
    if toWardrobe and CLOTHING_ITEM_SET[itemName] then
        local slotType     = getSlotType(itemName)
        local expectedSlot = slotType and WARDROBE_SLOTS[slotType]

        if expectedSlot and payload.toSlot and payload.toSlot ~= expectedSlot then
            return false
        end
    end

    return true
end)

-- Post-Event des Hooks abfangen: Kleidungsänderungen an Client senden
if wardrobeHookId then
    AddEventHandler(wardrobeHookId, function(success, payload)
        if not success or not Inventory then return end

        local toInvId   = tostring(payload.toInventory   or '')
        local fromInvId = tostring(payload.fromInventory  or '')

        local toWardrobe   = toInvId:find('^wardrobe:')
        local fromWardrobe = fromInvId:find('^wardrobe:')

        if not toWardrobe and not fromWardrobe then return end

        local item     = payload.item
        local itemName = type(item) == 'table' and item.name or tostring(item or '')

        if not CLOTHING_ITEM_SET[itemName] then return end

        local metadata = (type(item) == 'table' and item.metadata) or {}

        -- Spieler anhand der Garderobe finden
        local function findPlayer(wardrobeInvId)
            local owner = wardrobeInvId:match('^wardrobe:(.+)$')
            if not owner then return nil end

            for _, pid in ipairs(GetPlayers()) do
                local source = tonumber(pid)
                local playerInv = Inventory(source)
                if playerInv and tostring(playerInv.owner) == owner then
                    return source
                end
            end
            return nil
        end

        if toWardrobe then
            local source = findPlayer(toInvId)
            if source then
                TriggerClientEvent('ox_inventory:clothing:equip', source, itemName, payload.toSlot, metadata)
            end
        end

        if fromWardrobe then
            local source = findPlayer(fromInvId)
            if source then
                TriggerClientEvent('ox_inventory:clothing:unequip', source, itemName, payload.fromSlot, metadata)
            end
        end
    end)
end

-- Export: Garderobe eines Spielers zurückgeben
exports('getPlayerWardrobe', function(source)
    if not Inventory then return nil end
    local inv = Inventory(source)
    if not inv?.owner then return nil end
    return Inventory(('wardrobe:%s'):format(inv.owner))
end)

-- Export: Slot-Mapping zurückgeben
exports('getWardrobeSlots', function()
    return WARDROBE_SLOTS
end)

-- Export: Ist das Item ein Kleidungsitem?
exports('isClothingItem', function(itemName)
    return CLOTHING_ITEM_SET[itemName] == true
end)

-- ── NUI-Events: Anziehen / Ausziehen ─────────────────────────────────────────

-- Spieler zieht Kleidung aus Inventory an (Drag auf EquipmentPanel)
RegisterNetEvent('ox_inventory:clothing:equipFromInventory', function(fromSlot, slotType)
    local src = source
    if not Inventory or not fromSlot or not slotType then return end

    local wardrobeSlot = WARDROBE_SLOTS[slotType]
    if not wardrobeSlot then return end

    local playerInv = Inventory(src)
    if not playerInv or not playerInv.owner then return end

    local sourceItem = playerInv.items[fromSlot]
    if not sourceItem or not sourceItem.name then return end

    -- Item muss zum Slot passen
    if sourceItem.name ~= 'cloth_' .. slotType then
        lib.notify(src, { title = 'Garderobe', description = 'Dieses Item passt nicht in diesen Slot.', type = 'error' })
        return
    end

    local wardrobeId = ('wardrobe:%s'):format(playerInv.owner)
    registerWardrobe(playerInv.owner)
    Wait(50)

    local wardrobeInv = Inventory(wardrobeId)
    -- Vorhandenes Item im Ziel-Slot ausziehen und zurück ins Inventory legen
    if wardrobeInv and wardrobeInv.items[wardrobeSlot] then
        local existingItem = wardrobeInv.items[wardrobeSlot]
        if existingItem and existingItem.name then
            wardrobeInv:RemoveItem(existingItem.name, existingItem.count or 1, existingItem.metadata, wardrobeSlot)
            playerInv:AddItem(existingItem.name, existingItem.count or 1, existingItem.metadata)
            TriggerClientEvent('ox_inventory:clothing:unequip', src, existingItem.name, wardrobeSlot, existingItem.metadata)
        end
    end

    -- Item aus Spieler-Inventory in Schrank verschieben
    local removed = playerInv:RemoveItem(sourceItem.name, sourceItem.count or 1, sourceItem.metadata, fromSlot)
    if not removed then return end

    wardrobeInv = Inventory(wardrobeId)
    if wardrobeInv then
        wardrobeInv:AddItem(sourceItem.name, sourceItem.count or 1, sourceItem.metadata, wardrobeSlot)
    end

    TriggerClientEvent('ox_inventory:clothing:equip', src, sourceItem.name, wardrobeSlot, sourceItem.metadata)
end)

-- Spieler zieht Kleidung aus (Doppelklick auf EquipmentPanel)
RegisterNetEvent('ox_inventory:clothing:unequipToInventory', function(slotType)
    local src = source
    if not Inventory or not slotType then return end

    local wardrobeSlot = WARDROBE_SLOTS[slotType]
    if not wardrobeSlot then return end

    local playerInv = Inventory(src)
    if not playerInv or not playerInv.owner then return end

    local wardrobeId  = ('wardrobe:%s'):format(playerInv.owner)
    registerWardrobe(playerInv.owner)
    Wait(50)

    local wardrobeInv = Inventory(wardrobeId)
    if not wardrobeInv then return end

    local item = wardrobeInv.items[wardrobeSlot]
    if not item or not item.name then return end

    wardrobeInv:RemoveItem(item.name, item.count or 1, item.metadata, wardrobeSlot)
    playerInv:AddItem(item.name, item.count or 1, item.metadata)
    TriggerClientEvent('ox_inventory:clothing:unequip', src, item.name, wardrobeSlot, item.metadata)
end)

-- ── illenium-appearance: Kleidung als Items speichern ────────────────────────

local COMPONENT_TO_SLOT = {
    [1] = 'mask', [2] = 'hair', [3] = 'torso', [4] = 'legs',
    [5] = 'bag',  [6] = 'shoes', [7] = 'accessory', [8] = 'undershirt',
    [9] = 'armor', [10] = 'decal', [11] = 'top',
}

local PROP_TO_SLOT = {
    [0] = 'hat', [1] = 'glasses', [2] = 'ear', [6] = 'watch', [7] = 'bracelet',
}

local playerLastAppearance = {}

local function getChangedClothing(oldApp, newApp)
    local changes = {}

    local oldComps = (oldApp and type(oldApp.components) == 'table' and oldApp.components) or {}
    local newComps = (newApp and type(newApp.components) == 'table' and newApp.components) or {}

    for id, slotType in pairs(COMPONENT_TO_SLOT) do
        local old = oldComps[id] or {}
        local new = newComps[id] or {}
        if new.drawable ~= nil and (new.drawable ~= (old.drawable or -1) or (new.texture or 0) ~= (old.texture or 0)) then
            changes[slotType] = {
                drawable = new.drawable,
                texture  = new.texture  or 0,
                palette  = new.palette  or 0,
            }
        end
    end

    local oldProps = (oldApp and type(oldApp.props) == 'table' and oldApp.props) or {}
    local newProps = (newApp and type(newApp.props) == 'table' and newApp.props) or {}

    for id, slotType in pairs(PROP_TO_SLOT) do
        local old = oldProps[id] or {}
        local new = newProps[id] or {}
        if new.drawable ~= nil and (new.drawable ~= (old.drawable or -1) or (new.texture or 0) ~= (old.texture or 0)) then
            changes[slotType] = { drawable = new.drawable, texture = new.texture or 0 }
        end
    end

    return changes
end

local function applyAppearanceToWardrobe(src, appearance)
    if not Inventory or not appearance then return end

    local playerInv = Inventory(src)
    if not playerInv or not playerInv.owner then return end

    local wardrobeId = ('wardrobe:%s'):format(playerInv.owner)
    registerWardrobe(playerInv.owner)
    Wait(50)

    local oldApp = playerLastAppearance[src]
    playerLastAppearance[src] = appearance

    local diff = getChangedClothing(oldApp, appearance)
    if not next(diff) then return end

    local wardrobeInv = Inventory(wardrobeId)
    if not wardrobeInv then return end

    for slotType, metadata in pairs(diff) do
        local itemName     = 'cloth_' .. slotType
        local wardrobeSlot = WARDROBE_SLOTS[slotType]
        if not wardrobeSlot then goto continue end

        metadata.label = slotType:sub(1,1):upper() .. slotType:sub(2)

        -- Altes Item im Slot entfernen
        local existingItem = wardrobeInv.items[wardrobeSlot]
        if existingItem and existingItem.name then
            wardrobeInv:RemoveItem(existingItem.name, existingItem.count or 1, existingItem.metadata, wardrobeSlot)
        end

        -- Neues Item in Schrank legen (zieht automatisch an via swapItems Hook)
        wardrobeInv:AddItem(itemName, 1, metadata, wardrobeSlot)
        TriggerClientEvent('ox_inventory:clothing:equip', src, itemName, wardrobeSlot, metadata)

        ::continue::
    end

    lib.notify(src, {
        title       = 'Garderobe',
        description = 'Kleidung in Garderobe gespeichert.',
        type        = 'success',
        duration    = 3000,
    })
end

-- illenium-appearance: Wenn Spieler Aussehen speichert
AddEventHandler('illenium-appearance:server:saveAppearance', function(src, appearance)
    CreateThread(function()
        applyAppearanceToWardrobe(src, appearance)
    end)
end)

-- fivem-appearance als Fallback
AddEventHandler('fivem-appearance:server:saveAppearance', function(src, appearance)
    CreateThread(function()
        applyAppearanceToWardrobe(src, appearance)
    end)
end)

-- Spieler joined: Appearance zwischenspeichern für Diff-Berechnung
AddEventHandler('ox_inventory:playerLoaded', function(src)
    SetTimeout(5000, function()
        if not GetPlayerName(src) then return end
        local ok, appearance = pcall(function()
            return exports['illenium-appearance']:getPlayerAppearance(src)
        end)
        if ok and type(appearance) == 'table' then
            playerLastAppearance[src] = appearance
        end
    end)
end)

AddEventHandler('playerDropped', function()
    playerLastAppearance[source] = nil
end)

print('^2[ox_inventory] Kleidungsmodul (Server) geladen^0')
