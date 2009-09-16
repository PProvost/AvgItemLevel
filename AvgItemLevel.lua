--[[
Copyright 2009 Quaiche of Dragonblight

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]

local L = setmetatable({}, {__index=function(t,i) return i end})
local function Print(...) print("|cFF33FF99AvgItemLevel|r: ", ...) end
local debugf = tekDebug and tekDebug:GetFrame("AvgItemLevel")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

-- Main addon event frame
AvgItemLevel = CreateFrame("frame")
AvgItemLevel:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
AvgItemLevel:RegisterEvent("ADDON_LOADED")
AvgItemLevel:RegisterEvent("UNIT_INVENTORY_CHANGED")
AvgItemLevel.icon = "Interface\\Icons\\INV_Helmet_49"

-- Only these slots matter for vehicle effective iLevel
-- always make sure MAINHANDSLOT comes before SECONDARYHANDSLOT if they both appear in the list
AvgItemLevel.VEHICLE_SLOTS = { "BACKSLOT", "CHESTSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "HANDSSLOT", "HEADSLOT", "LEGSSLOT", "MAINHANDSLOT", "NECKSLOT", "SHOULDERSLOT", "TRINKET0SLOT", "TRINKET1SLOT", "WAISTSLOT", "WRISTSLOT" }
AvgItemLevel.ALL_SLOTS = { "BACKSLOT", "CHESTSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "HANDSSLOT", "HEADSLOT", "LEGSSLOT", "MAINHANDSLOT", "NECKSLOT", "RANGEDSLOT", "SECONDARYHANDSLOT", "SHOULDERSLOT", "TRINKET0SLOT", "TRINKET1SLOT", "WAISTSLOT", "WRISTSLOT" }

local function GetAdjustedItemLevel(quality, iLevel)
	local result = iLevel 
	if not quality then result = 0
	elseif quality == 3 then result = iLevel - 13
	elseif quality == 2 then result = iLevel - 26
	elseif quality < 2 then result = 0 end
	return result
end

local function ShowTooltip(owner, unit, anchor)
	GameTooltip:SetOwner(owner, anchor)
	GameTooltip:AddDoubleLine("|cffffffffAverage Equipped iLevel|r", string.format("|cffffffff%.2f|r", AvgItemLevel:CalculateAverage(unit, AvgItemLevel.ALL_SLOTS)))
	GameTooltip:AddLine(" ")

	local vil = AvgItemLevel:CalculateAverage(unit, AvgItemLevel.VEHICLE_SLOTS)
	GameTooltip:AddDoubleLine("|cffffffffEffective Vehicle iLevel|r", string.format("|cffffffff%.2f|r", vil))
	GameTooltip:AddDoubleLine("|cffffffffAppx Vehicle Health Bonus|r", string.format("|cffffffff%.2f%%|r", vil-170))
	GameTooltip:AddLine(" ")

	if unit == "player" then
		vil = AvgItemLevel:GetBestVehicleSetAvg() 
		GameTooltip:AddDoubleLine("|cffffffffBest Available Vehicle Set|r", string.format("|cffffffff%.2f|r", vil))
		GameTooltip:AddDoubleLine("|cffffffffAppx Vehicle Health Bonus|r", string.format("|cffffffff%.2f%%|r", vil-170))
		GameTooltip:AddLine(" ")
	end

	GameTooltip:AddLine("|cffffff00Click|r to show the group report frame")

	if unit == "player" then
		GameTooltip:AddLine("|cffffff00Shift-Click|r to equip best available vehicle set")
	end
	GameTooltip:Show()
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:GetDataObjectByName("AvgItemLevel") or ldb:NewDataObject("AvgItemLevel", {
	type = "launcher", 
	icon = AvgItemLevel.icon,
	text = "0.0",
})

function AvgItemLevel:UNIT_INVENTORY_CHANGED(unit)
	if unit == "player" then
		dataobj.text = string.format("|cffffffff%.2f|r", AvgItemLevel:CalculateAverage(unit, self.ALL_SLOTS))
	end
end

local selfLoaded, inspectLoaded
function AvgItemLevel:ADDON_LOADED(event, addon)
	if addon:lower() == "avgitemlevel" then 
		LibStub("tekKonfig-AboutPanel").new(nil, "AvgItemLevel")
		if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
		selfLoaded = true
	elseif addon:lower() == "blizzard_inspectui" then
		local butt = CreateFrame("Button", nil, InspectFrame)
		butt:SetNormalTexture(self.icon)
		butt:SetPoint("BOTTOMRIGHT", -45, 84)
		butt:SetWidth(22); butt:SetHeight(22)

		butt:SetScript("OnEnter", function(self) ShowTooltip(self, "target", "ANCHOR_RIGHT") end)
		butt:SetScript("OnLeave", function() GameTooltip:Hide() end)

		butt:SetScript("OnClick", function(self, button)
			if button == "LeftButton" then
				AvgItemLevel:ShowReportPanel()
			end
		end)

		inspectLoaded = true
	end
	if selfLoaded and inspectLoaded then self:UnregisterEvent("ADDON_LOADED"); self.ADDON_LOADED = nil end
end

local function Player_OnClick(self, button)
	if button == "LeftButton" then
			if IsShiftKeyDown() then 
				AvgItemLevel:EquipBestVehicleSet()
			else
				AvgItemLevel:ShowReportPanel()
			end 
	end
end

function AvgItemLevel:PLAYER_LOGIN()
	local butt = CreateFrame("Button", nil, PaperDollFrame)
	butt:SetNormalTexture(self.icon)
	butt:SetPoint("BOTTOMRIGHT", -45, 84)
	butt:SetWidth(22); butt:SetHeight(22)

	butt:SetScript("OnEnter", function(self) ShowTooltip(self, "player", "ANCHOR_RIGHT") end)
	butt:SetScript("OnLeave", function() GameTooltip:Hide() end)
	butt:SetScript("OnClick", Player_OnClick)

	self:UnregisterEvent("PLAYER_LOGIN"); self.PLAYER_LOGIN = nil
	self:UNIT_INVENTORY_CHANGED("player")
end

function AvgItemLevel:CalculateAverage(unit, slots)
	if not slots then slots = self.VEHICLE_SLOTS end
	local sum, count = 0, 0
	local slot, link, quality, _, iLevel, equipSlot
	local twoHanderEquipped = nil
	for i = 1,#slots do
		iLevel = 0
		slot = GetInventorySlotInfo(slots[i])
		link = GetInventoryItemLink(unit, slot)
		if link then
			_, _, quality, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
			if equipSlot == "INVTYPE_2HWEAPON" then twoHanderEquipped = true end
			iLevel = GetAdjustedItemLevel(quality, iLevel)
		end
		if not (twoHanderEquipped and slots[i] == "SECONDARYHANDSLOT") then
			sum = sum + iLevel
			count = count + 1
		end
	end
	return sum / count
end

function AvgItemLevel:GetBestVehicleSetAvg()
	local sum, count = 0, 0
	local bestSet = self:GetBestVehicleSet()
	local quality, iLevel, equipSlot, itemLink, _
	for slotname, t in pairs(bestSet) do
		itemLink = t[1]
		if itemLink then
			_, _, quality, iLevel, _, _, _, _, equipSlot = GetItemInfo(itemLink)
			iLevel = GetAdjustedItemLevel(quality, iLevel)
		end
		sum = sum + iLevel
		count = count + 1
	end
	return sum / count
end

function AvgItemLevel:EquipBestVehicleSet()
	local bestSet = self:GetBestVehicleSet()
	local itemLink, itemLoc, slotId, action
	for slotname, t in pairs(bestSet) do
		itemLink, itemLoc = t[1], t[2]
		if itemLoc then
			slotId = GetInventorySlotInfo(slotname)
			action = EquipmentManager_EquipItemByLocation(itemLoc, slotId)
			EquipmentManager_RunAction(action)
			Debug("Equipping " .. itemLink)
		else
			Debug("Keeping " .. itemLink)
		end
	end
end

-- Returns a table of the best pieces for each slot
-- Each entry in the result table is keyed by slotname and is a table with the following form
-- { itemLink, itemLoc }
-- where itemLoc is nil if the item is already equipped
function AvgItemLevel:GetBestVehicleSet()
	local resultSet = {}
	local link, quality, iLevel, bag, slotName, slotId, locSlot
	local maxItemLevel, maxItemLink, maxItemLoc
	local currentlink, currentiLevel
	local used = {}
	local inventoryItemsForSlot, currentLink
	local itemid, itemloc

	for i,slotName in ipairs(self.VEHICLE_SLOTS) do
		maxItemLevel = 0
		maxItemLink = ""

		slotId = GetInventorySlotInfo(slotName)

		inventoryItemsForSlot = GetInventoryItemsForSlot(slotId) 
		for itemloc, itemid in pairs(inventoryItemsForSlot) do
			_, link, quality, iLevel = GetItemInfo(itemid)
			iLevel = GetAdjustedItemLevel(quality, iLevel)
			if not used[link] and iLevel > maxItemLevel then
				used[maxItemLink] = nil -- clear the prev one
				maxItemLevel = iLevel
				maxItemLink = link
				maxItemLoc = itemloc
				used[link] = true
			end
		end

		currentlink = GetInventoryItemLink("player", slotId)
		if currentlink then 
			currentiLevel = select(4, GetItemInfo(currentlink))
		else
			currentlink = "None"
			currentiLevel = 0
		end

		if maxItemLevel > currentiLevel then
			resultSet[slotName] = { maxItemLink, maxItemLoc }
		else
			resultSet[slotName] = { currentlink, nil }
		end
	end   

	return resultSet
end

SLASH_AVGITEMLEVEL1 = "/avgilevel"
SLASH_AVGITEMLEVEL2 = "/avgitemlevel"
SLASH_AVGITEMLEVEL3 = "/ail"
SlashCmdList.AVGITEMLEVEL = function(msg)
	AvgItemLevel:ShowReportPanel()
end
 
dataobj.OnEnter = function(self) ShowTooltip(self, "player", "ANCHOR_BOTTOMLEFT") end
dataobj.OnLeave = function() GameTooltip:Hide() end
dataobj.OnClick = Player_OnClick

