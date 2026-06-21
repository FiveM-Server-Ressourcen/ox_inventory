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

print('^2[ox_inventory] Kleidungsmodul (Server) geladen^0')
