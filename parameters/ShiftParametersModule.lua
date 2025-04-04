local SCRIPT_TITLE = 'Shift parameters module V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ShiftParametersModule.lua

This script will move the offset parameters

Module for scripts ShiftParameters...lua

2025 - JF AVILES
--]]

-- Standard Synthesizer script call
function getClientInfo()
	return {
		-- name = SV:T(SCRIPT_TITLE),
		-- category = "_JFA_Parameters",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"DisplayName: ", "DisplayName: "},
			{"Type: ", "Type: "},
			{"Range: ", "Range: "},
			{"default: ", "default: "},
			{"Reference: ", "Reference: "},
			{"Multiple parameters reference are selected! Select only one!", "Multiple parameters reference are selected! Select only one!"},
			{"Please! Select a group!", "Please! Select a group!"},
		},
	}
end

-- Define a class  "MainObject"
MainObject = {
	SCRIPT_TITLE = SCRIPT_TITLE,
	project = nil,				-- initialization
	timeAxis = nil,				-- initialization
	editor = nil,				-- updated by initialization
	MODES = {}, 				-- up/down/left/right
	currentMode = 1, 			-- 1=up 2=down 3=left 4=right updated from parent call script
	PARAMETERS_REFERENCE = {},	-- initialization
	PARAMETER_REFERENCE = "",	-- updated on parameters found
	direction = 1,				-- updated when currentMode is set
	newGap = 0.1,				-- updated by parameter default values
	newTimePos = 0.01,			-- new time move
	reduceStepValue = 100,		-- reduce impact on moving value/points
	defaultValue = 1,			-- updated by parameter default values
	rangeValues = {},			-- updated by parameter default values
	currentGroupRef = nil,		-- initialization
	currentGroupNotes = nil,	-- initialization
	currentTrack = nil,			-- initialization
	paramsGroup = nil,			-- initialization
	endTrackPosition = 0,		-- initialization
	selection = nil,			-- initialization
	selectedNotes = nil,		-- initialization
	newPointsAllRef = {},		-- start
	newPoints = {},				-- start
	timeGapSeconds = 0.01		-- Gap in milliseconds 1 millisecond = 1411200 blicks
}

-- Constructor method for the MainObject class
function MainObject:new(SCRIPT_TITLE, currentMode)
    local mainObject = {}
    setmetatable(mainObject, self)
    self.__index = self
	
	self.SCRIPT_TITLE = SCRIPT_TITLE
	self.currentMode = currentMode
	
	-- Get project informations
	self:getProjectInformations()
	
	-- Set main variables
	self:setParameters()
	self:setModes()
	
	-- Update direction from current mode
	self.direction = self.MODES[self.currentMode].direction
	
    return self
end

-- Get project informations
function MainObject:getProjectInformations()
    self.project = SV:getProject()
    self.timeAxis = self.project:getTimeAxis()
    self.editor =  SV:getMainEditor()
	self.selection = self.editor:getSelection()
	self.selectedContent = self.selection:hasSelectedContent()
	self.selectedNotes = self.editor:getSelection():getSelectedNotes()
	self.currentGroupRef = self.editor:getCurrentGroup()
	if self.currentGroupRef ~= nil then
		self.currentGroupNotes = self.currentGroupRef:getTarget()
	end
	self.currentTrack = self.editor:getCurrentTrack()
	self.endTrackPosition = self.currentTrack:getGroupReference(self.currentTrack:getNumGroups()):getEnd()
	self.timeGapBlicks = self.timeAxis:getBlickFromSeconds(self.timeGapSeconds)
end

-- Show message dialog
function MainObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Set modes
function MainObject:setModes()
	self.MODES = {}
	if #self.MODES == 0 then
		-- Up/Down/Left/Right
		table.insert(self.MODES, {name="UP",	direction=1,	update="val"})
		table.insert(self.MODES, {name="DOWN",	direction=-1,	update="val"})
		table.insert(self.MODES, {name="LEFT",	direction=-1,	update="point"})
		table.insert(self.MODES, {name="RIGHT",	direction=1,	update="point"})
	end
end

-- Is update value (=> not update point)
function MainObject:isUpdateValue()
	return(self.MODES[self.currentMode].update == "val")
end

-- Start check current group
function MainObject:getObjectProperties(obj)
	local result = ""
	for k, v in pairs(obj) do
		if obj[k] ~= nil then
			result = result .. k .. "=" .. tostring(v) .. "\r"
		end
	end
	return result
end

-- Set parameters
function MainObject:setParameters()

	if #self.PARAMETERS_REFERENCE == 0 then
		table.insert(self.PARAMETERS_REFERENCE, {display = "Pitch Deviation", 	ref = "pitchDelta"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Vibrato Envelope",	ref = "vibratoEnv"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Loudness", 			ref = "Loudness"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Tension",			ref = "Tension"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Breathiness",		ref = "Breathiness"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Voicing",			ref = "Voicing"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Gender",			ref = "Gender"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Tone Shift",		ref = "ToneShift"})
		 -- Crash app v2.0.5
		-- table.insert(self.PARAMETERS_REFERENCE, {display = "Rap Intonation",	ref = "rapIntonation"})
		table.insert(self.PARAMETERS_REFERENCE, {display = "Mouth Opening",		ref = "MouthOpening"})
	end
end

-- get default parameter definition
function MainObject:getDefaultParamDefinition(parametersGroup)
	local range = {}
	local defaultValue = 0
	if parametersGroup ~= nil then		
		local paramsDef = parametersGroup:getDefinition()
		range = paramsDef.range
		defaultValue = paramsDef.defaultValue
	end
	return range, defaultValue
end

-- Get parameters definition
function MainObject:getParametersDefinition()
	local result = ""
	for _, parameter in pairs(self.PARAMETERS_REFERENCE) do
		local parameterGroup = self.currentGroupNotes:getParameter(parameter.ref)
		result = result .. parameter.display .. "="
			.. self:getForDisplayDefaultParamDefinition(parameterGroup)
			.. "\r"
	end
	return result
end

-- get default parameter definition for display
function MainObject:getForDisplayDefaultParamDefinition(parametersGroup)
	local result = ""
	
	if parametersGroup ~= nil then		
		local paramsDef = parametersGroup:getDefinition()
		local rangeInfo = ""
		local sep = ""
		for _, range in pairs(paramsDef.range) do
			rangeInfo = rangeInfo .. sep .. range
			sep = ";"
		end
		
		result = result ..  SV:T("DisplayName: ") .. paramsDef.displayName .. ", ".. SV:T("Type: ")
			.. paramsDef.typeName .. ", " .. SV:T("Range: ") .. rangeInfo 
			.. ", " .. SV:T("default: ") .. tostring(paramsDef.defaultValue) .. "\r"
	end
	return result
end


-- Get selected points in group parameters
function MainObject:getSelectedPointsInGroupParameters()
	local newPointsAllRef = {}
	
	for _, parameter in pairs(self.PARAMETERS_REFERENCE) do
		local newPoints = self.selection:getSelectedPoints(parameter.ref)
		if #newPoints > 0 then
			table.insert(newPointsAllRef, {ref = parameter.ref, points = newPoints})
		end
	end
	return newPointsAllRef
end

-- Get content selected points in group parameters
function MainObject:getSelectedContentPointsInGroupParameters()
	local result = ""
	
	for _, parameter in pairs(self.newPointsAllRef) do
		if #parameter.points> 0 then
			result = result .. SV:T("Reference: ") ..  parameter.ref .. "=" .. #parameter.points .. "\r"
		end
	end
	return result
end

-- Get first note in group
function MainObject:getFirstNoteInGroup()
	local noteFound = nil
	if self.currentGroupNotes:getNumNotes() > 1 then
		noteFound = self.currentGroupNotes:getNote(1)
	end
	return noteFound
end

-- Get last note in group
function MainObject:getLastNoteInGroup()
	local noteFound = nil
	if self.currentGroupNotes:getNumNotes() > 1 then
		noteFound = self.currentGroupNotes:getNote(self.currentGroupNotes:getNumNotes())
	end
	return noteFound
end

-- Get First and Last note in group
function MainObject:getFirstAndLastNoteInGroup()
	local firstNotePosition = -1
	local lastNotePosition = -1
	local firstNote = self:getFirstNoteInGroup()
	local lastNote = self:getLastNoteInGroup()
	if firstNote ~= nil then
		firstNotePosition = firstNote:getOnset()
	end
	if lastNote ~= nil then
		lastNotePosition = lastNote:getEnd()
	end
	return firstNotePosition, lastNotePosition
end

-- Get current note in position
function MainObject:getCurrentNoteInPosition(point)
	local noteFound = nil
	for iNote = 1, self.currentGroupNotes:getNumNotes() do
		local note = self.currentGroupNotes:getNote(iNote)
		if note:getOnset() <= point and note:getEnd() >= point then
			noteFound = note
			break
		end
	end
	return noteFound
end

-- Get group range time
function MainObject:getGroupRangeTime(firstNewPointPosition, lastNewPointPosition)
	local groupBegin = self.currentGroupRef:getOnset()
	local groupNewBegin = groupBegin
	local groupEnd = self.currentGroupRef:getOnset() + self.currentGroupRef:getDuration()
	local groupNewEnd = groupEnd
	if firstNewPointPosition < groupBegin then
		groupNewBegin = firstNewPointPosition - self.timeGapBlicks
	end
	if lastNewPointPosition > groupEnd then
		groupNewEnd = lastNewPointPosition + self.timeGapBlicks
	end
	return groupBegin, groupNewBegin, groupEnd, groupNewEnd
end

-- Add end points
function MainObject:addEndPoint(lastNotePosition, lastNewPointPosition, groupEnd, groupNewEnd)
	local endPoints = self.paramsGroup:getPoints(lastNewPointPosition + 1, groupEnd)
	
	-- If no more points after last point updated
	if #endPoints == 0 then
		-- Add a new point to reset position from last point value
		if lastNotePosition > -1 and lastNewPointPosition < lastNotePosition then
			if self.paramsGroup:get(lastNotePosition) ~= self.defaultValue then
				self.paramsGroup:add(lastNotePosition, self.defaultValue)
			end
		else
			if lastNewPointPosition > lastNotePosition then
				if self.paramsGroup:get(lastNewPointPosition + self.timeGapBlicks) ~= self.defaultValue then
					self.paramsGroup:add(lastNewPointPosition + self.timeGapBlicks, self.defaultValue)
				end
			end
		end
		
		if lastNewPointPosition > groupEnd then
			if self.paramsGroup:get(lastNewPointPosition + self.timeGapBlicks) ~= self.defaultValue then
				self.paramsGroup:add(lastNewPointPosition + (self.timeGapBlicks * 2), self.defaultValue)
			end
		end
	end
end

-- Add begin points
function MainObject:addBeginPoint(firstNotePosition, firstNewPointPosition, groupNewBegin, groupBegin)
	local firstPoints = self.paramsGroup:getPoints(0, groupNewBegin)

	-- If no points before first point updated
	if #firstPoints == 0 then			
		-- Add a new point to reset position from last point value
		if firstNotePosition > -1 and firstNewPointPosition > firstNotePosition then
			-- Fix new default value to start note
			if self.paramsGroup:get(firstNotePosition) ~= self.defaultValue then
				self.paramsGroup:add(firstNotePosition, self.defaultValue)
			end
		else
			if firstNewPointPosition < firstNotePosition then
				if self.paramsGroup:get(firstNewPointPosition - self.timeGapBlicks) ~= self.defaultValue then
					self.paramsGroup:add(firstNewPointPosition - self.timeGapBlicks, self.defaultValue)
				end
			end
		end
		
		if firstNewPointPosition < groupBegin then
			if self.paramsGroup:get(firstNewPointPosition - self.timeGapBlicks) ~= self.defaultValue then
				self.paramsGroup:add(firstNewPointPosition - (self.timeGapBlicks * 2), self.defaultValue)
			end
		end
	end
end

-- Shift selected points
function MainObject:shiftSelectedPoints(points)
	local newPoints = {}
	local addedPoints = 0
	
	if points[1]> 0 then
		firstNewPointval = self.paramsGroup:get(points[1])
	end
	
	for _, p in pairs(points) do
		local val = self.paramsGroup:get(p)
		
		self.paramsGroup:remove(p)
		
		local newVal = val
		local newPoint = p
		
		if self:isUpdateValue() then
			-- Up/down
			newVal = self:newPointValue(val)
		else
			-- Left/right
			newPoint = self:newPointPosition(p)
		end
		
		self.paramsGroup:add(newPoint, newVal)
		addedPoints = addedPoints + 1
		table.insert(newPoints, newPoint)
	end
	
	self:addPointsToCurrentNoteLimits(newPoints, addedPoints)

	return newPoints
end

-- New point value
function MainObject:newPointValue(val)
	return val + (self.newGap * self.direction)
end

-- New point position
function MainObject:newPointPosition(point)
	return point + (self.direction * self.timeAxis:getBlickFromSeconds(self.newTimePos))
end

-- Add points to current note limits
function MainObject:addPointsToCurrentNoteLimits(newPoints, addedPoints)
	if addedPoints > 0 then
		local firstNewPointPosition = newPoints[1]
		local firstNotePosition, lastNotePosition = self:getFirstAndLastNoteInGroup()
		local lastNewPointPosition = newPoints[#newPoints]
		local groupBegin, groupNewBegin, groupEnd, groupNewEnd = self:getGroupRangeTime(firstNewPointPosition, lastNewPointPosition)
		local notePosition = self:getCurrentNoteInPosition(firstNewPointPosition)
		if notePosition ~= nil then
			firstNotePosition = notePosition:getOnset()
			lastNotePosition = notePosition:getEnd()
		end
		self:addEndPoint(lastNotePosition, lastNewPointPosition, groupEnd, groupNewEnd)
		self:addBeginPoint(firstNotePosition, firstNewPointPosition, groupNewBegin, groupBegin)
	end
end

-- Update point value
function MainObject:updatePointValue(newPointsAllRef)
	if #newPointsAllRef > 0 then
		self.PARAMETER_REFERENCE = newPointsAllRef[1].ref
		self.newPoints = newPointsAllRef[1].points
		self.paramsGroup = self.currentGroupNotes:getParameter(self.PARAMETER_REFERENCE)
		
		-- Get new default and range value 
		self.range, self.defaultValue = self:getDefaultParamDefinition(self.paramsGroup)
		if #self.range > 0 then
			self.newGap = self.range[2] / self.reduceStepValue -- Reduce range to update value
		end
		
		if #self.newPoints > 0 then
			self.newPoints = self:shiftSelectedPoints(self.newPoints)
			if #self.newPoints >  0 then
				-- select new updated points
				self.selection:selectPoints(self.PARAMETER_REFERENCE, self.newPoints)
			end
		end
	end
end

-- Start process
function MainObject:start()
	
	if self.currentGroupRef ~= nil then
		-- SV:setHostClipboard(self:getParametersDefinition())
		if self.selectedContent then
			-- Get all selected points in parameters panel
			self.newPointsAllRef = self:getSelectedPointsInGroupParameters()
			
			-- Only one group at a time
			if #self.newPointsAllRef > 1 then
				local selContent = self:getSelectedContentPointsInGroupParameters()
				self:show(SV:T("Multiple parameters reference are selected! Select only one!") 
					.. "\r" .. selContent)
			else
				if #self.newPointsAllRef == 1 then
					self:updatePointValue(self.newPointsAllRef)
				end
			end		
		end	
	else
		self:show(SV:T("Please! Select a group!"))
	end
end

return 