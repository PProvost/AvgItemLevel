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

-- Only these slots matter for vehicle effective iLevel
local equipSlots = { "BACKSLOT", "CHESTSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "HANDSSLOT", "HEADSLOT", "LEGSSLOT", "MAINHANDSLOT", "NECKSLOT", "SHOULDERSLOT", "TRINKET0SLOT", "TRINKET1SLOT", "WAISTSLOT", "WRISTSLOT" }

local L = setmetatable({}, {__index=function(t,i) return i end})

local function Print(...) print("|cFF33FF99AvgItemLevel|r: ", ...) end
local debugf = tekDebug and tekDebug:GetFrame("AvgItemLevel")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

AvgItemLevel = CreateFrame("frame")
AvgItemLevel:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
AvgItemLevel:RegisterEvent("ADDON_LOADED")
AvgItemLevel:RegisterEvent("UNIT_INVENTORY_CHANGED")
AvgItemLevel:RegisterEvent("UNIT_TARGET")

local selfLoaded, inspectLoaded
function AvgItemLevel:ADDON_LOADED(event, addon)
	if addon:lower() == "avgitemlevel" then 
		LibStub("tekKonfig-AboutPanel").new(nil, "AvgItemLevel")
		if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
		selfLoaded = true
	elseif addon:lower() == "blizzard_inspectui" then
		self.inspString = InspectPaperDollFrame:CreateFontString("AvgItemLevelInspString", "OVERLAY", "GameFontNormalSmall")
		self.inspString:SetPoint("BOTTOMRIGHT", InspectPaperDollFrame, "BOTTOMRIGHT", -50, 85)
		self.inspString:SetJustifyH("RIGHT")
		InspectPaperDollFrame:HookScript("OnShow", function(self) AvgItemLevel:CalculateAndShow("target") end)
		inspectLoaded = true
	end
	if selfLoaded and inspectLoaded then self:UnregisterEvent("ADDON_LOADED"); self.ADDON_LOADED = nil end
end

function AvgItemLevel:PLAYER_LOGIN()
	local butt = CreateFrame("Button", nil, PaperDollFrame)
	butt:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMRIGHT", -45, 83)
	butt:SetWidth(45); butt:SetHeight(25)
	self.ppdString = butt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.ppdString:SetAllPoints()
	self.ppdString:SetJustifyH("RIGHT")

	butt:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Your current effective average iLevel.\nTo equip your highest iLevel set\nautomatically, Alt+Click here."])
	end)
	butt:SetScript("OnLeave", function() GameTooltip:Hide() end)

	butt:SetScript("OnClick", function(self, button)
		if button == "LeftButton" and IsAltKeyDown() then
			AvgItemLevel:EquipBest()
		end
	end)

	PaperDollFrame:HookScript("OnShow", function(self) AvgItemLevel:CalculateAndShow("player") end)
	self:UnregisterEvent("PLAYER_LOGIN"); self.PLAYER_LOGIN = nil
end

function AvgItemLevel:UNIT_INVENTORY_CHANGED(event, unit)
	if (unit == "player") or (unit == "target") then self:CalculateAndShow(unit) end
end

function AvgItemLevel:UNIT_TARGET(event, unit)
	if unit ~= "player" then return end
	if InspectFrame and InspectFrame:IsVisible() then self:CalculateAndShow("target") end
end

function AvgItemLevel:GetAdjustedItemLevel(quality, iLevel)
	local result = iLevel 
	if not quality then result = 0
	elseif quality == 3 then result = iLevel - 13
	elseif quality == 2 then result = iLevel - 26
	elseif quality < 2 then result = 0 end
	return result
end

function AvgItemLevel:CalculateAverage(unit)
	local total = 0
	local slot, link, quality, _, iLevel
	for i = 1,#equipSlots do
		iLevel = 0
		slot = GetInventorySlotInfo(equipSlots[i])
		link = GetInventoryItemLink(unit, slot)
		if link then
			_, _, quality, iLevel = GetItemInfo(link)
			iLevel = self:GetAdjustedItemLevel(quality, iLevel)
		end
		total = total + iLevel
	end
	return total/#equipSlots
end

function AvgItemLevel:CalculateAndShow(unit)
	local avg = self:CalculateAverage(unit)
	local fs = (unit == "target") and self.inspString or self.ppdString
	fs:SetText( string.format("Avg iLvl\n%.2f", avg) )
end


function AvgItemLevel:EquipBest()
	local link, quality, iLevel, bag, slotName, slotId, locSlot
	local maxItemLevel, maxItemLink, maxItemLoc
	local currentlink, currentiLevel
	local used = {}
	local set = {}
	local inventoryItemsForSlot, currentLink
	local itemid, itemloc

	for i,slotName in ipairs(equipSlots) do
		maxItemLevel = 0
		maxItemLink = ""

		slotId = GetInventorySlotInfo(slotName)

		inventoryItemsForSlot = GetInventoryItemsForSlot(slotId) 
		for itemloc, itemid in pairs(inventoryItemsForSlot) do
			_, link, quality, oiLevel = GetItemInfo(itemid)
			iLevel = self:GetAdjustedItemLevel(quality, oiLevel)
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
			Debug("Equipping " .. _G[slotName] .. ": " .. maxItemLink .. " (" .. maxItemLevel .. ")")
			local action = EquipmentManager_EquipItemByLocation(maxItemLoc, slotId)
			EquipmentManager_RunAction(action)
		else
			Debug("Keeping " .. _G[slotName] .. ": " .. currentlink .. " (" .. currentiLevel .. ")" )
		end
	end   
end
