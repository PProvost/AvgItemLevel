
----------------------
--      Locals      --
----------------------

local L = setmetatable({}, {__index=function(t,i) return i end})
local defaults, defaultsPC, db, dbpc = {}, {}


------------------------------
--      Util Functions      --
------------------------------

local function Print(...) print("|cFF33FF99AvgItemLevel|r:", ...) end

local debugf = tekDebug and tekDebug:GetFrame("AvgItemLevel")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end


-----------------------------
--      Event Handler      --
-----------------------------

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")


function f:ADDON_LOADED(event, addon)
	if addon:lower() ~= "avgitemlevel" then return end

	AvgItemLevelDB, AvgItemLevelDBPC = setmetatable(AvgItemLevelDB or {}, {__index = defaults}), setmetatable(AvgItemLevelDBPC or {}, {__index = defaultsPC})
	db, dbpc = AvgItemLevelDB, AvgItemLevelDBPC

	-- Do anything you need to do after addon has loaded

	LibStub("tekKonfig-AboutPanel").new("AvgItemLevel", "AvgItemLevel") -- Make first arg nil if no parent config panel

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end


function f:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")

	-- Do anything you need to do after the player has entered the world

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end


function f:PLAYER_LOGOUT()
	for i,v in pairs(defaults) do if db[i] == v then db[i] = nil end end
	for i,v in pairs(defaultsPC) do if dbpc[i] == v then dbpc[i] = nil end end

	-- Do anything you need to do as the player logs out
end


-----------------------------
--      Slash Handler      --
-----------------------------

SLASH_ADDONTEMPLATE1 = "/avgitemlevel"
SlashCmdList.ADDONTEMPLATE = function(msg)
	-- Do crap here
end
