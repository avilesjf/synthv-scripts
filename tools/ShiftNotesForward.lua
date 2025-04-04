local SCRIPT_TITLE = 'Shift notes forward V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ShiftNotesForward.lua

This script will move notes forward
with a short gap.

Set shortcut to ALT + cursor right

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"No notes selected!", "No notes selected!"}
		}
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
	direction = 1, -- Forward
	selectedNotes = nil,
	timeGapSeconds = 0.001	-- Gap in milliseconds 1 millisecond = 1411200 blicks
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

    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Shift selected notes
function NotesObject:shiftSelectedNotes()
	-- Get time gap in blicks
	-- A flick (frame-tick) is a very small unit of time.
	-- It is 1/705600000 (SV.QUARTER) of a second, exactly.
	local timeGapBlicks = self.timeAxis:getBlickFromSeconds(self.timeGapSeconds)
	
	-- for each selected notes
	for iNote = 1, #self.selectedNotes do
		local note = self.selectedNotes[iNote]
		local notePos = note:getOnset()
		
		local noteTimeGap = notePos + (timeGapBlicks * self.direction)
		
		-- Set new position
		note:setOnset(noteTimeGap)
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