local SCRIPT_TITLE = 'ShortcutsList V1.2'

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

2024 - JF AVILES
--]]


function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 2,
		minEditorVersion = 65540
	}
end

-- Define a class
InternalData = {
	SEP_KEYS = "/",
	winSepCharPath = "\\",
	winSettingsPathBegin = "OneDrive", -- C:\Users\YOUR_USER_NAME\OneDrive\Documents\Dreamtonics\Synthesizer V Studio\settings
	winSettingsPathDocument = "Documents", -- "\\Documenti", etc.
	winSettingsPathEnd = "\\Dreamtonics\\Synthesizer V Studio\\settings\\",
	macosPath = "/Library/Application Support/Dreamtonics/Synthesizer V Studio/settings/",
	settingsFile = "settings.xml",
	limitStringDisplay = 1500,
	htmlChars = {{"&lt;", "<"}, {"&quot;", "\""}, {"&gt;", ">"}, {"&#13;", "\r"}, {"&#10;", "\n"}},
	duplicatesShortcuts = {},
	DEBUG = false,
	logs = {
		logs = "",
		add = function(self, new) 
				if InternalData.DEBUG then self.logs = self.logs .. new end
			end,
		clear = function(self) 
					if InternalData.DEBUG then self.logs = "" end
				end,
		showLogs = function(self) 
					if InternalData.DEBUG then 
						SV:showMessageBox(SV:T(SCRIPT_TITLE), self.logs)
					end
				end
	}
}

-- Common tools
commonTools = {
	
	getFilePathSettings = function(documents)
		local hostinfo = SV:getHostInfo()
		local osType = hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
		local settingsFilePath = ""
		local settingsFolder = ""
		local settingsPathTitle = SV:T("Settings full path for file settings.xml")
		local settingsErrorText = SV:T("Cannot find automatically the settings path. Please insert the full path here:")
		local settingsErrorUserProfileText = SV:T("Cannot find user profile. Please insert the full path here:")
		
		if osType ~= "Windows" then	
			-- "macOS", "Linux", "Unknown"
			settingsFilePath = InternalData.macosPath .. InternalData.settingsFile
			if not commonTools.isFileExists(settingsFilePath) then
				settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorText, settingsPathTitle)
			end
		else
			-- Windows
			local userProfile = os.getenv("USERPROFILE")
			if userProfile then
				-- if direct
				settingsFolder = userProfile .. InternalData.winSepCharPath .. documents 
								.. InternalData.winSettingsPathEnd
				settingsFilePath = settingsFolder .. InternalData.settingsFile				
				if not commonTools.isFileExists(settingsFilePath) then
					-- trying with adding OneDrive
					settingsFolder = userProfile 
									.. InternalData.winSepCharPath 
									.. InternalData.winSettingsPathBegin 
									.. InternalData.winSepCharPath 
									.. documents
									.. InternalData.winSettingsPathEnd
					settingsFilePath = settingsFolder .. InternalData.settingsFile
					if not commonTools.isFileExists(settingsFilePath) then
						settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorText, settingsPathTitle)
					end
				end
			else
				settingsFilePath = SV:showInputBox(SV:T(SCRIPT_TITLE), settingsErrorUserProfileText, settingsPathTitle)
			end
		end
		return settingsFilePath
	end,
	
	-- Check if file exists
	isFileExists = function(fileName)
		local result = false
		local file = io.open(fileName, "r")
		if file ~= nil then
			io.close(file)
			result = true
		end
		return result
	end,
	
	-- Start process
	start = function()		
		-- settings file path:
		-- C:\Users\YOUR_USER_NAME\OneDrive\Documents\Dreamtonics\Synthesizer V Studio\settings\settings.xml
		-- "/Library/Application Support/Dreamtonics/Synthesizer V Studio/settings/settings/settings.xml
		local settingsPath = commonTools.getFilePathSettings(InternalData.winSettingsPathDocument)
		local fileNotFoundTitle = SV:T("File not found!")
		local definedTitle = SV:T("Defined:")
		local keyboardDefinedTitle = SV:T("Keyboard:")
		local notDefinedTitle = SV:T("Not defined:")
		local keyMapping = "@keyMapping"
		local keyName = "@name"
		local sepCharDisplay = ", "
		local keymaps = {}
		local keyboardMapping = ""
		local xml = newParser()	
		
		InternalData.logs:clear()
		local fhandle = io.open(settingsPath, 'r')
		
		if fhandle == nil then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), fileNotFoundTitle .. " : " .. settingsPath)
		else
			-- read file
			local data = fhandle:read("*a")
			io.close(fhandle)
			local parsedXml = xml:ParseXmlText(data)
			local error = true
			local sepline = "\r" .. "-------------------------" .. "\r"
			local seplineTitle = "-------------------------" .. "\r"
			
			if parsedXml.ApplicationSettings ~= nil then 				
				if parsedXml.ApplicationSettings.Keyboard ~= nil then 
					if parsedXml.ApplicationSettings.Keyboard[keyMapping] ~= nil then 
						local KeyboardKeyMapping = parsedXml.ApplicationSettings.Keyboard[keyMapping]
						if string.len(KeyboardKeyMapping) > 0 then
							keyboardMapping = commonTools.getHTMLToText(KeyboardKeyMapping)
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
						local displayLimitDefined =  commonTools.getMaxLengthScriptName(scriptItem)
						
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
								result = result .. commonTools.getFormatScriptItem(scriptName, keyMap)
								local tabCount = commonTools.getScriptNameTabs(tabCharCount, displayLimitDefined, scriptName)
								local tabs = string.rep("\t", tabCount)
								
								keyMap = commonTools.getSpecialKeymap(keyMap) -- if #b2 => adding (²) for info only
								resultForDisplayOnly = resultForDisplayOnly .. scriptName .. tabs .. " => ".. keyMap .. "\r"
								table.insert(keymaps, {scriptName, keyMap, iItem})
							end
						end
						
						-- Check if duplicate shortcuts exists
						InternalData.duplicatesShortcuts = commonTools.getDuplicateShortcuts(keymaps)
						
						if #InternalData.duplicatesShortcuts > 0 then
							local resultSC = commonTools.getDisplayDuplicateShortcuts(InternalData.duplicatesShortcuts)
							
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
								result = result .. commonTools.getFormatScriptItem(scriptName, "")
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
						
						error = false
						SV:setHostClipboard(result .. sepline .. resultForDisplayOnly)
						SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Shortcuts:") .. "\r" 
							.. string.sub(resultForDisplayOnly,1, InternalData.limitStringDisplay) 
							.. "\r"
							.. "..."
							.. "\r" 
							.. SV:T("All data copied to clipboard!"))
					end
				end
			end
			if error then 
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("settingsPath: ") 
									.. settingsPath .. "\r" 
									.. SV:T("Error in parsing XML file!"))
			end
		end
	end,
	
	-- get HTML to text
	getHTMLToText = function(KeyboardKeyMapping)
		local text = KeyboardKeyMapping
		
		for iHTMLKeys = 1, #InternalData.htmlChars do
			text = text:gsub(InternalData.htmlChars[iHTMLKeys][1], 
				InternalData.htmlChars[iHTMLKeys][2])
		end
		
		return text
	end,
	
	-- Check doublon
	getDuplicateShortcuts = function(keymaps)
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
	end,
	
	-- Get duplicate shortcuts to display
	getDisplayDuplicateShortcuts = function(duplicatesSC)
		local resultSC = ""
		
		for iSC = 1, #duplicatesSC do
			resultSC = resultSC .. table.concat(duplicatesSC[iSC], " = ") .. "\r"
		end
		return resultSC
	end,
	
	-- Get xml format for script item
	getFormatScriptItem = function(item, keymap)
		local scriptItemBegin = "<ScriptItem name="
		local scriptItemKeyMapping = "keyMapping="
		local scriptItemEnd = "/>"
		local sepQuote = "\""
		
		local result = scriptItemBegin .. sepQuote .. item .. sepQuote 
			.. " " 
			.. scriptItemKeyMapping .. sepQuote .. keymap .. sepQuote 
			.. scriptItemEnd .. "\r"
			
		return result
	end,
	
	-- Get tabs for script name
	getScriptNameTabs = function(tabCharCount, maxLine, scriptName)
		local scriptLen = string.len(scriptName)
		local maxTabCount = math.floor((maxLine + tabCharCount) / tabCharCount)
		local scriptTabCount = math.floor(scriptLen / tabCharCount)		
		return maxTabCount - scriptTabCount
	end,
	
	-- Get max string name with shortcuts dedined
	getMaxLengthScriptName = function(scriptItem)
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
	end,
	
	-- Get special keymap
	getSpecialKeymap = function(keyMap)
		if string.find(keyMap, "#b2") ~= nil then 
			keyMap = keyMap .. " (²)" 
		end
		return keyMap
	end

}

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

function main()
	commonTools.start()
	SV:finish()
end