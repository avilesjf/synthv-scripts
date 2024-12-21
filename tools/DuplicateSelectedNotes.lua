local SCRIPT_TITLE = 'Duplicate selected notes V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: DuplicateSelectedNotes.lua

This script will duplicate selected notes to 
a new selected target playhead postion.

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

-- Duplicate selected notes
function duplicateNotes(selectedNotes, newStartPosition)
	local currentTrack = SV:getMainEditor():getCurrentTrack()
	local groupRefMain = currentTrack:getGroupReference(1)
	local currentGroupRef = SV:getMainEditor():getCurrentGroup()
	local groupNotesMain = currentGroupRef:getTarget()
	local firstNotePosition = selectedNotes[1]:getOnset()
	
	-- for each selected notes
	for iNote = 1, #selectedNotes do
		local note = selectedNotes[iNote]:clone()

		-- Set new position
		note:setOnset(note:getOnset() - firstNotePosition + newStartPosition)
		groupNotesMain:addNote(note)
	end
	
end

-- Get selected notes
function getSelectedNotes()
	local selection = SV:getMainEditor():getSelection()
	local selectedNotes = selection:getSelectedNotes()
	return selectedNotes
end

-- Main process
function main()
	local timeAxis = SV:getProject():getTimeAxis()
	local selectedNotes = getSelectedNotes()
	local playBack = SV:getPlayback()	
	local seconds = playBack:getPlayhead()
	
	local newStartPosition = timeAxis:getBlickFromSeconds(seconds)
	-- Round a time position based on snapping settings
	local newTimePos = SV:getMainEditor():getNavigation():snap(newStartPosition)
	
	if #selectedNotes == 0 then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
	else		
		-- Start process
		duplicateNotes(selectedNotes, newTimePos)
	end
	
	SV:finish()
end