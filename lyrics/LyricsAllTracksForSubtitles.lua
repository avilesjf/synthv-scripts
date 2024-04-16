local SCRIPT_TITLE = 'Lyrics All tracks in .SRT format to Clipboard V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: LyricsAllTracksForSubtitles.lua

Copy into clipboard, all lyrics for video subtitles (.SRT) format 
for all tracks in the project.

This will extract the lyrics from all existing grouped notes (groups) inside all tracks,
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

DEBUG = false

-- trim string
function trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%02d:%06.3f", 
	  math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Get lyrics data formated to .SRT with timecode
function getLyricsLineFormated(nextLines, lineInc, firstSecNotePos, firstSecNoteDuration, lyricsLine)
  
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

-- Add lyrics for sub groups
function AddLyricsSubGroups(lyricsSubGroups, track, groupName, groupIndex, subGroupIndex,
	previousNotePos, previousNoteDurations, firstSecNotePos, secPreviousNoteDuration, TimeOffset, lyricsLines)
	
	-- Add lyrics for sub groups and timing
	table.insert(lyricsSubGroups, {
		track = track:getDisplayOrder(),
		trackName = track:getName(),
		groupName = groupName,
		groupIndex = groupIndex,
		subGroupIndex = subGroupIndex,
		timeBegin  =  previousNotePos,
		timeEnd  =  previousNoteDurations,
		timeSecondBegin = firstSecNotePos,
		timeSecondEnd = secPreviousNoteDuration,
		timeOffset = TimeOffset,
		lyricsGroup = lyricsLines
	})
end

-- Get lyrics from tracks for all groups notes inside
function getTrackLyrics(track, timeAxis, secondDecayInput)
	local groupsCount = track:getNumGroups()
	local secondDecay = tonumber(secondDecayInput)
	local DAWOffset = timeAxis:getBlickFromSeconds(secondDecay)
	local firstNoteStarted = ""  
	local nextLines = ""
	local lineInc = 0
	local resultLyrics = {}
	local lyricsGroup = ""

	for iGroup = 1, groupsCount do
		local ref = track:getGroupReference(iGroup)
		local noteGroup = ref:getTarget()
		local groupName = noteGroup:getName()
		local notesCount = noteGroup:getNumNotes()
		local lyricsSubGroups = {}
		
		if notesCount > 0 then
			local firstSecNotePos = nil
			local previousNote = nil
			local previousNotePos = nil
			local previousNoteDuration = nil
			local secPreviousNoteDuration = 0
			local TimeOffset = 0
			local lyricsLine = ""
			local lyricsLines = ""
			local sepChar = ""
			local previousLyrics = ""
			local previousNoteDurations = 0
			
			-- loop notes in group
			for iNote = 1, notesCount do
				local infos = ""
				local note = noteGroup:getNote(iNote)
				subGroupAdded = false
				
				if note ~= nil then
					local lyrics = note:getLyrics()
					
					TimeOffset = ref:getTimeOffset() - DAWOffset
					local notePos = note:getOnset()
					local secNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
					
					if previousNotePos ~= nil then
						previousNoteDurations = previousNotePos + previousNoteDuration + TimeOffset
						secPreviousNoteDuration = timeAxis:getSecondsFromBlick(previousNoteDurations)
					end
					
					if string.len(lyrics) > 0 then
						-- First note loop
						if previousNote ~= nil then
							-- Next notes not linked
							if secPreviousNoteDuration ~= secNotePos then						
								lineInc = lineInc + 1
								local sepChar = ""
								if string.len(lyricsLines) > 0 then sepChar = " " end
								lyricsLines = lyricsLines .. sepChar .. trim(lyricsLine)
								
								AddLyricsSubGroups(lyricsSubGroups, track, groupName, iGroup, lineInc,
									previousNotePos, previousNoteDurations, 
									firstSecNotePos, secPreviousNoteDuration, TimeOffset, lyricsLine)
								
								if lineInc == 1 then
									-- To display only in last message box
									firstNoteStarted = SecondsToClock(firstSecNotePos)
								end
																
								lyricsLine = ""
								previousLyrics = ""
								nextLines = "\r\r"
								firstNotePos = note:getOnset()
								firstSecNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
								previousNoteDurations = previousNotePos + previousNoteDuration + TimeOffset
								secPreviousNoteDuration = timeAxis:getSecondsFromBlick(previousNoteDurations)
							end
						else
							-- First note
							firstNotePos = note:getOnset()
							firstSecNotePos = timeAxis:getSecondsFromBlick(notePos + TimeOffset)
						end
						
						-- Filter char '+' & '-'
						if lyrics ~= "+" and lyrics ~= "-"  then 
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
			
			if string.len(lyricsLine) > 0 then 
				lineInc = lineInc + 1
				local sepChar = ""
				if string.len(lyricsLines) > 0 then sepChar = " " end
				lyricsLines = lyricsLines .. sepChar .. trim(lyricsLine)
					
				AddLyricsSubGroups(lyricsSubGroups, track, groupName, iGroup, lineInc,
					previousNotePos, previousNoteDurations, 
					firstSecNotePos, secPreviousNoteDuration, TimeOffset, trim(lyricsLine))
			end
			
			
			-- Add lyrics and timing
			table.insert(resultLyrics, {
				track = track:getDisplayOrder(),
				trackName = track:getName(),
				groupName = groupName,
				groupIndex = iGroup - 1,
				timeBegin  =  previousNotePos,
				timeEnd  =  previousNoteDurations,
				timeOffset = TimeOffset,
				timeSecondBegin = firstSecNotePos,
				timeSecondEnd = secPreviousNoteDuration,
				lyricsGroup = lyricsLines,
				lyricsSubGroups = lyricsSubGroups,
				lyricsLength = string.len(lyricsLines)
			})

		end
	end
	
	return resultLyrics
  
end

-- Check number notes, get track ref
-- Get each track, group number, start Blick + seconds, duration
-- process sequence, get first group for all track, if same track get group from track ref

-- Get lyrics from all tracks
function getLyrics(secondDecayInput)
	local project = SV:getProject()
	local timeAxis = project:getTimeAxis()
	local trackCount = project:getNumTracks()
	local resultLyrics = {}
	local lyricsTable = {}
	local maxLyrics =  0
	local previousMaxLyrics =  0
	local trackReference = 1
	local trackReferenceOrder = 1
	local trackReferenceLyricsLength = 0
	local result = ""
	
	for iTrack = 1, trackCount do
		local track = project:getTrack(iTrack)
		local trackName = track:getName()
		maxLyrics = 0
		
		resultLyrics = getTrackLyrics(track, timeAxis, secondDecayInput)
		
		if #resultLyrics > 0 then
			
			local trackNumber = 0
			local previousTrackNumber = 0
			for iGroups = 1, #resultLyrics do
				local lyricsInGroups = resultLyrics[iGroups]
				trackNumber = lyricsInGroups.track
				
				table.insert(lyricsTable, {
					trackOrder = resultLyrics.track,
					trackNumber = iTrack,
					trackName = trackName,
					timeBegin  =  lyricsInGroups.timeBegin,
					timeEnd  =  lyricsInGroups.timeEnd,
					timeSecondBegin = lyricsInGroups.timeSecondBegin,
					timeSecondEnd = lyricsInGroups.timeSecondEnd,
					timeOffset = lyricsInGroups.timeOffset,
					groupIndex = lyricsInGroups.groupIndex,
					lyric = lyricsInGroups.lyricsGroup,
					lyricsSubGroups = lyricsInGroups.lyricsSubGroups
				})
				
				if DEBUG == true then				
					if previousTrackNumber ~= trackNumber then
						result = result .. "track: " .. tostring(lyricsInGroups.track) .. ": " .. trackName .. "\r" 
					end

					result = result
					 .. "       " .. "g " .. string.format("%02d", lyricsInGroups.groupIndex)
					 .. ", timeBegin: " .. string.format("%12d", lyricsInGroups.timeBegin)
					 .. ", timeEnd: " .. string.format("%12d", lyricsInGroups.timeEnd)
					 .. ", timeSecondBegin: " .. SecondsToClock(lyricsInGroups.timeSecondBegin)
					 .. ", timeSecondEnd: " .. SecondsToClock(lyricsInGroups.timeSecondEnd)
					 .. ", " .. string.format("%02d", lyricsInGroups.lyricsLength)
					 .. " => " .. lyricsInGroups.lyricsGroup
					 .. "\r" 
				end
				
				maxLyrics = maxLyrics + lyricsInGroups.lyricsLength
				
				local lyricsSubGroupsCount = #lyricsInGroups.lyricsSubGroups
				for iLyricsSubGroups = 1, lyricsSubGroupsCount do
					local subGroup = lyricsInGroups.lyricsSubGroups[iLyricsSubGroups]
					if DEBUG == true then
						result = result 
						.. "       " .. "       " .. "sg " .. string.format("%02d", iLyricsSubGroups) 
						-- .. " - "  .. string.format("%02d", subGroup.subGroupIndex)
						.. ", timeSecondBegin: " .. SecondsToClock(subGroup.timeSecondBegin) 
						.. ", timeSecondEnd: " .. SecondsToClock(subGroup.timeSecondEnd) 
						.. " => " .. tostring(subGroup.lyricsGroup)
						.. "\r"
					end
				end
				
				previousTrackNumber = trackNumber
			 end
		end
		
		if maxLyrics > previousMaxLyrics then
			trackReference = iTrack
			trackReferenceOrder = track:getDisplayOrder()
			trackReferenceLyricsLength = maxLyrics
		end
		previousMaxLyrics = maxLyrics
		-- result = result .. "track: " .. tostring(trackReferenceOrder) 
		-- .. " - ".. trackName .. ", maxLyrics: " .. tostring(maxLyrics) .. "\r" 
	end

	-- Result infos
	if #lyricsTable > 0 then
		local nextLines = ""
		local lyricsToStore = ""
		local lineInc = 0
		local previousLyrics = ""
		local previousTimeBegin = 0
		local previousTrackNumber = 0
		
		table.sort(lyricsTable, function(a, b) return a.timeSecondBegin < b.timeSecondBegin end)
		
		result = result .. "-------------".. "\r"
		for iGroups = 1, #lyricsTable do
			if lyricsTable[iGroups].lyric ~= previousLyrics or 
				(lyricsTable[iGroups].lyric == previousLyrics and lyricsTable[iGroups].timeSecondBegin ~= previousTimeBegin) then
				
				if DEBUG == true then
					result = result .. "track: " .. tostring(lyricsTable[iGroups].trackNumber) 
					.. ",  trackName: " .. lyricsTable[iGroups].trackName
					.. ",  timeSecondBegin: " .. tostring(lyricsTable[iGroups].timeSecondBegin)
					.. ",  groupIndex: " .. tostring(lyricsTable[iGroups].groupIndex)
					.. ",  lyric: " .. tostring(lyricsTable[iGroups].lyric)
					.. "\r"
				end
				-- Subgroups
				local subGroupsCount = #lyricsTable[iGroups].lyricsSubGroups
				for iSubGroups = 1, subGroupsCount do
					lineInc = lineInc + 1
					local subGroup = lyricsTable[iGroups].lyricsSubGroups[iSubGroups]
					
					if DEBUG == true then
						result = result 
						.. ", timeBegin: " .. tostring(subGroup.timeBegin)
						.. ", timeEnd: " .. tostring(subGroup.timeEnd)
						.. ", timeOffset: " .. tostring(subGroup.timeOffset)
						.. ", lineInc: " .. tostring(lineInc)
						.. ", timeSecondBegin: " .. tostring(subGroup.timeSecondBegin)
						.. ", timeSecondEnd: " .. tostring(subGroup.timeSecondEnd)
						.. ", lyricsGroup: " .. tostring(subGroup.lyricsGroup)
						.. "\r"
					end

					lyricsToStore = lyricsToStore  
					  .. getLyricsLineFormated(nextLines, lineInc, subGroup.timeSecondBegin, subGroup.timeSecondEnd, subGroup.lyricsGroup)
					nextLines = "\r\r"
				end
				
			end
			previousLyrics = lyricsTable[iGroups].lyric
			previousTimeBegin = lyricsTable[iGroups].timeSecondBegin
			previousTrackNumber = lyricsTable[iGroups].trackNumber
			
		end
		
		-- to Clipboard
		if DEBUG == true then
			SV:setHostClipboard(result)
		else
			SV:setHostClipboard(lyricsToStore)
		end	
		
		-- Message result
		local resultMessage = SV:T("Lyrics placed on clipboard!") .. "\r" 
		 .. SV:T("track count:") .. " " .. tostring(trackCount)  .. "\r"
		 .. SV:T("track max lyrics:") .. " " .. tostring(trackReferenceLyricsLength)
		 .. ", " .. SV:T("Reference:") .. " " .. tostring(trackReference) 
		 .. ", " .. SV:T("Display order:") .. " " .. tostring(trackReferenceOrder)
		 	
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