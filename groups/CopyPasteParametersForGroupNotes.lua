local SCRIPT_TITLE = 'Copy/Paste all parameters for group notes V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: CopyPasteParametersForGroupNotes.lua

Copy all notes parameters from selected notes to target notes

pitchDelta=1:[1426381361, 6.7873301506042]|2:[1605705119, 161.53845214844]|3:[1624581303, 0.0]
vibratoEnv=1:[1444939514, 1.0]|2:[1455964514, 1.0769231319427]|3:[1679868169, 1.6561086177826]|4:[1690893169, 1.0]
lyrics=+
-- Interal tags script required for timing reference corresponding to the selected notes
timeBegin=1411200000
timeEnd=1852200000

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
	timeBeginFromClipboard = nil,
	currentGroupRef = nil,
	groupNotesMain = nil,
	parametersFoundCount = 0,
	parametersFoundCountFromClipBoard = 0,
	pasteAsyncAction = true,
	currentCopyPasteAction = 1,
	parametersClipBoard = nil,
	parametersClipBoardTable = nil,
	isParametersClipBoardTable = false,
	parametersFound = nil,
	parametersFoundFromClipBoard = nil,
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
	notesObject.parametersClipBoard = SV:getHostClipboard()
	NotesObject.isParametersClipBoardTable = notesObject:isClipboardTable()
	
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

-- Is clipboard is a lua table
function NotesObject:isClipboardTable()
	local result = false
	if self.parametersClipBoard ~= nil and type(self.parametersClipBoard) == "string" then
		result = self:checkValidParamsFromClipboard()
	end
	return result
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

-- Get string format from seconds
function NotesObject:secondsToClock(timestamp)
	return string.format("%01dmn %02.1fs",
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Check if clipboard table contains valid parameters
function NotesObject:checkValidParamsFromClipboard()
	local result = false
	self.parametersFoundCountFromClipBoard = 0
	
	if self.parametersClipBoard ~= nil then
		self.parametersClipBoardTable = jfaTools.stringToTable(self.parametersClipBoard)
		
		if self.parametersClipBoardTable ~= nil and type(self.parametersClipBoardTable) == "table" then
			for label, data in pairs(self.parametersClipBoardTable) do
				if self:isTagIsReferenced(label) then
					-- Get tag & data parameters from clipboard
					if self.parametersFoundFromClipBoard == nil then self.parametersFoundFromClipBoard = {} end
					self.parametersFoundFromClipBoard[label] = data
					self.parametersFoundCountFromClipBoard = self.parametersFoundCountFromClipBoard + 1
					result = true
				end
				-- Get timeBegin parameters from clipboard
				if label == "timeBegin" then
					self.timeBeginFromClipboard = data
					-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("self.timeBeginFromClipboard: ") .. tostring(self.timeBeginFromClipboard))
				end
			end
		end
	end
	-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("checkValidParamsFromClipboard: ") .. self:getParametersLabelFoundInClipboard())
	return result	
end

-- Get parameters Label Found in clipboard
function NotesObject:getParametersLabelFoundInClipboard()
	local result = ""
	
	if self.parametersFoundFromClipBoard ~= nil then
		local iLoop = 0
		for label, def in pairs(self.parametersFoundFromClipBoard) do
			iLoop = iLoop + 1
			result = result .. jfaTools.getStringDataForLoop(label, iLoop, self.parametersFoundCountFromClipBoard)
		end
		result = result .. "\r" .. "Count: " .. tostring(iLoop)
	end
	return result
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

-- Method to save parameters to clipboard
function NotesObject:saveParameters()
	local data = jfaTools.tableToString(self.parametersFound)
	SV:setHostClipboard(data)
end

-- Method to set Parameters of a NotesObject
function NotesObject:setParameters(newTimeBegin)
	local result = ""
	local timeBeginConvClipBoard = self.timeBeginFromClipboard
	if type(timeBeginConvClipBoard) == "string" then timeBeginConvClipBoard = tonumber(timeBeginConvClipBoard) end
	local timeOffset = self.timeBegin - timeBeginConvClipBoard
	local newPoints = {}
	
	--if self.timeBegin == timeBeginConvClipBoard then
	for label, data in pairs(self.parametersClipBoardTable) do
		if self:isTagIsReferenced(label) then
			local pointsLabel = {}
			result = result .. label .. ": " .. "\r"
			newPoints[label] = {}

			-- pitchDelta=1:[1426381361, 6.7873301506042]|2:[1605705119, 161.53845214844]|3:[1624581303, 0.0]
			local paramSlitted = jfaTools.split(data, "|")
			local iPoint = 0
			-- Separate points by "|"
			for iLine = 1, #paramSlitted do
				local str = paramSlitted[iLine]
				local numberStr = jfaTools.split(str, ":")
				iPoint = iPoint + 1
				
				-- Separate indice by points by ":"
				if numberStr ~= nil then
					local numberVal = numberStr[2]
					-- delete brackets in string [10010, 1.0]
					numberVal = string.gsub(numberVal, "%[", "")
					numberVal = string.gsub(numberVal, "%]", "")

					if numberVal ~= nil then
						-- Separate time/value by ", "
						local labelToFind = jfaTools.split(numberVal, ", ")
						if labelToFind ~= nil then
							local points = {}
							local time = 0
							local value = 0
							-- (1) Time / (2) value couple
							for iLineSub = 1, #labelToFind do
								local strSub = labelToFind[iLineSub]
								if iLineSub == 1 then
									-- Time to be replaced
									local newTimeBegin = tonumber(strSub) + timeOffset
									time = newTimeBegin
									result = result .. "(".. tostring(iLine) .. ") " .. tostring(strSub) .. " to " .. tostring(newTimeBegin) .. ", "
								else
									-- Value
									value = tonumber(strSub)
									result = result .. tostring(strSub) .. "\r"
									
									points = {time, value}
									table.insert(pointsLabel, points)
								end
							end
						end
					end
					
					table.insert(newPoints[label], pointsLabel)
				end
			end
			result = result .. "\r"
		end
	end
	
	-- self:getNewPoints(newPoints)
	self:setNewPoints(newPoints)
	-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("setParameters:") .. "\r" .. result)
    return result
end

-- Get new points parameters
function NotesObject:getNewPoints(newPoints)
	local result = ""
	if newPoints == nil then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("NO new points!"))
	else
		local iPoint = 0
		for label, data in pairs(newPoints) do
			iPoint = iPoint + 1
			result = result .. label .. ":" .. "\r"
			local iPointDetail = 0
			for labelPoint, dataPoint in pairs(data[iPoint]) do
				iPointDetail = iPointDetail + 1
				-- ²result = result .. "labelPoint: " .. tostring(iPointDetail) .. "= " .. tostring(dataPoint) .. "\r"
				for iLineSub = 1, #dataPoint do
					result = result .. jfaTools.getStringDataForLoop(tostring(dataPoint[iLineSub]), iLineSub, #dataPoint)
				end
				result = result .. "\r"
			end
		end
		-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("New points found:") .. "\r" .. result)
	end
	return result
end

-- Set new points parameters
function NotesObject:setNewPoints(newPoints)
	local result = ""
	if newPoints == nil then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("NO new points!"))
	else
		
		local iPoint = 0
		for label, data in pairs(newPoints) do
			iPoint = iPoint + 1
			result = result .. label .. ":" .. "\r"
			local paramsGroup = self.groupFromNote:getParameter(label)
			if (paramsGroup ~= nil) then
				local iPointDetail = 0
				local time = 0
				local value = 0
				
				if data[iPoint] ~= nil then
					for labelPoint, dataPoint in pairs(data[iPoint]) do
						iPointDetail = iPointDetail + 1
						-- ²result = result .. "labelPoint: " .. tostring(iPointDetail) .. "= " .. tostring(dataPoint) .. "\r"
						for iLineSub = 1, #dataPoint do
							result = result .. jfaTools.getStringDataForLoop(tostring(dataPoint[iLineSub]), iLineSub, #dataPoint)
							if iLineSub == 1 then 
								time = dataPoint[iLineSub]
							else
								value = dataPoint[iLineSub]
							end
						end
						paramsGroup:add(time, value)
						result = result .. "\r"
					end
				end
			end
		end
		-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("New points found:") .. "\r" .. result)
	end
	return result
end

-- Dialog box for copy
function NotesObject:promptForCopy()
	local resultAction = false
	local info = self:getParametersLabelFoundInGroupNotes()
	local remark = ""
	
	if string.len(info) > 0 then
		remark = SV:T("Note:") .. "\r " .. info
	end
	
	local waitForm = {
		title = SV:T("Copy parameters"),
		message = SV:T("Script will copy existing parameters under a range of selected notes.") .. "\r"
				  .. SV:T("Then select target notes to paste.") .. "\r\r"
				  .. SV:T("Click Cancel to abort.") .. "\r"
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

-- Dialog box for copy
function NotesObject:promptForPaste()
	local resultAction = false
	local info = self:getParametersLabelFoundInClipboard()
	local remark = ""
	
	if string.len(info) > 0 then
		remark = SV:T("Note: ") .. info
	end
	
	local waitForm = {
		title = SV:T("Paste parameters"),
		message = SV:T("Script will paste existing parameters under selected notes.") .. "\r"
				  .. SV:T("Target notes will receive previous parameters.") .. "\r\r"
				  .. SV:T("Click Cancel to abort.") .. "\r"
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
		if notesObject.parametersFoundCountFromClipBoard == 0 then
			notesObject:getParameters()
			
			-- Copy action
			local resultAction = notesObject:promptForCopy()
			
			if resultAction then
				-- save parameters to clipboard
				notesObject:saveParameters()
				
				-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters copy done!") )
				local result = jfaTools.tableToString(notesObject.parametersFound)
				if string.len(result) > 0 then
					--SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("getParametersFound:") .. "\r" .. result)
					SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters copy DONE!") .. "\r\r"
					.. SV:T("Next step :") .. "\r"
					.. SV:T("Select a new note target to duplicate all parameters") .. "\r"
					.. SV:T("and start this script again!"))
				else
					SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters not found for selected notes!") )
				end
			end
		else
			notesObject:getParameters()
			-- Save new parameters to clipboard
			notesObject:saveParameters()

			local timeBeginConvClipBoard = notesObject.timeBeginFromClipboard
			if type(timeBeginConvClipBoard) == "string" then timeBeginConvClipBoard = tonumber(timeBeginConvClipBoard) end
			
			if notesObject.timeBegin == timeBeginConvClipBoard then
				local groupRefTimeoffset = notesObject.currentGroupRef:getTimeOffset()
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("!! STOP !!") .. "\r" .. SV:T("You cannot paste on the same selected notes!") .. "\r\r"
					.. SV:T("(Current note time begin is ") 
					.. notesObject:secondsToClock(notesObject:getBlickToSecond(notesObject.timeBegin + groupRefTimeoffset))
					.. ")" .. "\r"
					.. SV:T("Parameters type count: ") .. tostring(notesObject.parametersFoundCount)
					)
			else
				-- Paste action
				local resultAction = notesObject:promptForPaste()
				
				if resultAction then
					local resultParams = notesObject:setParameters()
					-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Result params:") .. "\r" .. jfaTools.tableToString(resultParams))
					SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters paste DONE!") .. "\r\r"
					.. SV:T("Next step :") .. "\r"
					.. SV:T("See the paste action result inside the parameters window."))
					
				end				
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
