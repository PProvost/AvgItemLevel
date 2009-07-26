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
	for name, avg in pairs(averages) do
			i = i + 1
			local row = rows[i-offset]
			if (i-offset) > 0 and (i-offset) <= NUMROWS then
				row.name:SetText(name)
				if tonumber(avg) then
					if avg >= 220 then
						avgstring = "|cFF00FF00" .. string.format("%.2f", avg) .. "|r"
					elseif avg >= 210 then
						avgstring = "|cFFFFFF00" .. string.format("%.2f", avg) .. "|r"
					else
						avgstring = "|cFFFF0000" .. string.format("%.2f", avg) .. "|r"
					end
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

