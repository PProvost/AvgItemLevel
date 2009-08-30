-- credits: Rabbit for the old ClosetGnome code from which this is derived

assert(LibStub, "LibItemEquip-1.0 requires LibStub")
assert(LibStub:GetLibrary("AceTimer-3.0", true), "LibItemEquip-1.0 requires AceTimer-3.0")

local lib, oldminor = LibStub:NewLibrary("LibItemEquip-1.0", 1)
if not lib then return end
oldminor = oldminor or 0

local L = setmetatable({}, {__index=function(t,i) return i end})
local deequipQueue = nil

LibStub("AceTimer-3.0"):Embed(lib)

local PickupContainerItem = _G.PickupContainerItem
local AutoEquipCursorItem = _G.AutoEquipCursorItem
local EquipCursorItem = _G.EquipCursorItem
local PickupInventoryItem = _G.PickupInventoryItem

local function getInvItem(s)
	return GetInventoryItemLink("player", s)
end

local function compareItems(item1, item2)
	if not item1 or not item2 then return (item1 == item2) end
	item1 = item1:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub(":(%-?%d+)|", ":%%-?%%d+|")
	return item2:match(item1)
end

local function reclaim(t)
	if type(t) == "table" then wipe(t) end
	t=nil;return t
end

local function LockSlot(bag, slot)
	if not slotLocks then slotLocks = {} end
	if not slotLocks[bag] then slotLocks[bag] = {} end
	slotLocks[bag][slot] = true
end

local function IsSlotLocked(bag, slot)
	if slotLocks and slotLocks[bag] and slotLocks[bag][slot] then
		return true
	end
	return false
end

local function ClearSlotLocks()
	slotLocks = reclaim(slotLocks)
end

local function getItemEquipLoc(link)
	return select(9, GetItemInfo(link))
end

local function getItemSubtype(link)
	return select(7, GetItemInfo(link))
end

-- Debugging helper
function lib:ResetLocks()
	ClearSlotLocks()
end

local function GetOppositeSlot(slot)
	if type(slot) ~= "number" then error("Only takes numbers.") end
	if slot == 11 then return 12
	elseif slot == 12 then return 11
	elseif slot == 13 then return 14
	elseif slot == 14 then return 13
	elseif slot == 16 then return 17
	elseif slot == 17 then return 16
	end
	return nil
end

local function rerun(tmp)
	lib:EquipItemInternal(tmp.slot, tmp.item, true)
	tmp.slot = nil
	tmp.item = nil
	tmp = nil
	processDeequipQueue()
end

local function processDeequipQueue()
	if not deequipQueue then deequipQueue = {} end
	for i, slot in pairs(deequipQueue) do
		PickupInventoryItem(slot)
		local toBag, toSlot = lib:LocateFreeSlot()
		if toBag ~= nil then
			LockSlot(toBag, toSlot)
			PickupContainerItem(toBag, toSlot)
		else
			AutoEquipCursorItem()
			break
		end
	end
	deequipQueue = reclaim(deequipQueue)
	ClearSlotLocks()
end

local function ProcessEquipQueue()
	lib:UnregisterEvent("ITEM_LOCK_CHANGED")
	if not equipQueue then return end
	for slot, item in pairs(equipQueue) do
		lib:EquipItemInternal(slot, item, nil)
	end
--	if not ClosetGnome:IsEventRegistered("ITEM_LOCK_CHANGED") then
		equipQueue = reclaim(equipQueue)
--	end
end

local function QueueEquipItem(slot, item)
	if not equipQueue then equipQueue = {} end
	equipQueue[slot] = item
--	if not ClosetGnome:IsEventRegistered("ITEM_LOCK_CHANGED") then
		lib:RegisterEvent("ITEM_LOCK_CHANGED", ProcessEquipQueue)
--	end
end

-- ERR_2HANDED_EQUIPPED

local function ReallyWearSet(set, inCombat)
	local fullyEquipped = true
	for slot, item in pairs(set) do
		if not compareItems(getInvItem(slot), item) then
			if not inCombat or slot == 0 or slot == 16 or slot == 17 or slot == 18 then
				lib:EquipItemInternal(slot, item, nil)
			else
				fullyEquipped = false
			end
		end
	end
	return fullyEquipped
end

local function processQueue()
	if UnitIsDeadOrGhost("player") then return end
	if type(queuedSet) ~= "table" then
		lib:UnregisterEvent("PLAYER_REGEN_ENABLED")
		lib:UnregisterEvent("PLAYER_UNGHOST")
		lib:UnregisterEvent("PLAYER_ALIVE")
		queuedSet = {}
		return
	end
	lib:WearSet(unpack(queuedSet))
end


function lib:IsSetFullyEquipped(input)
	local set = nil
	if type(input) == "string" then
		set = db.set[input]
	elseif type(input) == "table" then
		set = input
	end
	if not set then return false end
	for slot, item in pairs(set) do
		-- Don't check the ammo slot at all.
		if slot > 0 and item and not IsEquippedItem(item) then
			return false
		end
	end
	return true
end


function lib:IsNormalBag(bagId)
	if bagId == 0 or bagId == -1 then return true end
	local link = getInvItem(ContainerIDToInventoryID(bagId))
	if not link then return false end
	local linkId = select(3, link:find("item:(%d+)"))
	if not linkId then return false end
	local bagType = getItemSubtype(linkId)
	if bagType and bagType == INVTYPE_BAG then return true end
	return false
end

function lib:LocateFreeSlot()
	for theBag = NUM_BAG_FRAMES, 0, -1 do
		if self:IsNormalBag(theBag) then
			local numSlot = GetContainerNumSlots(theBag)
			for theSlot = 1, numSlot, 1 do
				if not IsSlotLocked(theBag, theSlot) then
					local texture = GetContainerItemInfo(theBag, theSlot)
					if not texture then
						return theBag, theSlot
					end
				end
			end
		end
	end
	return nil
end

function lib:EquipItem(slot, item)
	self:EquipItemInternal(slot, item)
	processDeequipQueue()
end

function lib:EquipItemInternal(slot, item, secondTry)
	if item == false then
		-- We need to find a free slot in the inventory for this item.
		-- If there's anything in the slot.
		local hasItem = getInvItem(slot)
		if hasItem ~= false then
			if not deequipQueue then deequipQueue = {} end
			table.insert(deequipQueue, slot)
		end
	else
		if slot == 17 and getInvItem(16) and getItemEquipLoc(getInvItem(16)) == "INVTYPE_2HWEAPON" then
			-- We can't equip off-hand items if we still have a 2h weapon equipped.  In such an event, we should deequip the 2h weapon first.
			local toBag, toSlot = self:LocateFreeSlot()
			if toBag ~= nil then
				PickupInventoryItem(16)
				PickupContainerItem(toBag, toSlot)
				LockSlot(toBag, toSlot)
			end
		end
		if slot == 16 and getInvItem(17) and getItemEquipLoc(item) == "INVTYPE_2HWEAPON" then
			-- Deequip the off-hand to the last bag slot when equipping a 2h weapon
			local toBag, toSlot = self:LocateFreeSlot()
			if toBag ~= nil then
				PickupInventoryItem(17)
				PickupContainerItem(toBag, toSlot)
				LockSlot(toBag, toSlot)
			end
		end
		local bagNum, slotNum = self:FindItem(item)
		local oppositeSlot = GetOppositeSlot(slot)
		local slotItem = getInvItem(slot)
		-- equip from bags
		if bagNum > -1 then
			ClearCursor()
			local locked = select(3, GetContainerItemInfo(bagNum, slotNum))
			if locked then
				QueueEquipItem(slot, item)
			else
				PickupContainerItem(bagNum, slotNum)
				EquipCursorItem(slot)
				LockSlot(bagNum, slotNum)
			end
			-- equip from other slot
		elseif oppositeSlot and compareItems(getInvItem(oppositeSlot), item) then
			if slot == 17 and slotItem and getItemEquipLoc(slotItem) ~= "INVTYPE_WEAPON" then
				local toBag, toSlot = self:LocateFreeSlot()
				if toBag ~= nil then
					ClearCursor()
					PickupInventoryItem(17)
					PickupContainerItem(toBag, toSlot)
					LockSlot(toBag, toSlot)
					QueueEquipItem(slot, item)
					return
				end
			end
			ClearCursor()
			PickupInventoryItem(oppositeSlot)
			PickupInventoryItem(slot)
		else
			if not secondTry and item then
				local tmp = {}
				tmp.slot = slot
				tmp.item = item
				self:ScheduleTimer(rerun, 0.1, tmp)
			else
				if activeSlots ~= nil and activeSlots[slot] then
					missingItems[slot] = item
					activeSlots[slot] = false
					slots[slot].texture:SetVertexColor(255, 255, 0)
				end
				print(L["Couldn't find %s in your inventory."]:format(tostring(item)))
			end
		end
	end
end

function lib:FindItem(item)
	for i = NUM_BAG_FRAMES, 0, -1 do
		for j = GetContainerNumSlots(i), 1, -1 do
			if not IsSlotLocked(i, j) then
				local link = GetContainerItemLink(i, j)
				if link and compareItems(item, link) then return i, j end
			end
		end
	end
	return -1
end

function lib:WearSet(setToWear)
	ClearCursor()
	if CursorHasItem() or CursorHasSpell() or (UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player")) then return false end

	if type(setToWear) ~= "table" then return false end

	if UnitAffectingCombat("player") then
		print(L["May not equip set while in combat"])
		return false
	end

	deequipQueue = reclaim(deequipQueue)
	ReallyWearSet(setToWear, nil)
	processDeequipQueue()

	return true
end


