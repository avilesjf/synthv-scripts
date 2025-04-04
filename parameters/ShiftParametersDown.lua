local SCRIPT_TITLE = 'Shift parameters down V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ShiftParametersDown.lua

This script will move the offset parameters to the down

Set shortcut to ALT + cursor down

2025 - JF AVILES
--]]

-- Define a class "LocalObject"
LocalObject = {
	currentMode = 2,	-- 1=up 2=down 3=left 4=right
	SCRIPT_TITLE = SCRIPT_TITLE,
	moduleName = "ShiftParametersModule",
	moduleScriptFilename = "ShiftParameters.lua",
	pathModuleScript = "/jfaviles/parameters/", -- path stored module script ShiftParametersUp.lua
	macosPath = "/Library/Application Support/Dreamtonics/Synthesizer V Studio 2/scripts/",
	windowsPath = "/AppData/Roaming/Dreamtonics/Synthesizer V Studio 2/scripts/",
	rootPath = "",
	modulePath = ""
}

-- Constructor method for the MainObject class
function LocalObject:new()
    local mainObject = {}
    setmetatable(mainObject, self)
    self.__index = self
	
	self.rootPath = self:getPathScript()
	self.modulePath = self.rootPath .. self.moduleScriptFilename

	-- Get path and load required module: ShiftParametersModule.lua	
	package.path = package.path .. ";" .. self.rootPath .. "?.lua"
	self.mainObjectModule = require(self.moduleName)
	
    return self
end

-- Get windows user profile
function LocalObject:getWindowsUserProfile()
	local userProfile = os.getenv("USERPROFILE")
	userProfile = string.gsub(userProfile,"\\","/")
	userProfile = string.gsub(userProfile,"//","/")	
	return userProfile
end

-- Get path scripts
function LocalObject:getPathScript()
	local osType = SV:getHostInfo().osType -- "macOS", "Linux", "Unknown", "Windows"
	local path = ""
	
	if osType ~= "Windows" then	
		-- "macOS", "Linux", "Unknown"
		path = self.macosPath .. self.pathModuleScript
	else
		-- Windows
		local userProfile = self.getWindowsUserProfile()
		if #userProfile > 0 then
			path = userProfile .. self.windowsPath .. self.pathModuleScript
		else
			path = self.windowsPath .. self.pathModuleScript
			settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Path not found!"), path)
		end
	end
	return path
end

-- Standard Synthesizer script call
function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Parameters",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

-- Main process
function main()
	localObject = LocalObject:new()	
	if not localObject.mainObjectModule then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Module: ") .. localObject.moduleName .. " " .. SV:T("not found!"))
	else
		local mainObject = MainObject:new(SCRIPT_TITLE, localObject.currentMode)
		mainObject:start()
	end
		
	SV:finish()
end