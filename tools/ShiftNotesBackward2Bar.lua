local SCRIPT_TITLE = 'Shift notes backward to previous bar V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ShiftNotesBackward2Bar.lua

This script will move notes backward
to the first previous measure bar

Set shortcut to CTRL + ALT + Cursor left

2025 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"No notes selected!", "No notes selected!"},
		},
	}
end

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
	direction = -1,
	numerator = 4,
	denominator = 4,
	selectedNotes = nil,
	noteFirst = nil
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = notesObject.project:getTimeAxis()
    notesObject.editor =  SV:getMainEditor()
	notesObject.selectedNotes = notesObject.editor:getSelection():getSelectedNotes()
	if notesObject.selectedNotes ~= nil and #notesObject.selectedNotes > 0 then
		notesObject.noteFirst = notesObject.selectedNotes[1]
	end

    return notesObject
end

-- Create temp measure mark
function NotesObject:createTempMeasureMark(measureFirst)
	-- Temporary measure mark addition
	self.timeAxis:addMeasureMark(measureFirst, self.numerator, self.denominator)
	local measureMark = self.timeAxis:getMeasureMarkAt(measureFirst)
	local measurePos = measureMark.position
	local measureBlick = measureMark.positionBlick
	self.timeAxis:removeMeasureMark(measureFirst)
	return measurePos, measureBlick
end

-- Get first measure from note postion
function NotesObject:getFirstMeasureFromNote(notePos)
	local measurePos = 0
	local measureBlick = 0
	local noteIsOnFirstMeasure = false
	local measureFirst = self.timeAxis:getMeasureAt(notePos)
	local checkExistingMeasureMark = self.timeAxis:getMeasureMarkAt(measureFirst)
	
	if checkExistingMeasureMark ~= nil then
		self.numerator = checkExistingMeasureMark.numerator
		self.denominator = checkExistingMeasureMark.denominator
		measurePos = checkExistingMeasureMark.position
		measureBlick = checkExistingMeasureMark.positionBlick
		if measurePos == 0 and measureFirst == 0 then
			measureBlick = notePos
		else
			measurePos, measureBlick = self:createTempMeasureMark(measureFirst)
		end
	else
		measurePos, measureBlick = self:createTempMeasureMark(measureFirst)
	end
	noteIsOnFirstMeasure = notePos == measureBlick
		
	if noteIsOnFirstMeasure then
		if measureFirst > 1 then
			measureFirst = measureFirst - 1
			-- Carefull don't create new mark on measure = 0 => crash!
			measurePos, measureBlick = self:createTempMeasureMark(measureFirst)
		else
			measurePos = 0
			measureBlick = 0
		end
	end
	return measurePos, measureBlick
end

-- Shift selected notes
function NotesObject:shiftSelectedNotes()
	local measurePos, measureBlick = self:getFirstMeasureFromNote(self.noteFirst:getOnset())
	
	local noteTimeGap = self.noteFirst:getOnset() + (measureBlick * self.direction)
	-- for each selected notes
	for iNote = 1, #self.selectedNotes do
		local note = self.selectedNotes[iNote]

		-- Set new position
		note:setOnset(note:getOnset() + (noteTimeGap * self.direction))
	end
end

-- Main process
function main()
	local notesObject = NotesObject:new()

	if #notesObject.selectedNotes == 0 then
		notesObject:show(SV:T("No notes selected!"))
	else		
		-- Start process
		notesObject:shiftSelectedNotes()
	end
	
	SV:finish()
end