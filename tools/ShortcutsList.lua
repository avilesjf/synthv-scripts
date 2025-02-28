local SCRIPT_TITLE = 'ShortcutsList V1.3'

--[[

lua file name: ShortcutsList.lua

List all defined shortcuts from settings.xml
And copy result into the Clipboard.
Detecting duplicates & display Keyboard mapping

!! Search variables settingsPath below in this script to update them for your own system (MAC, International) !!

Example:
-------------------------
Keyboard:
<?xml version="1.0" encoding="UTF-8"?>

<KEYMAPPINGS basedOnDefaults="1">
  <MAPPING commandId="6001" description="Rescan" key="..."/>
</KEYMAPPINGS>
-------------------------
Defined:
<ScriptItem name="Lyrics tracks to Clipboard V1.0" keyMapping=="ctrl + shift + L"/>
<ScriptItem name="Group name udate V1.0" keyMapping=="ctrl + shift + R"/>
<ScriptItem name="Group name update V1.0" keyMapping=="ctrl + shift + R"/>
<ScriptItem name="Groups name update All V1.0" keyMapping=="ctrl + shift + U"/>
<ScriptItem name="Lyrics tracks in .SRT format to Clipboard V1.0" keyMapping=="ctrl + shift + L"/>
...
-------------------------
Duplicates: 
ShortcutsList V1.0 = ctrl + shift + O
ShortcutsList V1.2 = ctrl + shift + O
...
-------------------------
Not defined:
<ScriptItem name="Merge Selected Notes" keyMapping==""/>
<ScriptItem name="Play with Smooth Page Turning" keyMapping==""/>
<ScriptItem name="Randomize Parameters" keyMapping==""/>
<ScriptItem name="Remove Short Silences" keyMapping==""/>
<ScriptItem name="Scale Selected Notes" keyMapping==""/>
<ScriptItem name="Silence Skipping Play" keyMapping==""/>
<ScriptItem name="Split Selected Groups" keyMapping==""/>
<ScriptItem name="Split Selected Notes" keyMapping==""/>
<ScriptItem name="add cl to the beginning of selected phonemes" keyMapping==""/>
...
-------------------------
Defined:
Add Breaths											 => ctrl + shift + B
Move Note Down										 => ctrl + cursor down
Move Note Up										 => ctrl + cursor up
Move Notes Down										 => ctrl + shift + cursor down
Move Notes Up										 => ctrl + shift + cursor up
Clear parameters V1.0								 => ctrl + alt + #b2 (²)
Clear the clipboard content V1.0					 => ctrl + shift + #b2 (²)
Copy/Paste all parameters for group notes V1.0		 => ctrl + #b2 (²)
...
-------------------------
Not defined:
Add Minus, Add Note, Add Plus, ...
Clone Parameter Curve, Continuous Scroll, ...
...
-------------------------

To get the script path files:
update variable isScriptPathActive = true
..
Scripts path files:
Add Breaths	C:/Users/username/OneDrive/Documents/Dreamtonics/Synthesizer V Studio/scripts/impkit/addbreaths.lua

Note: Not tested in the MACOS env.
-------------------------

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Settings full path for file settings.xml", "Settings full path for file settings.xml"},
			{"Cannot find automatically the settings path. Please insert the full path here:", "Cannot find automatically the settings path. Please insert the full path here:"},
			{"Cannot find user profile. Please insert the full path here:", "Cannot find user profile. Please insert the full path here:"},
			{"File not found!", "File not found!"},
			{"Defined:", "Defined:"},
			{"Keyboard:", "Keyboard:"},
			{"Not defined:", "Not defined:"},
			{"Scripts path files:", "Scripts path files:"},
			{"Error on files script title not found!, see logs copied into your clipboard.", "Error on files script title not found!, see logs copied into your clipboard."},
			{"Duplicates: ", "Duplicates: "},
			{"Count", "Count"},
			{"Shortcuts:", "Shortcuts:"},
			{"All data copied to clipboard!", "All data copied to clipboard!"},
			{"settingsPath: ", "settingsPath: "},
			{"Error in parsing XML file!", "Error in parsing XML file!"},
			{"Cannot find automatically the script folder path. Please insert the folder path here:", "Cannot find automatically the script folder path. Please insert the folder path here:"},
			{"No such file or directory", "No such file or directory"},
		},
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 3,
		minEditorVersion = 65540
	}
end

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	winSepCharPath = "/",
	winSettingsPathEnd = "/Dreamtonics/Synthesizer V Studio/settings/",
	macosPathSettings = "/Library/Application Support/Dreamtonics/Synthesizer V Studio/settings/",
	settingsFile = "settings.xml",
	winScriptPathBegin = "OneDrive", -- C:\Users\YOUR_USER_NAME\OneDrive\Documents\Dreamtonics\Synthesizer V Studio\Script
	winScriptPathDocument = "Documents", -- "/Documenti", etc.
	winScriptPathEnd = "/Dreamtonics/Synthesizer V Studio/scripts/",
	macosPath = "/Library/Application Support/Dreamtonics/Synthesizer V Studio/Script/",
	scriptFile = "/Utilities/RandomizeParameters.lua",
	limitStringDisplay = 2000,
	htmlChars = {{"&lt;", "<"}, {"&quot;", "\""}, {"&gt;", ">"}, {"&#13;", "\r"}, {"&#10;", "\n"}},
	duplicatesShortcuts = {},
	DEBUG = false,
	isScriptPathActive = false, -- To get the script path of each files with shortcuts enabled
	jsScriptTitle = "SCRIPT_TITLE =",
	luaScriptTitle = "SCRIPT_TITLE =",
	functionScript = "getClientInfo",
	functionReturnScript = "return {",
	nameScript = "name",
	scriptFilesLua = {},
	scriptFilesJs = {},
	scriptFilesNotScript = {},
	hostinfo = nil,
	osType = "",
	osName = "",
	hostName = "",
	languageCode = "", 
	hostVersion = "",
	hostVersionNumber = 0
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()

	notesObject.hostinfo = SV:getHostInfo()
	notesObject.osType = notesObject.hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	notesObject.osName = notesObject.hostinfo.osName
	notesObject.hostName = notesObject.hostinfo.hostName
	notesObject.languageCode = notesObject.hostinfo.languageCode
	notesObject.hostVersion = notesObject.hostinfo.hostVersion
	notesObject.hostVersionNumber = notesObject.hostinfo.hostVersionNumber
	
    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end
-- Add internal logs
function NotesObject:logsAdd(new)
	if self.DEBUG then self.logs = self.logs .. new end
end

-- Clear internal logs
function NotesObject:logsClear()
	if self.DEBUG then self.logs = "" end
end

-- Display logs
function NotesObject:logsShow()
	if self.DEBUG then 
		self:show(self.logs)
	end
end

-- Get file path settings
function NotesObject:getFilePathSettings(documents)
	local hostinfo = SV:getHostInfo()
	local osType = hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	local settingsFilePath = ""
	local settingsFolder = ""
	local settingsPathTitle = SV:T("Settings full path for file settings.xml")
	local settingsErrorText = SV:T("Cannot find automatically the settings path. Please insert the full path here:")
	local settingsErrorUserProfileText = SV:T("Cannot find user profile. Please insert the full path here:")

	if osType ~= "Windows" then	
		-- "macOS", "Linux", "Unknown"
		settingsFilePath = self.macosPathSettings .. self.settingsFile
		if not self:isFileExists(settingsFilePath) then
			settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorText, settingsFilePath)
		end
	else
		-- Windows
		local userProfile = self:getWindowsUserProfile()
		if userProfile then
			-- if direct
			settingsFolder = userProfile .. self.winSepCharPath .. documents 
							.. self.winSettingsPathEnd
			settingsFilePath = settingsFolder .. self.settingsFile				
			if not self:isFileExists(settingsFilePath) then
				-- trying with adding OneDrive
				settingsFolder = userProfile 
								.. self.winSepCharPath 
								.. self.winScriptPathBegin 
								.. self.winSepCharPath 
								.. documents
								.. self.winSettingsPathEnd
				settingsFilePath = settingsFolder .. self.settingsFile
				if not self:isFileExists(settingsFilePath) then
					settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorText, settingsFilePath)
				end
			end
		else
			settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorUserProfileText, settingsFilePath)
		end
	end
	return settingsFilePath
end
	
-- Check if file exists
function NotesObject:isFileExists(fileName)
	local result = false
	local file = io.open(fileName, "r")
	if file ~= nil then
		io.close(file)
		result = true
	end
	return result
end

-- Start process
function NotesObject:start()
	local returnValue = false
	
	-- settings file path:
	-- C:\Users\YOUR_USER_NAME\OneDrive\Documents\Dreamtonics\Synthesizer V Studio\settings\settings.xml
	-- "/Library/Application Support/Dreamtonics/Synthesizer V Studio/settings/settings/settings.xml
	local settingsPath = self:getFilePathSettings(self.winScriptPathDocument)
	local fileNotFoundTitle = SV:T("File not found!")
	local definedTitle = SV:T("Defined:")
	local keyboardDefinedTitle = SV:T("Keyboard:")
	local notDefinedTitle = SV:T("Not defined:")
	local scriptPathTitle = SV:T("Scripts path files:")
	local keyMapping = "@keyMapping"
	local keyName = "@name"
	local sepCharDisplay = ", "
	local keymaps = {}
	local keyboardMapping = ""
	local scriptsFilePath = {}
	local xml = newParser()	

	self:logsClear()
	if self.isScriptPathActive then
		local iErrorOnFile = 0
		self.scriptFilesLua, self.scriptFilesJs, self.scriptFilesNotScript, iErrorOnFile = self:getScriptFileList()
		if iErrorOnFile > 0 then
			self:show(SV:T("Error on files script title not found!, see logs copied into your clipboard."))
			SV:setHostClipboard(self.logs)
			self:logsShow()
			
			return returnValue
		end
	end

	local fhandle = io.open(settingsPath, 'r')
	
	if fhandle == nil then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), fileNotFoundTitle .. " : " .. settingsPath)
	else
		-- read file
		local data = fhandle:read("*a")
		io.close(fhandle)
		
		local errorXML = true
		local parsedXml = xml:ParseXmlText(data)
		local sepline = "\r" .. "-------------------------" .. "\r"
		local seplineTitle = "-------------------------" .. "\r"
		
		if parsedXml.ApplicationSettings ~= nil then 				
			if parsedXml.ApplicationSettings.Keyboard ~= nil then 
				if parsedXml.ApplicationSettings.Keyboard[keyMapping] ~= nil then 
					local KeyboardKeyMapping = parsedXml.ApplicationSettings.Keyboard[keyMapping]
					if string.len(KeyboardKeyMapping) > 0 then
						keyboardMapping = self:getHTMLToText(KeyboardKeyMapping)
					end
				end					
			end
			
			if parsedXml.ApplicationSettings.Scripts ~= nil then 
				if parsedXml.ApplicationSettings.Scripts.ScriptItem ~= nil then 
					local result = ""
					local resultForDisplayOnly = definedTitle .. "\r"
					local resultForDisplayOnlyLine = ""
					local displayLimitNotDefined = 100
					local tabCharCount = 4
					local scriptItem = parsedXml.ApplicationSettings.Scripts.ScriptItem
					local displayLimitDefined =  self:getMaxLengthScriptName(scriptItem)
					
					if string.len(keyboardMapping) > 0 then
						result = result .. seplineTitle
						result = result .. keyboardDefinedTitle .. "\r"
						result = result .. keyboardMapping
						result = result .. sepline
					end
					
					result = result .. definedTitle .. "\r"
					-- Defined
					for iItem = 1, #scriptItem do
						local keyMap = scriptItem[iItem][keyMapping]
						if string.len(keyMap)> 0 then
							local scriptName = scriptItem[iItem][keyName]
							result = result .. self:getFormatScriptItem(scriptName, keyMap)
							local tabCount = self:getScriptNameTabs(tabCharCount, displayLimitDefined, scriptName)
							local tabs = string.rep("\t", tabCount)
							local scriptFilePath = ""
							
							if self.isScriptPathActive then
								scriptFilePath = self:findScriptPath(scriptName)
							end
							
							keyMap = self:getSpecialKeymap(keyMap) -- if #b2 => adding (²) for info only
							resultForDisplayOnly = resultForDisplayOnly .. scriptName .. tabs .. " => ".. keyMap .. "\r"
							
							table.insert(keymaps, {scriptName, keyMap, iItem})
							
							if self.isScriptPathActive and #scriptFilePath > 0 then
								table.insert(scriptsFilePath, {scriptName, scriptFilePath})
							end
						end
					end
					
					-- Check if duplicate shortcuts exists
					self.duplicatesShortcuts = self:getDuplicateShortcuts(keymaps)
					
					if #self.duplicatesShortcuts > 0 then
						local resultSC = self:getDisplayDuplicateShortcuts(self.duplicatesShortcuts)
						
						result = result .. sepline
						result = result .. SV:T("Duplicates: ") .. "\r"
						result = result .. resultSC
						resultForDisplayOnly = resultForDisplayOnly .. sepline
						resultForDisplayOnly = resultForDisplayOnly .. SV:T("Duplicates: ") .. "\r"
						resultForDisplayOnly = resultForDisplayOnly .. resultSC
					end
					
					-- Not Defined
					result = result .. sepline
					result = result .. notDefinedTitle .. "\r"
					resultForDisplayOnly = resultForDisplayOnly .. sepline
					resultForDisplayOnly = resultForDisplayOnly .. notDefinedTitle .. "\r"

					-- Not defined
					for iItem = 1, #scriptItem do
						local keyMap = scriptItem[iItem][keyMapping]
						if string.len(keyMap) == 0 then
							-- <ScriptItem name="Lyrics tracks to Clipboard V1.0" keyMapping="ctrl + shift + L"/>
							local scriptName = scriptItem[iItem][keyName]
							result = result .. self:getFormatScriptItem(scriptName, "")
							resultForDisplayOnly     = resultForDisplayOnly .. scriptName .. sepCharDisplay
							resultForDisplayOnlyLine = resultForDisplayOnlyLine .. scriptName .. sepCharDisplay
							
							-- Adding return on string limit to displayLimit
							if string.len(resultForDisplayOnlyLine) > displayLimitNotDefined then
								resultForDisplayOnly = resultForDisplayOnly .. "\r"
								resultForDisplayOnlyLine = ""
							end
							
						end
					end						
					resultForDisplayOnly = resultForDisplayOnly .. sepline
					
					if #scriptsFilePath > 0 then
						result = result .. sepline
						result = result .. scriptPathTitle .. "\r"
						-- Scripts path files
						for iItem = 1, #scriptsFilePath do
							local scriptFilename = scriptsFilePath[iItem][1]
							local scriptPathFilename = scriptsFilePath[iItem][2]
							result = result .. scriptFilename .. "\t".. scriptPathFilename .. "\r"
						end
						result = result .. SV:T("Count") .. " : ".. #scriptsFilePath .. "\r"
					end
					
					errorXML = false
					returnValue = true
					SV:setHostClipboard(result .. sepline .. resultForDisplayOnly)
					SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Shortcuts:") .. "\r" 
						.. string.sub(resultForDisplayOnly,1, self.limitStringDisplay) 
						.. "\r"
						.. "..."
						.. "\r" 
						.. SV:T("All data copied to clipboard!"))
				end
			end
		end
		
		if errorXML then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("settingsPath: ") 
								.. settingsPath .. "\r" 
								.. SV:T("Error in parsing XML file!"))
		end
	end
	return returnValue
end
	
-- get HTML to text
function NotesObject:getHTMLToText(KeyboardKeyMapping)
	local text = KeyboardKeyMapping
	
	for iHTMLKeys = 1, #self.htmlChars do
		text = text:gsub(self.htmlChars[iHTMLKeys][1], 
			self.htmlChars[iHTMLKeys][2])
	end
	
	return text
end
	
-- Check doublon
function NotesObject:getDuplicateShortcuts(keymaps)
	local keymapsSortedSC = {}
	local duplSC = {}
	local duplSCResult = {}
	
	for iSC = 1, #keymaps do
		table.insert(keymapsSortedSC, keymaps[iSC][2])
	end
	
	table.sort(keymapsSortedSC, 
		function(a, b)
			return a > b
		end
	)
	
	-- Find duplicates
	local oldSC = ""
	for iSC = 1, #keymapsSortedSC do
		if oldSC == keymapsSortedSC[iSC] then 
			table.insert(duplSC, keymapsSortedSC[iSC])
		end
		oldSC = keymapsSortedSC[iSC]
	end
	
	-- if duplicated shortcuts found, build a complete result array
	for iSC = 1, #keymaps do
		-- Check if shortcut exists into the duplicates array
		for iDuplicatesSC = 1, #duplSC do
			if duplSC[iDuplicatesSC] == keymaps[iSC][2] then
				-- Get keymaps existing item found in duplicates array
				table.insert(duplSCResult, {keymaps[iSC][1], keymaps[iSC][2]})
			end
		end
	end
		
	return duplSCResult
end
	
-- Get duplicate shortcuts to display
function NotesObject:getDisplayDuplicateShortcuts(duplicatesSC)
	local resultSC = ""
	
	for iSC = 1, #duplicatesSC do
		resultSC = resultSC .. table.concat(duplicatesSC[iSC], " = ") .. "\r"
	end
	return resultSC
end

-- Get scripts file list
function NotesObject:getScriptFileList()
	local scriptFilesLua = {}
	local scriptFilesJs = {}
	local scriptFilesNotScript = {}
	local folderPath = self:getScriptsPath()
	local iErrorOnFile = 0
	if folderPath ~= nil and #folderPath > 0 then
		local luaExtension = ".lua" -- limit to lua scripting files
		local jsExtension = ".js" -- limit to lua scripting files
		local fileIsExtension = false
		folderlist, full_folderlist = self:listFiles(folderPath)
			
		for k, filePath in pairs(full_folderlist) do
			fileIsExtension = false
			
			if filePath ~= nil and #filePath > 0 then
				
				-- lua scripting files
				if string.find(filePath, luaExtension, 1, true) ~= nil then
					local titleFile, iError = self:fileProcess(filePath, self.luaScriptTitle)
					iErrorOnFile = iErrorOnFile + iError
					if titleFile ~= nil and #titleFile > 0 then
						table.insert(scriptFilesLua, {filePath, titleFile})
					end					
					fileIsExtension = true
				end
				-- js scripting files
				if string.find(filePath, jsExtension, 1, true) ~= nil then
					local titleFile, iError = self:fileProcess(filePath, self.jsScriptTitle)
					iErrorOnFile = iErrorOnFile + iError
					if titleFile ~= nil and #titleFile > 0 then
						table.insert(scriptFilesJs, {filePath, titleFile})
					end
					fileIsExtension = true
				end
				-- not a script file
				if not fileIsExtension then
					table.insert(scriptFilesNotScript, {filePath, ""})
				end
			end
		end
		-- self:show("filesPathList:\r" .. table.concat(filesPathList, "\r"))
		-- self:show("filesList:\r" .. table.concat(filesList, "\r"))
	end
	return scriptFilesLua, scriptFilesJs,scriptFilesNotScript, iErrorOnFile
end

-- List files in folder
function NotesObject:listFiles(directory)
    local i, dir, popen = 0, {}, io.popen
	local full_dir = {}
    local pfile
	
	if self.osType ~= "Windows" then
		local tempfilename = os.tmpname()
		os.execute([[ls -d ]] .. directory .. [[*/ >> ]] .. tempfilename)
		
		if self:isFileExists(tempfilename) then
			pfile = lines_from(tempfilename)
			os.remove(tempfilename)
			
			for _,foldername in pairs(pfile) do
				local testname = string.lower(foldername)
				if string.find(testname,"ignore") == nil then
					if string.find(testname, ".lua", 1, true) ~= nil or 
						string.find(testname, ".js", 1, true) ~= nil then
						foldername = string.gsub(foldername,"//","/")
						i = i + 1
						full_dir[i] = foldername
						local start = 0, searchnew, searchold
						
						while true do
						  start = string.find(foldername, "/", start+1)    -- find 'next' newline
						  if start == nil then break end
						  searchold = searchnew
						  searchnew = start
						end
						dir[i] = string.sub(foldername,searchold+1)		
						dir[i] = string.gsub(dir[i],"/","")
					end
					-- Check if it's a subfolder
					if string.find(testname, ".lua", 1, true) == nil and 
						string.find(testname, ".js", 1, true) == nil then
						local subfolder = directory .. testname .. self:getSepPathChar()
						local dir2, full_dir2 = self:listFiles(subfolder)
						if #full_dir2 > 0 then
							for k, filePath in pairs(full_dir2) do
								table.insert(dir, dir2[k])
								table.insert(full_dir, filePath)
							end
						end
					end
					
				end	
			end
		end	
	else
		local cmd = 'dir "'..directory..'" /b'
		pfile = popen(cmd)
		for filename in pfile:lines() do
			local testname = string.lower(filename)
			if string.find(testname,"ignore") == nil then
				if string.find(testname, ".lua", 1, true) ~= nil or 
					string.find(testname, ".js", 1, true) ~= nil then
					-- self:logsAdd(directory .. filename .. "\r")
					if self:isFileExists(directory .. filename) then
						i = i + 1
						dir[i] = filename
						full_dir[i] = directory .. filename
					end
				end
				
				-- Check if it's a subfolder
				if string.find(testname, ".", 1, true) == nil then
					local subfolder = directory .. testname .. self:getSepPathChar()
					local dir2, full_dir2 = self:listFiles(subfolder)
					if #full_dir2 > 0 then
						for k, filePath in pairs(full_dir2) do
							table.insert(dir, dir2[k])
							table.insert(full_dir, filePath)
						end
					end
				end
			end			
		end
		pfile:close()
		
	end	
    return dir, full_dir
end

-- Get clean separator filename
function NotesObject:getCleanSeparatorFilename(filename)
	if #filename > 0 then
		if string.find(filename, '\\') ~= nil then
			filename = filename:gsub('\\', '/')
		end
		if string.find(filename, '//') ~= nil then
			filename = filename:gsub('//', '/')
		end
	end
	return filename
end

-- Get separator path char
function NotesObject:getSepPathChar()
	local sepPath = "/"
	-- check if it's a subfolder
	if self.osType ~= "Windows" then	
		sepPath = "/"
	end
	return sepPath
end

-- Read file content
function NotesObject:readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

-- File processing
function NotesObject:fileProcess(file, scriptTitle)
	-- Process one file
	local scriptLines = {}
	local scriptContent = self:readAll(file)
	local result = ""
	local iFunction = 0
	local iMax = 0
	local iError = 0
	if scriptContent ~= nil then
		if #scriptContent > 0 then
			scriptLines = self:split(scriptContent, "\r\n")
			
			for iPos = 1, #scriptLines do
				iMax = iPos
				local line = scriptLines[iPos]
				if string.find(string.lower(line), string.lower(scriptTitle)) ~= nil then
					result = line
					break
				end
				-- Find function getClientInfo()
				if string.find(string.lower(line), string.lower(self.functionScript)) ~= nil then
					iFunction = iFunction + 1
				end
				-- Find return {
				if string.find(string.lower(line), string.lower(self.functionReturnScript)) ~= nil then
					iFunction = iFunction + 1
				end
				-- Find name = or "name": eg: "name": "Tuner" name = "Hello World (Lua)"
				if iFunction == 2 and 
					string.find(string.lower(line), string.lower(self.nameScript)) ~= nil then
					result = self:getCleanScriptName(line)
					break
				end
			end
			if iMax == #scriptLines then
				iError = iError + 1
				self:logsAdd("Nothing found in this script file! " .. file .. ", title: " .. scriptTitle .. "\r")
			end
		end
	end
	return result, iError
end

-- Get clean script name
function NotesObject:getCleanScriptName(line)
	local name = ""
	-- if js script
	if string.find(line, ":") then
		-- function getClientInfo() {
			-- return {
				-- "name": "Tuner",
		local lineArray = self:split(line, ':')
		-- "Tuner",
		name = lineArray[2]
	end
	-- if lua script
	if string.find(line, "=") then
		-- function getClientInfo()
		  -- return {
			-- name = "Hello World (Lua)",
		  local lineArray = self:split(line, '=')
		  -- name = "Hello World (Lua)",
		  name = lineArray[2]
	end
	
	if name ~= nil and #name > 0 then
		name = string.gsub(name, ",", "")
		name = string.gsub(name, '"', '')
	end
	
	return name
end

-- Split string by sep char
function NotesObject:split(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
	  table.insert(result, each)
   end
   return result
end

-- Find script path
function NotesObject:findScriptPath(scriptName)
	local scriptFilePath = ""
	local isFound = false
	
	-- Find in lua files
	for ifile = 1, #self.scriptFilesLua do
		if string.find(string.lower(self.scriptFilesLua[ifile][2]), string.lower(scriptName)) ~= nil then
			scriptFilePath = self.scriptFilesLua[ifile][1]
			isFound = true
			break
		end
	end
	
	-- Find in js files
	if not isFound then
		for ifile = 1, #self.scriptFilesJs do
			if string.find(string.lower(self.scriptFilesJs[ifile][2]), string.lower(scriptName)) ~= nil then
				scriptFilePath = self.scriptFilesJs[ifile][1]
				isFound = true
				break
			end
		end
	end
	
	return scriptFilePath
end

-- Get xml format for script item
function NotesObject:getFormatScriptItem(item, keymap)
	local scriptItemBegin = "<ScriptItem name="
	local scriptItemKeyMapping = "keyMapping="
	local scriptItemEnd = "/>"
	local sepQuote = "\""
	
	local result = scriptItemBegin .. sepQuote .. item .. sepQuote 
		.. " " 
		.. scriptItemKeyMapping .. sepQuote .. keymap .. sepQuote 
		.. scriptItemEnd .. "\r"
		
	return result
end

-- Get tabs for script name
function NotesObject:getScriptNameTabs(tabCharCount, maxLine, scriptName)
	local scriptLen = string.len(scriptName)
	local maxTabCount = math.floor((maxLine + tabCharCount) / tabCharCount)
	local scriptTabCount = math.floor(scriptLen / tabCharCount)

	return maxTabCount - scriptTabCount
end

-- Get max string name with shortcuts dedined
function NotesObject:getMaxLengthScriptName(scriptItem)
	local maxLength = 0
	local currentLength = 0
	
	-- Defined
	for iItem = 1, #scriptItem do
		local keyMap = scriptItem[iItem]["@keyMapping"]
		
		if string.len(keyMap)> 0 then
			local scriptName = scriptItem[iItem]["@name"]
			currentLength = string.len(scriptName)
			
			if currentLength > maxLength then
				maxLength = currentLength
			end
		end
	end

	return maxLength
end
	
-- Get special keymap
function NotesObject:getSpecialKeymap(keyMap)
	if string.find(keyMap, "#b2") ~= nil then 
		keyMap = keyMap .. " (²)" 
	end
	return keyMap
end
	
-- Get Scripts path
function NotesObject:getScriptsPath()
	local scriptFilePath = ""
	local scriptFolder = ""
	local scriptErrorText = SV:T("Cannot find automatically the script folder path. Please insert the folder path here:")
	local scriptErrorUserProfileText = SV:T("Cannot find user profile. Please insert the full path here:")
	
	if self.osType ~= "Windows" then	
		-- "macOS", "Linux", "Unknown"
		scriptFilePath = self.macosPath
		if not self:isFolderExists(scriptFilePath) then
			scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorText, scriptFilePath)
		end
	else
		-- Windows
		local userProfile = self:getWindowsUserProfile()
		if userProfile then
			-- if direct
			scriptFolder = userProfile .. self.winSepCharPath .. self.winScriptPathDocument 
							.. self.winScriptPathEnd
			scriptFilePath = scriptFolder
			if not self:isFolderExists(scriptFilePath) then
				-- trying with adding OneDrive
				scriptFolder = userProfile 
								.. self.winSepCharPath 
								.. self.winScriptPathBegin 
								.. self.winSepCharPath 
								.. self.winScriptPathDocument
								.. self.winScriptPathEnd
				scriptFilePath = scriptFolder
				if not self:isFolderExists(scriptFilePath) then
					scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorText, scriptFilePath)
				end
			end
		else
			scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorUserProfileText, "")
		end
	end
	return scriptFilePath
end

-- Get windows user profile
function NotesObject:getWindowsUserProfile()
	local userProfile = os.getenv("USERPROFILE")
	userProfile = string.gsub(userProfile,"\\","/")
	userProfile = string.gsub(userProfile,"//","/")	
	return userProfile
end

-- Check if folder exists
function NotesObject:isFolderExists(folderName)
  local fileHandle, error = io.open(folderName .. "/*.*", "r")
  if fileHandle ~= nil then
    io.close(fileHandle)
    return true
  else
	-- be carefull! Text returned by os system
    if string.match(error, SV:T("No such file or directory")) then
      return false
    else
      return true
    end
  end
end

-- Main function
function main()
	local notesObject = NotesObject:new()
	notesObject:start()
	
	SV:finish()
end

-- Github: Cluain simple xmlParser
function newParser()
	-- Github: Cluain
	-- https://github.com/Cluain/Lua-Simple-XML-Parser/blob/master/xmlTest.lua
    XmlParser = {}

    function XmlParser:ToXmlString(value)
        value = string.gsub(value, "&", "&amp;"); -- '&' -> "&amp;"
        value = string.gsub(value, "<", "&lt;"); -- '<' -> "&lt;"
        value = string.gsub(value, ">", "&gt;"); -- '>' -> "&gt;"
        value = string.gsub(value, "\"", "&quot;"); -- '"' -> "&quot;"
        value = string.gsub(value, "([^%w%&%;%p%\t% ])",
            function(c)
                return string.format("&#x%X;", string.byte(c))
            end)
        return value
    end

    function XmlParser:FromXmlString(value)
        value = string.gsub(value, "&#x([%x]+)%;",
            function(h)
                return string.char(tonumber(h, 16))
            end)
        value = string.gsub(value, "&#([0-9]+)%;",
            function(h)
                return string.char(tonumber(h, 10))
            end)
        value = string.gsub(value, "&quot;", "\"")
        value = string.gsub(value, "&apos;", "'")
        value = string.gsub(value, "&gt;", ">")
        value = string.gsub(value, "&lt;", "<")
        value = string.gsub(value, "&amp;", "&")
        return value
    end

    function XmlParser:ParseArgs(node, s)
        string.gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
            node:addProperty(w, self:FromXmlString(a))
        end)
    end

    function XmlParser:ParseXmlText(xmlText)
        local stack = {}
        local top = newNode()
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
            if not ni then break end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top:value() or "") .. self:FromXmlString(text)
                stack[#stack]:setValue(lVal)
            end
            if empty == "/" then -- empty element tag
                local lNode = newNode(label)
                self:ParseArgs(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then -- start tag
                local lNode = newNode(label)
                self:ParseArgs(lNode, xarg)
                table.insert(stack, lNode)
		top = lNode
            else -- end tag
                local toclose = table.remove(stack) -- remove top

                top = stack[#stack]
                if #stack < 1 then
                    error("XmlParser: nothing to close with " .. label)
                end
                if toclose:name() ~= label then
                    error("XmlParser: trying to close " .. toclose.name .. " with " .. label)
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        local text = string.sub(xmlText, i);
        if #stack > 1 then
            error("XmlParser: unclosed " .. stack[#stack]:name())
        end
        return top
    end

    function XmlParser:loadFile(xmlFilename, base)
        if not base then
            base = system.ResourceDirectory
        end

        local path = system.pathForFile(xmlFilename, base)
        local hFile, err = io.open(path, "r")

        if hFile and not err then
            local xmlText = hFile:read("*a") -- read file content
            io.close(hFile)
            return self:ParseXmlText(xmlText), nil
        else
            print(err)
            return nil
        end
    end

    return XmlParser
end

function newNode(name)
    local node = {}
    node.___value = nil
    node.___name = name
    node.___children = {}
    node.___props = {}

    function node:value() return self.___value end
    function node:setValue(val) self.___value = val end
    function node:name() return self.___name end
    function node:setName(name) self.___name = name end
    function node:children() return self.___children end
    function node:numChildren() return #self.___children end
    function node:addChild(child)
        if self[child:name()] ~= nil then
            if type(self[child:name()].name) == "function" then
                local tempTable = {}
                table.insert(tempTable, self[child:name()])
                self[child:name()] = tempTable
            end
            table.insert(self[child:name()], child)
        else
            self[child:name()] = child
        end
        table.insert(self.___children, child)
    end

    function node:properties() return self.___props end
    function node:numProperties() return #self.___props end
    function node:addProperty(name, value)
        local lName = "@" .. name
        if self[lName] ~= nil then
            if type(self[lName]) == "string" then
                local tempTable = {}
                table.insert(tempTable, self[lName])
                self[lName] = tempTable
            end
            table.insert(self[lName], value)
        else
            self[lName] = value
        end
        table.insert(self.___props, { name = name, value = self[name] })
    end

    return node
end