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

local slots = { "AmmoSlot", "BackSlot", "ChestSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "HandsSlot", "HeadSlot", "LegsSlot", "MainHandSlot", "NeckSlot", "RangedSlot", "SecondaryHandSlot", "ShoulderSlot", "Trinket0Slot", "Trinket1Slot", "WaistSlot", "WristSlot" }

-- Event hander frame
local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")

function f:ADDON_LOADED(event, addon)
	if addon:lower() ~= "avgitemlevel" then return end
	LibStub("tekKonfig-AboutPanel").new(nil, "AvgItemLevel")
	self:UnregisterEvent("ADDON_LOADED"); self.ADDON_LOADED = nil
	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end

function f:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")

	-- Setup fontstring on the PaperDollFrame
	self.fontString = PaperDollFrame:CreateFontString("AvgItemLevelString", "ARTWORK", "GameFontNormalSmall")
	self.fontString:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMRIGHT", -50, 86)
	PaperDollFrame:HookScript("OnShow", function(self) f:Calculate() end)

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end

function f:Calculate()
	local total, count = 0, 0
	local slot, link, _, iLevel
	for i = 1,#slots do
		slot = GetInventorySlotInfo(slots[i])
		link = GetInventoryItemLink("player", slot)
		if link then
			iLevel = select(4, GetItemInfo(link))
			total = total + (iLevel or 0)
			count = count + 1
		end
	end

	self.fontString:SetText( string.format("%.2f", total/count) )
end
