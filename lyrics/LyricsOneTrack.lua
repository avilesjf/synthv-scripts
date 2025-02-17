local SCRIPT_TITLE = 'Lyrics one track to Clipboard V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: LyricsOneTrack.lua

Copy into clipboard, all lyrics inside all group of notes
in text format for current track.

This will extract the lyrics from all existing grouped notes (groups) inside one track,
and separate all not linked notes.

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Lyrics placed on clipboard!", "Lyrics placed on clipboard!"},
			{"track count:", "track count:"},
			{"track max lyrics:", "track max lyrics:"},
			{"Reference:", "Reference:"},
			{"Display order:", "Display order:"},
			{"Nothing found!", "Nothing found!"},
		},
	}
end

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

-- Add space between lyrics if they are stored in each note
function addSpaceChar(previousLyrics)
	local sepChar = ""
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

-- Check lyrics "a" less than .1s for special effect
function isLyricsEffect(timeAxis, note)
	local result = false
	local notelength = timeAxis:getSecondsFromBlick(note:getDuration())
	-- ie: 0.0635
	if notelength < 0.1 then
		result = true
	end
	return result
end

-- Is lyrics is a text accepted
function isTextAccepted(timeAxis, note)
	local result = false
	local lyrics = note:getLyrics()
	
	-- Filter char '+' & '++' & '-' & 'br' & ' & .cl & .pau & .sil
	if lyrics ~= "+" and lyrics ~= "++" and lyrics ~= "-" and lyrics ~= "br" and lyrics ~= "'" 
		and lyrics ~= ".cl" and lyrics ~= ".pau" and lyrics ~= ".sil"  then
		result = true
	end
	
	-- Specific for personal vocal effect
	if lyrics == "a" and isLyricsEffect(timeAxis, note) then
		result = false
	end

	return result
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
						
						-- Filter char '+' & '-' & 'br' & ' & .cl & .pau & .sil
						if isTextAccepted(timeAxis, note) then
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
function getLyrics()
	local project = SV:getProject()
	local timeAxis = project:getTimeAxis()
	local trackCount = project:getNumTracks()
	local track = SV:getMainEditor():getCurrentTrack()
	local resultLyrics = {}
	local lyricsTable = {}
	local maxLyrics =  0
	local previousMaxLyrics =  0
	local trackReference = 1
	local trackReferenceOrder = 1
	local trackReferenceLyricsLength = 0
	local result = ""
	
	local trackName = track:getName()
	maxLyrics = 0
	
	resultLyrics = getTrackLyrics(track, timeAxis, 0)
	
	if #resultLyrics > 0 then
		
		local trackNumber = 1
		local previousTrackNumber = 0
		for iGroups = 1, #resultLyrics do
			local lyricsInGroups = resultLyrics[iGroups]
			trackNumber = lyricsInGroups.track
			
			table.insert(lyricsTable, {
				trackOrder = resultLyrics.track,
				trackNumber = trackNumber,
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
		trackReference = 1
		trackReferenceOrder = track:getDisplayOrder()
		trackReferenceLyricsLength = maxLyrics
	end
	previousMaxLyrics = maxLyrics
	-- result = result .. "track: " .. tostring(trackReferenceOrder) 
	-- .. " - ".. trackName .. ", maxLyrics: " .. tostring(maxLyrics) .. "\r" 


	-- Result infos
	if #lyricsTable > 0 then
		local nextLines = ""
		local nextLyrics = ""
		local lyricsToStore = ""
		local lineInc = 0
		local previousLyrics = ""
		local previousTimeBegin = 0
		local previousTrackNumber = 0
		
		table.sort(lyricsTable, function(a, b) return a.timeSecondBegin < b.timeSecondBegin end)
		
		lyricsToStore = "Track: (" .. string.format("%02d", lyricsTable[1].trackNumber) .. ") " 
			.. string.format("%-20s", lyricsTable[1].trackName) .. " "
			.. "\r\r"
			
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
				
				lyricsToStore = lyricsToStore .. nextLines
				-- .. "Track: " .. "(" .. string.format("%02d", lyricsTable[iGroups].trackNumber) .. ") " 
				-- .. string.format("%-20s", lyricsTable[iGroups].trackName) .. " "
				.. "Group: " .. "(" .. string.format("%02d", lyricsTable[iGroups].groupIndex) .. ") " .. "\r"
				--.. "Group: " .. "(" .. string.format("%02d", lyricsTable[iGroups].groupIndex) ..") " 
				--.. lyricsTable[iGroups].lyric
				
				nextLyrics = ""
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

					lyricsToStore = lyricsToStore  .. nextLyrics .. subGroup.lyricsGroup
					nextLyrics = "\r"
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
	
	getLyrics()

	SV:finish()
end