local SCRIPT_TITLE = 'Group create from starting bar V1.0'

--[[

lua file name: GroupCreateFromStartingBar.lua

Create group of selected notes and start it from the nearest measure bar.
This to make it easier to copy/paste chorus 
on a another bar further into the song.

2024 - JF AVILES
--]]

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Lyrics",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

DEBUG = false

-- Limit string max length
function limitStringLength(resultLyrics, maxLengthResult)
	-- Limit string max length
	if string.len(resultLyrics) > maxLengthResult then
		local posStringChar = string.find(resultLyrics," ", maxLengthResult - 10)
		if posStringChar == nil then posStringChar = maxLengthResult end
		resultLyrics = string.sub(resultLyrics, 1, posStringChar)
	end
	return resultLyrics
end

-- Rename one group
function renameOneGroup(maxLengthResult, noteGroup)
	local resultLyrics = ""
	local groupName = noteGroup:getName()
	local notesCount = noteGroup:getNumNotes()

	if notesCount > 0 then
		local lyricsLine = ""
		local sep = ""

		for i = 1, notesCount do
			local infos = ""
			local note = noteGroup:getNote(i)
			
			if note ~= nil then
				local lyrics = note:getLyrics()			
				if string.len(lyrics) > 0 then
				
				  -- Filter char '+' & '-' & 'br'
				  if lyrics ~= "+" and lyrics ~= "br"  then
					-- Replace following note char '-'
					if lyrics == "-" then lyrics = ".." end 
					-- Add lyrics for each note
					lyricsLine = lyricsLine .. sep .. lyrics
					sep = " "
				  end
				  
				end
			end
		end

		-- Add lyrics
		resultLyrics = limitStringLength(lyricsLine, maxLengthResult)
		-- Update if new lyrics only
		if noteGroup:getName() ~= resultLyrics then noteGroup:setName(resultLyrics)	end
	end

	return resultLyrics
end

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%02d:%06.3f", 
	  math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Create group from selected note and starting group from first nearest bar
function CreateGroup()
	local maxLengthResult = 30
	local timeAxis = SV:getProject():getTimeAxis()
	local editor = SV:getMainEditor()
	local track = editor:getCurrentTrack()
	local notesNotFound = false
	local notesNotFoundCount = 0
	local selection = editor:getSelection()
	local selectedNotes = selection:getSelectedNotes()
	
	if #selectedNotes == 0 then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
		return false
	end
	
	local measurePos = 0
	local measureBlick = 0
	local noteFirst = selectedNotes[1]	
	
	local measureFirst = timeAxis:getMeasureAt(noteFirst:getOnset())
	local checkExistingMeasureMark = timeAxis:getMeasureMarkAt(measureFirst)
	
	if checkExistingMeasureMark ~= nil then
		if checkExistingMeasureMark.position == measureFirst then
			measurePos = checkExistingMeasureMark.position
			measureBlick = checkExistingMeasureMark.positionBlick
		else 
			timeAxis:addMeasureMark(measureFirst, 4, 4)
			local measureMark = timeAxis:getMeasureMarkAt(measureFirst)
			measurePos = measureMark.position
			measureBlick = measureMark.positionBlick
			timeAxis:removeMeasureMark(measureFirst)
		end
	else
		timeAxis:addMeasureMark(measureFirst, 4, 4)
		local measureMark = timeAxis:getMeasureMarkAt(measureFirst)
		measurePos = measureMark.position
		measureBlick = measureMark.positionBlick
		timeAxis:removeMeasureMark(measureFirst)
	end
	
	if DEBUG then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Notes start: ") .. noteFirst:getLyrics()
		.. ", sec: " .. tostring(timeAxis:getSecondsFromBlick(noteFirst:getOnset()))
		.. ", secClock: " .. SecondsToClock(timeAxis:getSecondsFromBlick(noteFirst:getOnset()))
		.. ", measure: " .. tostring(measurePos)
		.. ", secClock: " .. SecondsToClock(timeAxis:getSecondsFromBlick(noteFirst:getOnset()))
		.. ", pos: " .. tostring(noteFirst:getOnset())
		.. ", measureBlick: " .. tostring(measureBlick)
		.. ", secClockmeasureBlick: " .. SecondsToClock(timeAxis:getSecondsFromBlick(measureBlick))
		)
	end
	local groupRefMain = track:getGroupReference(1)
	local groupNotesMain = groupRefMain:getTarget()

	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	for iNote = 1, #selectedNotes do
		local note = selectedNotes[iNote]:clone()
		note:setOnset(note:getOnset() - measureBlick)
		noteGroup:addNote(note)
		-- Remove previous selected notes
		groupNotesMain:removeNote(selectedNotes[iNote]:getIndexInParent())
	end

	if not notesNotFound then
		noteGroup:setName(resultLyrics)
		SV:getProject():addNoteGroup(noteGroup)
		local resultLyrics = renameOneGroup(maxLengthResult, noteGroup)
		
		local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
		newGrouptRef:setTimeOffset(measureBlick)
		track:addGroupReference(newGrouptRef)
		

		if DEBUG then
			local result = ""
			for iNote = 1, groupNotes1:getNumNotes() do
				local note = groupNotes1:getNote(iNote)
				result = result .. note:getLyrics() .. ", "
			end
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("result: ") .. result)
		end
	else
		noteGroup = nil
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Notes not found in main group! Count notes not found: ") .. tostring(notesNotFoundCount))
	end
	
	return true
end

function main()

  CreateGroup()
  SV:finish()
end