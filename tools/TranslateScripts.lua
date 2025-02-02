local SCRIPT_TITLE = 'Translate scripts V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: TranslateScripts.lua

Retrieving all SV:T(text) found inside a script
and generate a getTranslations function 
with all text found into the clipboard

2025 - JF AVILES
--]]

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

-- Translate SV:T text to display
function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

-- Text to display into the corresponding language
function getArrayLanguageStrings()
	return {
		["en-us"] = { -- English
			{"Enter the full script path filename", "Enter the full script path filename"},
			{"not found!", "not found!"},
			{"Done!", "Done!"},
			{"Nothing to read!", "Nothing to read!"},
		},
		["de-de"] = {}, -- Deutsch
		["es-la"] = {}, -- Spanish
		["fr-fr"] = {	-- French
			{"Enter the full script path filename", "Entrez le chemin complet du nom du fichier script"},
			{"not found!", "non trouvé !"},
			{"Done!", "Fait !"},
			{"Nothing to read!", "Pas de contenu !"},
		},
		["ja-jp"] = {},	-- Japanese
		["ko-kr"] = {}, -- Korean
		["pt-br"] = {}, -- Portuguese
		["ru-ru"] = {}, -- Russian
		["vi-vn"] = {}, -- Vietnamese
		["zh-cn"] = {}, -- Chinese
		["zh-tw"] = {}, -- Chinese Taïwan
	}
end


-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	scriptFile = "C:/Users/jfavi/OneDrive/Documents/Dreamtonics/Synthesizer V Studio/scripts/jfaviles/tools/TranslateScripts.lua",
	askForScriptFile = true,
	isExecutableChained = true
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = SV:getProject():getTimeAxis()
	
    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
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

-- Get host infos
function NotesObject:getHostInfos()
	local hostinfo = SV:getHostInfo()
	local osType = hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	local osName = hostinfo.osName
	local hostName = hostinfo.hostName
	local languageCode = hostinfo.languageCode
	local hostVersion = hostinfo.hostVersion
	return osType, osName, hostName, languageCode, hostVersion
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
	local filename = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Enter the full script path filename"), "")
	return filename
end

-- Get source code
function NotesObject:getSourceCode(languageCode, textArray)
	local fTranslations = ""
	local fLanguage = ""
	
	fTranslations = fTranslations .. 'function getTranslations(langCode)' .. '\r'
	fTranslations = fTranslations .. '\treturn getArrayLanguageStrings()[langCode]' .. '\r'
	fTranslations = fTranslations .. 'end' .. '\r'
	
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

-- Start project notes processing
function NotesObject:start()
	local result = false
	local osType, osName, hostName, languageCode, hostVersion = self:getHostInfos()
	
	if self.askForScriptFile then
		local filename = ""
		
		filename = self:getScriptFile()
		if #filename == 0 then
			return result
		end
		
		filename = self:getCleanFilename(filename)
		self.scriptFile = filename
	end

	-- if process not ok
	if not self:isFileExists(self.scriptFile) then
		self:show(self.scriptFile .. " " .. SV:T("not found!"))
	else
		-- Process
		local textFound = {}
		local scriptLines = {}
		local scriptContent = self:readAll(self.scriptFile)
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
				-- .. " osType: " .. osType .. "\r"
				-- .. " osName: " .. osName .. "\r"
				-- .. " hostName: " .. hostName .. "\r"
				-- .. " languageCode: " .. languageCode .. "\r"
				-- .. " hostVersion: " .. hostVersion .. "\r"
				-- .. " Found: " .. #textFound .. "\r"
				-- .. " scriptLines: " .. #scriptLines .. "\r" 
				-- .. table.concat(textFound, "\r"))
				
				local languageSourceCode = self:getSourceCode(languageCode, textFound)
				SV:setHostClipboard(languageSourceCode)
				-- self:show(languageSourceCode)
				self:show(SV:T("Done!") .. "\r" .. SV:T("Source code copied into the clipboard!"))
		else
			self:show(SV:T("Nothing to read!"))
		end
	end
	return result
end

-- Main process
function main()
	local notesObject = NotesObject:new()
	notesObject:start()
	
	-- End of script
	SV:finish()
end
