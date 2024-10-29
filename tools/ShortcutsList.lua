local SCRIPT_TITLE = 'ShortcutsList V1.0'

--[[

lua file name: ShortcutsList.lua

List all defined shortcuts from settings.xml
And copy result into the Clipboard.

!! Update settingsPath for your own system !!

Example:
Defined:
<ScriptItem name="Lyrics tracks to Clipboard V1.0" keyMapping=="ctrl + shift + L"/>
<ScriptItem name="Group name udate V1.0" keyMapping=="ctrl + shift + R"/>
<ScriptItem name="Group name update V1.0" keyMapping=="ctrl + shift + R"/>
<ScriptItem name="Groups name update All V1.0" keyMapping=="ctrl + shift + U"/>
<ScriptItem name="Lyrics tracks in .SRT format to Clipboard V1.0" keyMapping=="ctrl + shift + L"/>

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

2024 - JF AVILES
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

-- Define a class
InternalData = {
	SEP_KEYS = "/",
	settingsPathBegin = "\\OneDrive",
	settingsPathDocument = "\\Documents", -- "\\Documenti",
	settingsPathEnd = "\\Dreamtonics\\Synthesizer V Studio\\settings\\",
	settingsFile = "settings.xml",
	limitStringDisplay = 1500,
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

	-- Start process
	start = function()
		local userFolder = os.getenv("USERPROFILE")
		local settingsPath = userFolder 
			.. InternalData.settingsPathBegin 
			.. InternalData.settingsPathDocument 
			.. InternalData.settingsPathEnd 
			.. InternalData.settingsFile

		InternalData.logs:clear()
		local xml = newParser()	
		local fhandle = io.open(settingsPath, 'r')
		if fhandle == nil then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("File not found!: ") .. settingsPath)
		else
			-- read file
			local data = fhandle:read("*a")
			io.close(fhandle)
			local parsedXml = xml:ParseXmlText(data)
			local error = true
			
			if parsedXml.ApplicationSettings ~= nil then 				
				if parsedXml.ApplicationSettings.Scripts ~= nil then 
					if parsedXml.ApplicationSettings.Scripts.ScriptItem ~= nil then 
						local result = SV:T("Defined:") .. "\r"
						-- Defined
						for i=1, #parsedXml.ApplicationSettings.Scripts.ScriptItem do
							local keyMap = parsedXml.ApplicationSettings.Scripts.ScriptItem[i]["@keyMapping"]
							if string.len(keyMap)> 0 then
								local scriptName = parsedXml.ApplicationSettings.Scripts.ScriptItem[i]["@name"]
								result = result .. commonTools.getFormatScriptItem(scriptName, keyMap)
							end
						end
						
						result = result .."\r"
						result = result .. "-------------------------" .. "\r"
						result = result .. SV:T("Not defined:") .. "\r"
						-- Not defined
						for i=1, #parsedXml.ApplicationSettings.Scripts.ScriptItem do
							local keyMap = parsedXml.ApplicationSettings.Scripts.ScriptItem[i]["@keyMapping"]
							if string.len(keyMap) == 0 then
								-- <ScriptItem name="Lyrics tracks to Clipboard V1.0" keyMapping="ctrl + shift + L"/>
								local scriptName = parsedXml.ApplicationSettings.Scripts.ScriptItem[i]["@name"]
								result = result .. commonTools.getFormatScriptItem(scriptName, "")
							end
						end
						error = false
						SV:setHostClipboard(result)
						SV:showMessageBox(SV:T(SCRIPT_TITLE), "Shortcuts:\r" 
							.. string.sub(result,1, InternalData.limitStringDisplay) 
							.. "\r"
							.. "..."
							.. "\r" 
							.. SV:T("All data copied to clipboard!"))
					end
				end
			end
			if error then 
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("settingsPath: ") .. settingsPath .. "\r" .. SV:T("Error in parsing XML file!"))
			end
		end
	end,
	
	getFormatScriptItem = function(item, keymap)
		local scriptItemBegin = "<ScriptItem name="
		local scriptItemKeyMapping = "keyMapping=="
		local scriptItemEnd = "/>"
		local sepQuote = "\""
		
		local result = scriptItemBegin .. sepQuote .. item .. sepQuote 
			.. " " 
			.. scriptItemKeyMapping .. sepQuote .. keymap .. sepQuote 
			.. scriptItemEnd .. "\r"
			
		return result
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