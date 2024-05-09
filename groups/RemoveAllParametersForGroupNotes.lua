local SCRIPT_TITLE = 'Remove all parameters for group notes V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: RemoveAllParametersForGroupNotes.lua

Remove all parameters from selected notes to target notes

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

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	editor = nil,
	track = nil,
	groupsCount = nil,
	secondDecay = 0,
	selection = nil,
	selectedNotes = nil,
	groupFromNote = nil,
	timeBegin = nil,
	timeEnd = nil,
	lyrics = "",
	currentGroupRef = nil,
	groupNotesMain = nil,
	parametersFoundCount = 0,
	parametersRemovedCount = 0,
	pasteAsyncAction = true,
	currentCopyPasteAction = 1,
	parametersFound = nil,
	paramsSynthV = {
		pitchDelta = 0, 
		vibratoEnv = 1, 
		loudness = 0, 
		tension = 0, 
		breathiness = 0, 
		voicing = 1, 
		gender = 0
	}

}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = notesObject.project:getTimeAxis()
    notesObject.editor =  SV:getMainEditor()
    notesObject.track = notesObject.editor:getCurrentTrack()
    notesObject.selection = notesObject.editor:getSelection()
    notesObject.selectedNotes = notesObject.selection:getSelectedNotes()
	notesObject.currentGroupRef = notesObject.editor:getCurrentGroup()
	notesObject.groupNotesMain = notesObject.currentGroupRef:getTarget()
	
	notesObject.parametersFoundCount = 0
	notesObject.parametersRemovedCount = 0
	
	-- Get range time
	if #notesObject.selectedNotes > 0 then
		-- get current group from first note
		local sourceNote = notesObject.selectedNotes[1]
		notesObject.groupFromNote = sourceNote:getParent()
		
		notesObject.timeBegin = notesObject.selectedNotes[1]:getOnset()
		if #notesObject.selectedNotes > 1 then
			local lastSourceNote = notesObject.selectedNotes[#notesObject.selectedNotes]
			notesObject.timeEnd = lastSourceNote:getOnset() + lastSourceNote:getDuration()
		else
			notesObject.timeEnd = notesObject.timeBegin + notesObject.selectedNotes[1]:getDuration()
		end
		for iNote = 1, #notesObject.selectedNotes do
			notesObject.lyrics = notesObject.lyrics .. jfaTools.getSepCharLoop(iNote, " ") .. notesObject.selectedNotes[iNote]:getLyrics()
		end
	end

    return notesObject
end

-- Method to get Selected Notes Count of a NotesObject
function NotesObject:getSelectedNotesCount()
    return self.selectedNotesCount
end

-- is source note selected
function NotesObject:isOneNoteSelected()
	return #self.selectedNotes > 0
end

-- Is tag is referenced
function NotesObject:isTagIsReferenced(tag)
	local result = false
	for label, data in pairs(self.paramsSynthV) do
		if tag == label then result = true end
	end
	return result
end

-- Get blick to second
function NotesObject:getBlickToSecond(time)
	return self.timeAxis:getSecondsFromBlick(time)
end

-- Get parameters Label Found in selected group notes
function NotesObject:getParametersLabelFoundInGroupNotes()
	local result = ""
	
	if self.parametersFound ~= nil then
		local iLoop = 0
		local strFound = ""
		for label, def in pairs(self.parametersFound) do
			if self:isTagIsReferenced(label) then
				iLoop = iLoop + 1
				strFound = strFound .. jfaTools.getStringDataForLoop(label, iLoop, self.parametersFoundCount)
			end
		end
		if string.len(strFound) > 0 then
			result = "Parameters found: " .. strFound .. "\r" .. "count: " .. tostring(iLoop)
		end
	end
	return result
end

-- get default parameter definition
function NotesObject:getDefaultParamDefinition(parameterName, parametersGroup)
	local result = ""

	if parametersGroup ~= nil then
		local paramsDef = parametersGroup:getDefinition()
	
		for iRange = 1, #paramsDef.range do
			range = range .. getStringDataForLoop(range, iRange, #paramsDef.range)
		end
		
		result = result ..  SV:T("Def params - DisplayName: ") .. paramsDef.displayName ..  SV:T(", Type: ")
			.. paramsDef.typeName ..  SV:T(", Range: ") .. range 
			..  SV:T(", default: ") .. tostring(paramsDef.defaultValue) .. "\r"
	else
		result = result .. tostring(parameterName) .. " => " ..  SV:T("parametersGroup is nil!") .. "\r"
	end
	return result
end

-- Method to get Parameters corresponding of selected notes timing range
function NotesObject:getParameters()
	local result = {}
	
	self.parametersFoundCount = 0
	
	if self.groupFromNote ~= nil then
		local paramPointsFound = {}
		
		-- Loop parameters
		for iParam, def in pairs(self.paramsSynthV) do
			local pointCount = 0
			local paramsGroup = self.groupFromNote:getParameter(iParam)
			
			if paramsGroup ~= nil then
				local allPoint = paramsGroup:getAllPoints()
				-- Loop all parameters points
				for iPoint = 1, #allPoint do
					local pts = allPoint[iPoint]
					local array = {}
					local dataStr = ""
					
					-- Loop each pair point
					for iPosPoint = 1, #pts do
						local currentPoint = allPoint[iPoint][1]
						
						-- Only time inside selected notes
						if currentPoint >= self.timeBegin  and currentPoint <= self.timeEnd  then
							dataStr = tostring(allPoint[iPoint][iPosPoint])
							array[iPosPoint] = allPoint[iPoint][iPosPoint]
							if iPosPoint == 1 then pointCount = pointCount + 1 end
						end
					end
					-- store only points found in timing range from selected notes
					if string.len(dataStr) > 0 then
						paramPointsFound[pointCount] = array
					end
				end
				
				if #paramPointsFound > 0 then
					result[iParam] = paramPointsFound
					self.parametersFoundCount = self.parametersFoundCount + 1
					paramPointsFound = {}
					pointCount = 0
				end
			end
		end
		
		-- Add note time & lyrics
		if self.parametersFoundCount > 1 then
			result["timeBegin"] = self.timeBegin
			result["timeEnd"] = self.timeEnd
			result["lyrics"] = self.lyrics
		end
	end
	
	-- save parameters to inner object
	self.parametersFound = result
    return result
end

-- Remove all parameters
function NotesObject:removeParameters()
	local result = ""	
	
	if self.parametersFound ~= nil then
		local iParametersLabelFoundCount = 0
		
		for label, def in pairs(self.parametersFound) do
			if self:isTagIsReferenced(label) then
				local paramsGroup = self.groupFromNote:getParameter(label)
				if (paramsGroup ~= nil) then
					paramsGroup:remove(self.timeBegin, self.timeEnd)
					iParametersLabelFoundCount = iParametersLabelFoundCount + 1
				end
			end
		end
		
		self.parametersRemovedCount = iParametersLabelFoundCount
		
		if self.parametersRemovedCount > 0 then
			result = "Found: " .. tostring(self.parametersRemovedCount) .. " " .. SV:T("parameters removed!")
		else
			result = "No parameters found!"
		end
	end
	
	return result 
end

-- Dialog box for copy
function NotesObject:promptForRemove()
	local resultAction = false
	local info = self:getParametersLabelFoundInGroupNotes()
	local remark = ""
	
	if string.len(info) > 0 then
		remark = SV:T("Note:") .. "\r" .. info
	end
	
	local waitForm = {
		title = SV:T("Remove parameters"),
		message = SV:T("Script will erase existing parameters") .. "\r"
				  .. SV:T("under a range of selected notes.") .. "\r"
				  .. SV:T("(Without any impact on notes properties)") .. "\r\r"
				  .. SV:T("Click Cancel to abort.")  .. "\r"
				  .. "\r"
				  .. remark,
		buttons = "OkCancel",
		widgets = {}
	}
	
	local result = SV:showCustomDialog(waitForm)	
	if result.status == true then
		resultAction = true
	else
		resultAction = false
	end
	return resultAction	
end

-- Main processing task	
function main()
	
	local notesObject = NotesObject:new()

	-- At least one note must be selected
	if not notesObject:isOneNoteSelected() then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
	else
		-- Check if copy or paste action
		notesObject:getParameters()
		
		-- Copy action
		local resultAction = notesObject:promptForRemove()
		
		if resultAction then
			-- remove parameters
			local resultRemovingParams  = notesObject:removeParameters()
			if notesObject.parametersRemovedCount > 0 then
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters removing DONE!") .. "\r\r"
				.. SV:T("Next step :") .. "\r"
				.. SV:T("See result inside the parameter view."))
			else
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No parameters found for selected notes!") )
			end
		end
	end
	SV:finish()
end

-- Tools for specificc strings implementations
jfaTools = {

	-- trim string
	trim = function(s)
	  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
	end,

	-- Split string into array separated by space
	splitSpace = function(argstr)
	  local args = {}
	  for v in string.gmatch(argstr, "%S+") do
		table.insert(args, v)
	  end
	  return args
	end,

	-- Check nil for number values
	isNumberNotNil = function(a) if a == nil then return 0 else return a end end,

	-- Get sep char in loop for string with count indice
	getSepCharLoop = function(iLoop, newSep)
		local defaultSep = ", "
		local result = ""
		
		if newSep == nil or string.len(newSep) == 0 then newSep = defaultSep end
		
		if iLoop == 1 then
			result = ""
		else 
			result = newSep
		end
		return result
	end,

	-- Get sep char in loop for string with count indice not on last loop
	getSepCharLoopNotForLast = function(iLoop, iCount, newSep)
		local defaultSep = ", "
		local result = ""
		
		if newSep == nil or string.len(newSep) == 0 then newSep = defaultSep end
		
		if iLoop == iCount then
			result = ""
		else 
			result = newSep
		end
		return result
	end,

	-- get start bracket char in loop for string with count indice
	getBracketStartInLoop = function(iLoop, newSep)
		local defaultSep = "["
		local result = ""
		
		if newSep == nil or string.len(newSep) == 0 then newSep = defaultSep end
		
		if iLoop == 1 then
			result = newSep
		else 
			result = ""
		end
		return result
	end,

	-- get end bracket char in loop for string with count indice
	getBracketEndInLoop = function(iLoop, iCount, newSep)
		local defaultSep = "]"
		local result = ""
		
		if newSep == nil or string.len(newSep) == 0 then newSep = defaultSep end
		
		if iLoop < iCount then
			result = ""
		else 
			result = newSep
		end
		return result
	end,

	-- get string format for loop
	getStringDataForLoop = function(dataString, iLoop, count, newSep, newSepStart, newSepEnd)
		local result = ""
		result = jfaTools.getBracketStartInLoop(iLoop, newSepStart) .. jfaTools.getSepCharLoop(iLoop, newSep)
			.. dataString 
			.. jfaTools.getBracketEndInLoop(iLoop, count, newSepEnd)
		return result
	end,

	-- Quote string
	quote = function(str)
		return "\""..str.."\""
	end,

	-- Split string by sep char
	split = function(str, sep)
	   local result = {}
	   local regex = ("([^%s]+)"):format(sep)
	   for each in str:gmatch(regex) do
		  table.insert(result, each)
	   end
	   return result
	end,

	-- Convert table to string
	tableToString = function(tableInput, level)
		local result = ""
		if level == nil then level = 0	end
		
		if type(tableInput) == "table" then
			local iCount = 0
			
			for label, data in pairs(tableInput) do
				iCount = iCount + 1
			end
			
			local iLoop = 0
			for label, data in pairs(tableInput) do
				iLoop = iLoop + 1
				if type(data) == "table" then
					dataStr = jfaTools.tableToString(data, level + 1)
					local sep = "|"
					local strAssign = ":"
					if level == 0 then 
						sep = "\r" 
						strAssign = "="
					end
					if iLoop == iCount then sep = "" end
					result = result .. label .. strAssign .. dataStr .. sep
				elseif type(data) == "number" and type(label) == "number" then
					dataStr = jfaTools.getStringDataForLoop(tostring(data), label, iCount)
					result = result .. dataStr
				else
					dataStr = tostring(data)
					result = result .. label .. "=" .. dataStr .. "\r"
				end
			end
		elseif type(tableInput) == "string" then
			result = tableInput
		else
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("type(data) is NOT table or string! type: ") .. type(tableInput) 
			.. SV:T(", level: ") .. tostring(level) .. SV:T(", tableInput: ").. tostring(tableInput))
			result = tostring(tableInput)
		end
		return result
	end,
	
	-- Convert string to table
	stringToTable = function(paramsString, newSep, newAssign)
		local result = nil
		if newSep == nil then newSep = "\r" end
		if newAssign == nil then newAssign = "=" end
		
		if paramsString ~= nil and string.len(paramsString) > 0 then
			result = {}
			local paramSlitted = jfaTools.split(paramsString, newSep)
			for iLine = 1, #paramSlitted do
				local labelToFind = jfaTools.split(paramSlitted[iLine], "=")
				-- timeEnd=1852200000
				-- pitchDelta=1:[1426381361, 6.7873301506042]|2:[1605705119, 161.53845214844]|3:[1624581303, 0.0]
				result[labelToFind[1]] = labelToFind[2]
			end
		end
		return result
	end

}
