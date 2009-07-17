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

local slots = { "BackSlot", "ChestSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "HandsSlot", "HeadSlot", "LegsSlot", "MainHandSlot", "NeckSlot", "ShoulderSlot", "Trinket0Slot", "Trinket1Slot", "WaistSlot", "WristSlot" }

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("UNIT_TARGET")

local selfLoaded, inspectLoaded
function f:ADDON_LOADED(event, addon)
	if addon:lower() == "avgitemlevel" then 
		LibStub("tekKonfig-AboutPanel").new(nil, "AvgItemLevel")
		if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
		selfLoaded = true
	elseif addon:lower() == "blizzard_inspectui" then
		self.inspString = InspectPaperDollFrame:CreateFontString("AvgItemLevelInspString", "OVERLAY", "GameFontNormalSmall")
		self.inspString:SetPoint("BOTTOMRIGHT", InspectPaperDollFrame, "BOTTOMRIGHT", -50, 85)
		self.inspString:SetJustifyH("RIGHT")
		InspectPaperDollFrame:HookScript("OnShow", function(self) f:Calculate("target") end)
		inspectLoaded = true
	end
	if selfLoaded and inspectLoaded then self:UnregisterEvent("ADDON_LOADED"); self.ADDON_LOADED = nil end
end

function f:PLAYER_LOGIN()
	self.ppdString = PaperDollFrame:CreateFontString("AvgItemLevelPpdString", "OVERLAY", "GameFontNormalSmall")
	self.ppdString:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMRIGHT", -45, 85)
	self.ppdString:SetJustifyH("RIGHT")
	PaperDollFrame:HookScript("OnShow", function(self) f:Calculate("player") end)
	self:UnregisterEvent("PLAYER_LOGIN"); self.PLAYER_LOGIN = nil
end

function f:UNIT_INVENTORY_CHANGED(event, unit)
	if (unit == "player") or (unit == "target") then self:Calculate(unit) end
end

function f:UNIT_TARGET(event, unit)
	if unit ~= "player" then return end
	if InspectFrame and InspectFrame:IsVisible() then self:Calculate("target") end
end

function f:Calculate(unit)
	local total = 0
	local slot, link, quality, _, iLevel
	for i = 1,#slots do
		iLevel = 0
		slot = GetInventorySlotInfo(slots[i])
		link = GetInventoryItemLink(unit, slot)
		if link then
			_, _, quality, iLevel = GetItemInfo(link)
			if quality == 3 then iLevel = iLevel - 13
			elseif quality == 2 then iLevel = iLevel - 26
			elseif quality < 2 then iLevel = 0 end
		end
		total = total + iLevel
	end
	local fs = (unit == "target") and self.inspString or self.ppdString
	fs:SetText( string.format("Avg iLvl\n%.2f", total/#slots) )
end
