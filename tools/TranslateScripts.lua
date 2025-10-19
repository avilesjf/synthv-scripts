local SCRIPT_TITLE = 'Translate scripts V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: TranslateScripts.lua

Retrieving all SV:T(text) found inside a script
and generate a getTranslations function 
with all text found into the clipboard

Set askForScriptFile = true to display an input box
	if false variable "scriptFile" is used, set your .lua file below (class "NotesObject")
Set isMultipleScript = true to loop all files into subfolders
	note: if true askForScriptFile is not used
Set	isFilterSubfolder = true to filter a specific subfolder
	mode used only if isMultipleScript = true
	to specify the filtered subfolder update the variable: filterSubfolder
Note: Not tested in the MACOS env.

2025 - JF AVILES
--]]

-- Translate SV:T text to display
function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

-- Text to display into the corresponding language
function getArrayLanguageStrings()
	return {
		["en-us"] = { -- English
			{"No such file or directory", "No such file or directory"},
			{"Cannot find automatically the script path. Please insert the full path here:", "Cannot find automatically the script path. Please insert the full path here:"},
			{"Cannot find user profile. Please insert the full path here:", "Cannot find user profile. Please insert the full path here:"},
			{"Cannot find automatically the script folder path. Please insert the folder path here:", "Cannot find automatically the script folder path. Please insert the folder path here:"},
			{"Done!", "Done!"},
			{"Nothing to read!", "Nothing to read!"},
			{"Source code copied into the clipboard!", "Source code copied into the clipboard!"},
			{"No file found!", "No file found!"},
			{"not found!", "not found!"},
		},
		["de-de"] = {}, -- Deutsch
		["es-la"] = {}, -- Spanish
		["fr-fr"] = {},	-- French
		["ja-jp"] = {},	-- Japanese
		["ko-kr"] = {}, -- Korean
		["pt-br"] = {}, -- Portuguese
		["ru-ru"] = {}, -- Russian
		["vi-vn"] = {}, -- Vietnamese
		["zh-cn"] = {}, -- Chinese
		["zh-tw"] = {}, -- Chinese Taïwan
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 2,
		minEditorVersion = 65540
	}
end

-- Define a class "NotesObject"
NotesObject = {
	project = nil,
	scriptFile = "Utilities/RandomizeParameters.lua",
	isCommandActived = false,  -- if command prompt is activated (windows only)
	askForScriptFile = true,  -- if true a dialog box is displayed
	isMultipleScript = false, -- if true askForScriptFile is not more used
	isFilterSubfolder = false,
	filterSubfolder = "Utilities", -- filter for multiple subfolders scan
	winSepCharPath = "/",
	winScriptPathBegin = "OneDrive", -- C:\Users\YOUR_USER_NAME\OneDrive\Documents\Dreamtonics\Synthesizer V Studio\Script
	winScriptPathDocument = "Documents", -- "\\Documenti", etc.
	winScriptPathEnd = "/Dreamtonics/Synthesizer V Studio/scripts/",
	macosPath = "/Library/Application Support/Dreamtonics/Synthesizer V Studio/Script/",
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
	
    self.project = SV:getProject()
	self:getHostInformations()
	
    return self
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get host informations
function NotesObject:getHostInformations()
	self.hostinfo = SV:getHostInfo()
	self.osType = self.hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	self.osName = self.hostinfo.osName
	self.hostName = self.hostinfo.hostName
	self.languageCode = self.hostinfo.languageCode
	self.hostVersion = self.hostinfo.hostVersion
	self.hostVersionNumber = self.hostinfo.hostVersionNumber
end

-- Read file content
function NotesObject:readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
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

-- Split string by sep char
function NotesObject:split(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
	  table.insert(result, each)
   end
   return result
end

-- Get clean filename
function NotesObject:getCleanFilename(file)
	local filename = file
	if #filename > 0 then
		if string.find(filename, '"') ~= nil then
			filename = filename:gsub('"', '')
		end
	end
	return filename
end

-- Get wave file path
function NotesObject:getScriptFile()
	local filename = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Enter the full path audio filename"), "")
	return filename
end

-- Get file path
function NotesObject:getFilePath()	
	local scriptFilePath = ""
	local scriptFolder = ""
	local scriptErrorText = SV:T("Cannot find automatically the script path. Please insert the full path here:")
	local scriptErrorUserProfileText = SV:T("Cannot find user profile. Please insert the full path here:")
	
	if self.osType ~= "Windows" then	
		-- "macOS", "Linux", "Unknown"
		scriptFilePath = self.macosPath .. self.scriptFile
		if not self:isFileExists(scriptFilePath) then
			scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorText, scriptFilePath)
		end
	else
		-- Windows
		local userProfile = self:getWindowsUserProfile()
		if userProfile then
			-- if direct
			scriptFolder = userProfile .. self.winSepCharPath .. self.winScriptPathDocument 
							.. self.winScriptPathEnd
			scriptFilePath = scriptFolder .. self.scriptFile				
			if not self:isFileExists(scriptFilePath) then
				-- trying with adding OneDrive
				scriptFolder = userProfile 
								.. self.winSepCharPath 
								.. self.winScriptPathBegin 
								.. self.winSepCharPath 
								.. self.winScriptPathDocument
								.. self.winScriptPathEnd
				scriptFilePath = scriptFolder .. self.scriptFile			
				if not self:isFileExists(scriptFilePath) then
					scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorText, scriptFilePath)
				end
			end
		else
			scriptFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), scriptErrorUserProfileText, "")
		end
	end
	return scriptFilePath
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

-- Get source code
function NotesObject:getSourceCode(languageCode, textArray)
	local fTranslations = ""
	local fLanguage = ""
	local jfaComment = '-- Generated by JFA TranslateScripts.lua'
	
	fTranslations = fTranslations .. jfaComment .. '\r'
	fTranslations = fTranslations .. 'function getTranslations(langCode)' .. '\r'
	fTranslations = fTranslations .. '\treturn getArrayLanguageStrings()[langCode]' .. '\r'
	fTranslations = fTranslations .. 'end' .. '\r'
	
	fLanguage = fLanguage .. jfaComment .. '\r'
	fLanguage = fLanguage .. 'function getArrayLanguageStrings()' .. '\r'
	fLanguage = fLanguage .. '\treturn {' .. '\r'
	fLanguage = fLanguage .. '\t\t["' .. languageCode .. '"] = {' .. '\r'
	for iItem = 1, #textArray do
		fLanguage = fLanguage .. '\t\t\t{"' .. textArray[iItem] .. '", "' .. textArray[iItem] .. '"},' .. '\r'
	end
	fLanguage = fLanguage .. '\t\t},' .. '\r'
	fLanguage = fLanguage .. '\t}' .. '\r'
	fLanguage = fLanguage .. 'end' .. '\r'
	
	return fTranslations .. "\r" .. fLanguage
end

-- Is text already exists in array
function NotesObject:isTextExists(text, textArray)
	local exists = false
	for iPos = 1, #textArray do
		if textArray[iPos] == text then
			exists = true
			break
		end
	end
	return exists
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
					if string.find(testname, ".lua", 1, true) ~= nil then
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
				if string.find(testname, ".lua", 1, true) ~= nil then
					i = i + 1
					dir[i] = filename
					full_dir[i] = directory .. filename		
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

-- file processing
function NotesObject:fileProcess(file, languageCode)
	-- Process one file
	local textFound = {}
	local scriptLines = {}
	local scriptContent = self:readAll(file)
	local languageSourceCode = ""
	
	if scriptContent ~= nil then
		if #scriptContent > 0 then
			scriptLines = self:split(scriptContent, "\r\n")
			for iPos = 1, #scriptLines do
				local line = scriptLines[iPos]
				for capture in string.gmatch(line, 'SV%:T%("(.-)"%)') do
					if capture ~= "SCRIPT_TITLE" then
						if not self:isTextExists(capture, textFound) then
							table.insert(textFound, capture)
						end
					end
				end						
			end
		end
		-- self:show(SV:T("Done!") 
		-- .. " Found: " .. #textFound .. "\r"
		-- .. " scriptLines: " .. #scriptLines .. "\r" 
		-- .. table.concat(textFound, "\r"))
		languageSourceCode = self:getSourceCode(languageCode, textFound)
	end
	return languageSourceCode
end

-- Select file
function NotesObject:selectFile()
	local result = ""
	local osType = SV:getHostInfo().osType
	local tempClipBoard = SV:getHostClipboard()
	if osType == 'macOS' then
		-- TODO
		local command = [[osascript -e 'tell application "System Events" to activate' \
			-e 'do shell script "echo " & todo & " | pbcopy"' ]]
		os.execute(command)
	elseif osType == 'Windows' then
		-- local psCommand = [[Add-Type -AssemblyName PresentationFramework;$u8 = [System.Text.Encoding]::UTF8;$out = [Console]::OpenStandardOutput();$ofd = New-Object -TypeName Microsoft.Win32.OpenFileDialog;$ofd.Multiselect = $false;If ($ofd.ShowDialog() -eq $true) {ForEach ($filename in $ofd.FileNames) {$u8filename = $u8.GetBytes("$filename`n");$out.Write($u8filename, 0, $u8filename.Length)}}]]
		-- local psCommand = [[Add-Type -AssemblyName PresentationFramework;$u8 = [System.Text.Encoding]::UTF8;$ofd = New-Object -TypeName Microsoft.Win32.OpenFileDialog;$ofd.Multiselect = $false;If ($ofd.ShowDialog() -eq $true) {ForEach ($filename in $ofd.FileNames) {$u8filename = $u8filename + $filename}; Set-Clipboard -Value $u8filename}]]
		-- local psCommand = [[Add-Type -AssemblyName PresentationFramework;$u8 = [System.Text.Encoding]::UTF8;$out = [Console]::OpenStandardOutput();$ofd2 = "ERROR`n".ToCharArray() -as [byte[]];$ofd1 = $false;If ($ofd1 -eq $true) {$out.Write($ofd1, 0, $ofd1.Length)}else{$out.Write($ofd2, 0, $ofd2.Length)}]]
		local psCommand = [[Add-Type -AssemblyName PresentationFramework;$u8 = [System.Text.Encoding]::UTF8;$ofd2 = 'ERROR';$ofd = New-Object -TypeName Microsoft.Win32.OpenFileDialog;$ofd.Multiselect = $false;If ($ofd.ShowDialog() -eq $true) {Set-Clipboard -Value $ofd.FileNames}else{Set-Clipboard -Value $ofd2}]]
		local command = 'powershell -WindowStyle Hidden -Command "' .. psCommand .. '"'
		os.execute(command)
	else
		SV:showMessageBox("Error", "Unsupported OS. Please use macOS or Windows.")
	end
	result = SV:getHostClipboard()
	SV:setHostClipboard(tempClipBoard)	
	return result
end

-- Start project notes processing
function NotesObject:start()
	local result = false
	-- self:show(" osType: " .. self.osType .. "\r"
	-- .. " osName: " .. self.osName .. "\r"
	-- .. " hostName: " .. self.hostName .. "\r"
	-- .. " languageCode: " .. self.languageCode .. "\r"
	-- .. " hostVersion: " .. self.hostVersion .. "\r" )
	
	if self.isMultipleScript then
		local folderPath = self:getScriptsPath()
		
		if folderPath ~= nil and #folderPath > 0 then
			local luaExtension = ".lua" -- limit to lua scripting files
			local filter = ""
			if self.isFilterSubfolder then
				filter = self.filterSubfolder .. self:getSepPathChar()
			end
			local pathFolder = folderPath .. filter
			
			folderlist, full_folderlist = self:listFiles(pathFolder)
			local filesPathList = {}
			local filesList = {}
			local languageSourceCode = ""
			
			for k, filePath in pairs(full_folderlist) do
				-- Only lua scripting files
				if string.find(full_folderlist[k], luaExtension, 1, true) ~= nil then
					table.insert(filesPathList, filePath)
					table.insert(filesList, folderlist[k])
					
					local newFileSourceCode = self:fileProcess(filePath, self.languageCode)
					if newFileSourceCode ~= nil and #newFileSourceCode > 0 then
						languageSourceCode = languageSourceCode
							.. filePath .. "\r"
							.. newFileSourceCode
							.. "\r"
					else
						languageSourceCode = languageSourceCode
							.. filePath .. "\r"
							.. SV:T("Nothing to read!")
							.. "\r"
					end					
				end
			end
			SV:setHostClipboard(languageSourceCode)
			self:show(SV:T("Done!") 
				.. "\r" .. SV:T("Source code copied into the clipboard!"))
			
			-- self:show("filesPathList:\r" .. table.concat(filesPathList, "\r"))
			-- self:show("filesList:\r" .. table.concat(filesList, "\r"))
		
		else
			self:show(SV:T("No file found!"))
		end
	else
		if self.isCommandActived then
			local filename = self:selectFile()
			if string.find(filename, "ERROR") ~= nil then
				self:show(SV:T("No file found!"))
				return result
			else
				self.scriptFile = filename
			end
		else
			if self.askForScriptFile then
				local filename = self:getScriptFile()
				if #filename == 0 then
					return result
				end
				
				filename = self:getCleanFilename(filename)
				self.scriptFile = filename
			else
				local filename = self:getFilePath()
				if #filename == 0 then
					return result
				end
				
				filename = self:getCleanFilename(filename)
				self.scriptFile = filename
			end
		end
		
		-- if process not ok
		if not self:isFileExists(self.scriptFile) then
			self:show(self.scriptFile .. " " .. SV:T("not found!"))
		else
			local languageSourceCode = self:fileProcess(self.scriptFile, self.languageCode)
			
			if languageSourceCode ~= nil and #languageSourceCode > 0 then
				SV:setHostClipboard(languageSourceCode)
				self:show(SV:T("Done!") 
					.. "\r" .. SV:T("Source code copied into the clipboard!"))
			else
				self:show(SV:T("Nothing to read!"))
			end
		end
	end
	return result
end

-- Main process
function main(notEndProcess)
	local notesObject = NotesObject:new()
	
	notesObject:start()
	
	if notEndProcess == nil then
		-- End of script
		SV:finish()
	end
end
