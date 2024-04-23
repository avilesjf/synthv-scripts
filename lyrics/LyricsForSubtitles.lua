local SCRIPT_TITLE = 'Lyrics track in .SRT format to Clipboard V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: LyricsForSubtitles.lua

Copy into clipboard, all lyrics for video subtitles (.SRT) format
one selected track only

This will extract the lyrics from all existing grouped notes (groups) inside a track,
separate all not linked notes.

Example :
1
00:00:06,873 --> 00:00:09,709
Lyrics of the song

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

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%02d:%06.3f", 
	  math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Get lyrics data formated to .SRT with timecode
function getLyricsLine(timeAxis, nextLines, firstNotePos, firstSecNoteDurations, TimeOffset, 
  lineInc, firstSecNoteDuration, firstSecNotePos, lyricsLine)
  
	firstSecNoteDuration = timeAxis:getSecondsFromBlick(firstNotePos + firstSecNoteDurations + TimeOffset)
	return nextLines .. tostring(lineInc) 
	.. "\r" .. SecondsToClock(firstSecNotePos) .. " --> " .. SecondsToClock(firstSecNoteDuration) 
	.. "\r" .. lyricsLine
end

-- Add space between lyrics if they are stored in each note
function addSpaceChar(previousLyrics)
	sepChar = ""
	local tempStr = ""
	local tempStrLen = string.len(previousLyrics)
	if string.len(previousLyrics)>0 then
		tempStr = string.sub(previousLyrics, -1)
		if tempStr ~= " " then
			sepChar = " "
		end
	end	
	return sepChar
end

-- Check number notes, get track ref
-- Get each track, group number, start Blick + seconds, duration
-- process sequence, get first group for all track, if same track get group from track ref

-- Get lyrics from groups notes
function getLyrics(secondDecayInput) 
	local timeAxis = SV:getProject():getTimeAxis()
	local editor = SV:getMainEditor()
	local track = editor:getCurrentTrack()
	local groupsCount = track:getNumGroups()
	local secondDecay = tonumber(secondDecayInput)
	local DAWOffset = timeAxis:getBlickFromSeconds(secondDecay)
	local firstNoteStarted = ""  
	local nextLines = ""
	local lineInc = 0
	local resultLyrics = ""

	for j = 1, groupsCount do
		local ref = track:getGroupReference(j)
		local noteGroup = ref:getTarget()
		local groupName = noteGroup:getName()
		local notesCount = noteGroup:getNumNotes()

		if notesCount > 0 then
			local firstNotePos = nil
			local firstSecNotePos = nil
			local firstSecNoteDuration = nil
			local firstSecNoteDurations = nil
			local previousNote = nil
			local previousNotePos = nil
			local previousNoteDuration = nil
			local secPreviousNoteDuration = 0
			local TimeOffset = 0
			local lyricsLine = ""
			local lyricsLines = ""
			local sepChar = ""
			local previousLyrics = ""
			
			-- loop notes in group
			for i = 1, notesCount do
				local infos = ""
				local note = noteGroup:getNote(i)
				
				if note ~= nil then
					local lyrics = note:getLyrics()
					local duration = note:getDuration()
					
					if firstSecNoteDurations == nil then
						firstNotePos = note:getOnset()
						firstSecNoteDurations = note:getDuration()
					else 
						firstSecNoteDurations = firstSecNoteDurations + note:getDuration()
					end
					
					TimeOffset = ref:getTimeOffset() - DAWOffset
					local notePos = note:getOnset()
					local secNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
					
					if previousNotePos ~= nil then
						secPreviousNoteDuration = timeAxis:getSecondsFromBlick(previousNotePos + previousNoteDuration + TimeOffset)
					end
					
					if string.len(lyrics) > 0 then
						-- First note loop
						if previousNote ~= nil then
							-- Next notes not linked
							if secPreviousNoteDuration ~= secNotePos then						
								lineInc = lineInc + 1
								lyricsLines = lyricsLines .. getLyricsLine(timeAxis, nextLines, firstNotePos, firstSecNoteDurations, 
								  TimeOffset, lineInc, firstSecNoteDuration, firstSecNotePos, lyricsLine)
								if lineInc == 1 then
									-- To display only in last message box
									firstNoteStarted = SecondsToClock(firstSecNotePos)
								end
								lyricsLine = ""
								previousLyrics = ""
								nextLines = "\r\r"
								firstNotePos = note:getOnset()
								firstSecNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
								firstSecNoteDurations = note:getDuration()
							end
						else
							-- First note
							firstNotePos = note:getOnset()
							firstSecNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
						end
						-- Filter char '+' & '-' & 'br'
						if lyrics ~= "+" and lyrics ~= "-" and lyrics ~= "br"  then
							-- add space between lyrics if they are stored in each note
							sepChar = addSpaceChar(previousLyrics)

							-- Add lyrics for each note
							lyricsLine = lyricsLine .. sepChar .. lyrics
							previousLyrics = lyrics
						end
					end
					previousNote = note
					previousNotePos = previousNote:getOnset()
					previousNoteDuration = previousNote:getDuration()				
				end
			end
			lineInc = lineInc + 1
			lyricsLines = lyricsLines .. getLyricsLine(timeAxis, nextLines, firstNotePos, firstSecNoteDurations, TimeOffset, 
			  lineInc, firstSecNoteDuration, firstSecNotePos, lyricsLine)

			-- Add lyrics and timing
			resultLyrics = resultLyrics .. lyricsLines
		end
	end

	-- Result infos
	if string.len(resultLyrics) > 0 then 
		-- to Clipboard
		SV:setHostClipboard(resultLyrics)
		-- Message result
		local resultMessage = SV:T("Lyrics placed on clipboard!") .. "\r" 
		 .. SV:T("First note started at:") .. " " .. firstNoteStarted
		SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage)
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found!"))
	end
  
end

function main()
	local message = SV:T("Add an offset (in seconds)")  .. "\r"
	 .. SV:T("corresponding to the start of your project in your DAW") .. "\r"
	 .. SV:T("(Only if your project doesn't start from the first bar!)") .. "\r"
	
	local defaultText = "0"
	local results = SV:showInputBox(SV:T(SCRIPT_TITLE), message, defaultText)
	if string.len(results) > 0 then
		getLyrics(results)
	end

	SV:finish()
end