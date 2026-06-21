---
name: ox_inventory Clothing System
description: Full clothing slot system for ox_inventory + illenium-appearance integration — architecture decisions and gotchas
---

# ox_inventory Kleidungssystem

## Slot-Mapping (muss in server.lua + client.lua identisch sein)
hat=1, glasses=2, ear=3, watch=4, bracelet=5, mask=6, hair=7, torso=8,
undershirt=9, top=10, decal=11, legs=12, shoes=13, bag=14, accessory=15, armor=16

## GTA Component IDs → slotType
mask=1, hair=2, torso=3, legs=4, bag=5, shoes=6, accessory=7, undershirt=8, armor=9, decal=10, top=11
Props: hat=0, glasses=1, ear=2, watch=6, bracelet=7

## Wardrobe-ID Format
`wardrobe:{owner}` — owner = citizenid / identifier

## Architektur-Entscheidungen
- Kleidung liegt in einem ox_inventory Stash (wardrobe:{owner}) mit 16 Slots
- Slot-Nummer = Wardrobe-Slot (1-16), erzwungen via swapItems Hook
- EquipmentPanel ist links vom LeftInventory (inventory-wrapper: flex-row)
- NUI-Events: `updateWardrobeItems` (full refresh), `updateWardrobeSlot` (single slot)
- illenium-appearance: `illenium-appearance:server:saveAppearance` event → Diff-Berechnung → Items in Wardrobe

**Why:** ox_inventory native Stash-System nutzen statt eigener Datenhaltung; Diff-Berechnung vermeidet Duplikate bei jedem Appearance-Save

## Build
npm install benötigt `--legacy-peer-deps` (React 19 vs react-redux 8 Konflikt)
Build: `cd web && npm run build`
