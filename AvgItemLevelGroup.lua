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
	local averages = {}
	local unitbase
	local groupsize = 0
	if UnitInRaid("player") then
		unitbase = "raid"
		groupsize = GetNumRaidMembers()
	else
		unitbase = "party"
		groupsize = GetNumPartyMembers()
		averages[UnitName("player")] = AvgItemLevel:CalculateAverage("player")
	end

	for i = 1, groupsize do
		local unit = unitbase..i
		local name = UnitName(unit)
		if CanInspect(unit) then
			NotifyInspect(unit)
			local avg = AvgItemLevel:CalculateAverage(unit)
			averages[name] = avg 
			ClearInspectPlayer()
		else
			averages[name] = "Out of range"
		end
	end
	return averages
end

local offset = 0
local function Update()
	local averages = GetGroupAverages()
	scroll:SetMinMaxValues(0, math.max(0, #averages))

	local avgstring
	local i = 0
	local min, max = 239, 0   -- 239 is the highest iLevel in the game pre patch 3.2
	for _,avg in pairs(averages) do
		if avg < min then min = avg end
		if avg > max then max = avg end
	end
	for name, avg in pairs(averages) do
			i = i + 1
			local row = rows[i-offset]
			local perc = (avg-min)/(max-min)
			if (i-offset) > 0 and (i-offset) <= NUMROWS then
				row.name:SetText(name)
				if tonumber(avg) then
					avgstring = ColorGradientEscape(perc, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0) .. string.format("%.2f",avg) .. "|r"
				else
					avgstring = "|cFFFFFFFF" .. avg .. "|r"
				end
				row.avg:SetText(avgstring)
				row:Show()
			end
	end
	if (i-offset) < NUMROWS then
		for j=(i-offset+1),NUMROWS do rows[j]:Hide() end
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
refreshButton:SetScript("OnClick", Update)

scroll:SetValue(0)
panel:SetScript("OnShow", Update)

SLASH_AVGITEMLEVEL1 = "/avgilevel"
SLASH_AVGITEMLEVEL2 = "/avgitemlevel"
SlashCmdList.AVGITEMLEVEL = function(msg)
	ShowUIPanel(panel)	
end
 
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:GetDataObjectByName("AvgItemLevel") or ldb:NewDataObject("AvgItemLevel", {type = "launcher", icon = "Interface\\Icons\\Ability_Vehicle_SiegeEngineRam"})
dataobj.OnClick = SlashCmdList.AVGITEMLEVEL

