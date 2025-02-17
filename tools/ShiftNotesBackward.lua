local SCRIPT_TITLE = 'Shift notes backward V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ShiftNotesBackward.lua

This script will move notes forward
with a short gap.

Set shortcut to ALT + cursor left

2024 - JF AVILES
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

-- 1 millisecond = 1411200 blicks
local timeGapSeconds = 0.001	-- Gap in milliseconds
local direction = -1 			-- Backward

-- Shift selected notes
function shiftSelectedNotes(selectedNotes)
	local timeGapBlicks = getTimeGapInBlicks(timeGapSeconds)
	
	-- for each selected notes
	for iNote = 1, #selectedNotes do
		local note = selectedNotes[iNote]
		local notePos = note:getOnset()
		
		local noteTimeGap = notePos + (timeGapBlicks * direction)
		
		-- Set new position
		note:setOnset(noteTimeGap)
	end
end

-- Get selected notes
function getSelectedNotes()
	local selection = SV:getMainEditor():getSelection()
	local selectedNotes = selection:getSelectedNotes()
	return selectedNotes
end

-- Get time gap in blicks
function getTimeGapInBlicks(seconds)
    local project = SV:getProject()
    local timeAxis = project:getTimeAxis()
	
	-- A flick (frame-tick) is a very small unit of time.
	-- It is 1/705600000 (SV.QUARTER) of a second, exactly.
	return timeAxis:getBlickFromSeconds(seconds)
end

-- Main process
function main()
	local selectedNotes = getSelectedNotes()
	
	if #selectedNotes == 0 then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
	else		
		-- Start process
		shiftSelectedNotes(selectedNotes)
	end
	
	SV:finish()
end