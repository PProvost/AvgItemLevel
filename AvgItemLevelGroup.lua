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

local equipSlots = {
	["HEADSLOT"] = { "INVTYPE_HEAD" },
	["NECKSLOT"] = { "INVTYPE_NECK" },
	["SHOULDERSLOT"] = { "INVTYPE_SHOULDER" },
	["BACKSLOT"] = { "INVTYPE_CLOAK" },
	["CHESTSLOT"] = { "INVTYPE_ROBE", "INVTYPE_CHEST" },
	["WRISTSLOT"] = { "INVTYPE_WRIST" },
	["WAISTSLOT"] = { "INVTYPE_WAIST" },
	["LEGSSLOT"] = { "INVTYPE_LEGS" },
	["FEETSLOT"] = { "INVTYPE_FEET" },
	["FINGER0SLOT"] = { "INVTYPE_FINGER" },
	["FINGER1SLOT"] = { "INVTYPE_FINGER" },
	["TRINKET0SLOT"] = { "INVTYPE_TRINKET" },
	["TRINKET1SLOT"] = { "INVTYPE_TRINKET" },
	["MAINHANDSLOT"] = { "INVTYPE_2HWEAPON", "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND" },
}

local function Equip()
	local slotname
	local maxiLevel
	local maxiLevelItem 
	local found
	local itemlink
	local invTypes
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice 

	for slotname, _ in pairs(equipSlots) do
		maxiLevel = 0
		maxiLevelItem = ""

		itemlink = GetInventoryItemLink("player", GetInventorySlotInfo(slotname))
		name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemlink)
		if iLevel > maxiLevel then 
			maxiLevel = iLevel
			maxiLevelItem = itemlink
		end

		invTypes = equipSlots[slotname]

		for bag = 0,NUM_BAG_SLOTS do
			for slot = 1,GetContainerNumSlots(bag) do
				itemlink = GetContainerItemLink(bag, slot)
				if itemlink then
					name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemlink)
					if class == "Armor" or class == "Weapon" then
						found = false
						for i = 1, #invTypes do if equipSlot == invTypes[i] then found = true end end
						if found == true then
							if iLevel > maxiLevel then 
								maxiLevelItem = itemlink
								maxiLevel = iLevel 
							end
						end
					end
				end
			end
		end

		Print("Equipping " .. _G[slotname] .. ": " .. maxiLevelItem .. " (" .. maxiLevel .. ")" )
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

