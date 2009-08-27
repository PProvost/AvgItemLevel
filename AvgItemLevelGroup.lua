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

local function Print(...) print("|cFF33FF99AvgItemLevel|r: ", ...) end

local panel = LibStub("tekPanel").new("AvgItemLevelFrame", "Average Item Level")

local NUMROWS = 22
local SCROLLSTEP = math.floor(NUMROWS/3)
local scrollbox = CreateFrame("Frame", nil, panel)
scrollbox:SetPoint("TOPLEFT", 0, -78)
scrollbox:SetPoint("BOTTOMRIGHT", -43, 82)
local scroll = LibStub("tekKonfig-Scroll").new(scrollbox, 0, SCROLLSTEP)

local rows, lastbutt = {}
local function OnMouseWheel(self, val) scroll:SetValue(scroll:GetValue() - val*SCROLLSTEP) end
for i=1,NUMROWS do
	local butt = CreateFrame("Button", nil, panel)
	butt:SetWidth(318) butt:SetHeight(16)
	if lastbutt then butt:SetPoint("TOP", lastbutt, "BOTTOM") else butt:SetPoint("TOPLEFT", 23, -77) end

	local name = butt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("LEFT", 5, 0)
	butt.name = name

	local avg = butt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	avg:SetPoint("RIGHT", -25, 0)
	butt.avg = avg

	butt:EnableMouseWheel(true)
	butt:SetScript("OnMouseWheel", OnMouseWheel)

	table.insert(rows, butt)
	lastbutt = butt
end

-- Source: http://www.wowwiki.com/ColorGradient
local function ColorGradient(perc, ...)
	if perc >= 1 then
		local r, g, b = select(select('#', ...) - 2, ...)
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = ...
		return r, g, b
	end
	
	local num = select('#', ...) / 3
	local segment, relperc = math.modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

local function ColorGradientEscape(perc, c1r, c1g, c1b, c2r, c2g, c2b, c3r, c3g, c3b)
   local r, g, b = ColorGradient(perc, c1r, c1g, c1b, c2r, c2g, c2b, c3r, c3g, c3b)   
   r = r <= 1 and r >= 0 and r or 0
   g = g <= 1 and g >= 0 and g or 0
   b = b <= 1 and b >= 0 and b or 0
   return string.format("|cFF%02x%02x%02x", r*255, g*255, b*255)
end

local function GetGroupAverages()
	local result = {}
	local unitbase
	local groupsize = 0
	if UnitInRaid("player") then
		unitbase = "raid"
		groupsize = GetNumRaidMembers()
	else
		unitbase = "party"
		groupsize = GetNumPartyMembers()
		table.insert(result, { name=UnitName("player"), average=AvgItemLevel:CalculateAverage("player") })
	end

	for i = 1, groupsize do
		local unit = unitbase..i
		local name = UnitName(unit)
		if CanInspect(unit) then
			NotifyInspect(unit)
			local avg = AvgItemLevel:CalculateAverage(unit)
			table.insert(result, {name=name, average=avg})
			ClearInspectPlayer()
		else
			table.insert(result, {name=name, average="Out of range"})
		end
	end

	table.sort(result, function(x,y) 
		if not tonumber(x.average) then return false end
		if not tonumber(y.average) then return true end
		return (x.average > y.average)
	end)

	return result
end

local offset = 0
local averages
local min, max
local avg

local function Update()
	local avgstring
	local i = 0

	for index,average in ipairs(averages) do
		avg = average.average
		i = i + 1
		local row = rows[i+offset]
		if tonumber(avg) then
			local perc = 1
			if max > min then perc = (avg-min)/(max-min) end
			avgstring = ColorGradientEscape(perc, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0) .. string.format("%.2f",avg) .. "|r"
		else
			avgstring = "|cFFFFFFFF" .. avg .. "|r"
		end
		if (i-offset) > 0 and (i-offset) <= NUMROWS then
			row.name:SetText(average.name)
			row.avg :SetText(avgstring)
			row:Show()
		end
	end
	if (i-offset) < NUMROWS then
		for j=(i-offset+1),NUMROWS do rows[j]:Hide() end
	end
end

local function Report()
	local chatType = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
	local msg

	local averages = GetGroupAverages()
	SendChatMessage("AvgItemLevel Report", chatType)
	SendChatMessage("-------------------------------", chatType)
	for index, average in ipairs(averages) do
		local name, avg = average.name, average.average
		if tonumber(avg) then avg = string.format("%.2f",avg) end
		msg = string.format("%s %s", name, avg)
		SendChatMessage(msg, chatType)
	end
end

local function Show()
	averages = GetGroupAverages()
	scroll:SetMinMaxValues(0, math.max(0, #averages))

	min, max = 500, 0   -- 239 is the highest iLevel in the game pre patch 3.2
	for index,average in ipairs(averages) do
		avg = average.average
		if tonumber(avg) and (avg < min) then min = avg end
		if tonumber(avg) and (avg > max) then max = avg end
	end

	Update()
end

local equipSlots = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT", "WRISTSLOT", "WAISTSLOT", 
	"LEGSSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "MAINHANDSLOT", }

-- Source: http://wowprogramming.com/docs/api_types#itemLocation
local ITEM_INVENTORY_BACKPACK = 0x00200000
local ITEM_INVENTORY_BAGS = 0x00400000
local MASK_BAG = 0xf00
local MASK_SLOT = 0x3f
local bagMap = {
    [0x100] = 1,
    [0x200] = 2,
    [0x400] = 3,
    [0x800] = 4,
}

local function ItemInBag(itemLocation)
    if bit.band(itemLocation, ITEM_INVENTORY_BAGS) > 0 then
        local bag = bagMap[bit.band(itemLocation, MASK_BAG)]
        local slot = bit.band(itemLocation, MASK_SLOT)
        return bag, slot
    elseif bit.band(itemLocation, ITEM_INVENTORY_BACKPACK) > 0 then
        local slot = bit.band(itemLocation, MASK_SLOT)
        return 0, slot
    end
end

local function Equip()
	local slotname
	local maxiLevel, maxiLevelItem, maxiLevelLoc
	local link, iLevel
	local used = {}
	local slot

	for i,slotname in ipairs(equipSlots) do
		maxiLevel = 0
		maxiLevelItem = ""

		slot = GetInventorySlotInfo(slotname)

		-- todo adjusted ilevel (taking quality into account)

		local inventoryItemsForSlot = GetInventoryItemsForSlot(slot) 
		for itemloc, itemid in pairs(inventoryItemsForSlot) do
			_, link, _, iLevel = GetItemInfo(itemid)
			if not used[link] and iLevel > maxiLevel then
				used[maxiLevelItem] = nil -- clear the prev one

				maxiLevel = iLevel
				maxiLevelItem = link
				maxiLevelLoc = itemloc
				used[link] = true
			end
		end

		local currentlink = GetInventoryItemLink("player", slot)
		currentiLevel = select(4, GetItemInfo(currentlink))
		if maxiLevel > currentiLevel then
			local bbag, sslot = ItemInBag(maxiLevelLoc)
			local alink = GetContainerItemLink(bbag, sslot)
			Print("Equipping " .. _G[slotname] .. ": " .. alink .. " (" .. maxiLevel .. ")")
		else
			Print("Keeping " .. _G[slotname] .. ": " .. currentlink .. " (" .. currentiLevel .. ")" )
		end

		-- See EquipCursorItem and PickupContainerItem and ClearCursor
	end   
end

local orig = scroll:GetScript("OnValueChanged")
scroll:SetScript("OnValueChanged", function(self, offset, ...)
	offset = math.floor(offset)
	Update()
	return orig(self, offset, ...)
end)

local refreshButton = LibStub("tekKonfig-Button").new(panel, "TOPRIGHT", -45, -43)
refreshButton:SetWidth(65) 
refreshButton:SetHeight(22)
refreshButton:SetText("Refresh")
refreshButton:SetScript("OnClick", Show)

local reportButton = LibStub("tekKonfig-Button").new(panel, "RIGHT", refreshButton, "LEFT", -5, 0)
reportButton:SetWidth(65) 
reportButton:SetHeight(22)
reportButton:SetText("Report")
reportButton:SetScript("OnClick", Report)

local equipButton = LibStub("tekKonfig-Button").new(panel, "RIGHT", reportButton, "LEFT", -5, 0)
equipButton:SetWidth(65) 
equipButton:SetHeight(22)
equipButton:SetText("Equip")
equipButton:SetScript("OnClick", Equip)

scroll:SetValue(0)
panel:SetScript("OnShow", Show)

SLASH_AVGITEMLEVEL1 = "/avgilevel"
SLASH_AVGITEMLEVEL2 = "/avgitemlevel"
SlashCmdList.AVGITEMLEVEL = function(msg)
	ShowUIPanel(panel)	
end
 
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:GetDataObjectByName("AvgItemLevel") or ldb:NewDataObject("AvgItemLevel", {type = "launcher", icon = "Interface\\Icons\\Ability_Vehicle_SiegeEngineRam"})
dataobj.OnClick = SlashCmdList.AVGITEMLEVEL

