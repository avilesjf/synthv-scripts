local SCRIPT_TITLE = 'Import midi file V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ImportMidiFile.lua

This script will import a midi file
and insert notes AND create groups into a new track
(not done by the default SynthV import).

Midi file path:
To avoid copy/pasting the midi file path each time,
midi file path is also retrieved from: Clipboard or trackname

Midi extracting source code comming from:
https://github.com/Possseidon/lua-midi/blob/main/lib/midi.lua

2024 - JF AVILES
--]]

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_MIDI",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

local DEBUG = false
-- A flick (frame-tick) is a very small unit of time. It is 1/705600000 of a second, exactly.
local ticksPerQuarter = nil
local ticks = 0

-- Main procedure
function main()
	local DEFAULT_FILE_PATH = ""
	local contentInfo = SV:getHostClipboard()
	local filenameInit = DEFAULT_FILE_PATH

	-- Get file name from last clipboard
	if string.find(contentInfo, InternalData.midiFileExtension, 1, true) ~= nil then
		filenameInit = fileTools.getCleanFilename(contentInfo)
	end
	
	local trackList, trackPos = trackTools.getTracksList()
	
	-- Get file name with path from a track name in SynthV
	if string.len(InternalData.midiFileNameFromTrack) > 0 then
		filenameInit = InternalData.midiFileNameFromTrack
	end
	
	local midiFilename = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Enter the full path to your MIDI file"), filenameInit)
	
	if string.len(midiFilename) > 0 then
		local filename = fileTools.getCleanFilename(midiFilename)
		mainTools.getNotesFromMidiFile(InternalData.project, getMidiReader(), filename, trackList, trackPos)
	end

	SV:finish()
end

InternalData = {
	project = SV:getProject(),
	timeAxis = SV:getProject():getTimeAxis(),
	blicksPerQuarter = SV.QUARTER, -- 705600000 
	CURRENT_LYRIC = "",
	INDEX_NOTE = 0,
	CURRENT_TRACK = 0,
	PREVIOUS_TRACK = 0,
	DELTA_TIME = 0,
	tempoMarkers = {},
	markers = {},
	midiTrackNames = {},
	notesTable = {},
	controllersTable = {},
	channelPressure = {},
	timeSignature = {},
	listAllTracks = {},
	midiFileNameFromTrack = "",
	midiFileExtension = ".mid",
	tempoActive = 120,
	metronomeActive = 24,
	signatureActive = 4, -- numerator
	denominatorActive = 4,
	dottedActive = 8,
	formatCount = "Count: %04d",
	formatNumber = "%4d",
	formatTrack = "%2d"
}

-- Call back to dispatch content data from midi file
function callback(name, ...)
	local handler = handlers[name]
	
	if handler then
		handler(...)
	end
end

-- main tools
mainTools = {
	-- Create user input form
	getForm = function(trackList)	
		local midiTrackList, listTracks, firstTrackWithNotes = fileTools.getMidiTrackList()
		local trackDefault =  0
		
		InternalData.listAllTracks = listTracks
		
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message =  SV:T("Select a midi source track,") .. "\r" 
					.. SV:T("A new track will be created with notes inside groups!"),
			buttons = "OkCancel",
			widgets = {
				{
					name = "trackMidi", type = "ComboBox",
					label = SV:T("Select a midi track (count = " .. #InternalData.listAllTracks .. ")"),
					choices = midiTrackList, 
					default = firstTrackWithNotes
				},
				{
					name = "separator", type = "TextArea", label = "", height = 0
				}
			}
		}
		return SV:showCustomDialog(form)
	end,
	
	-- Extract data from midi file
	extractMidiData = function(MidiReader, midiFilename)
		local file = io.open(midiFilename, 'rb')
		local result = {}
		
		-- Protected external call function
		local status, retval = pcall(function() resultTrack = MidiReader.process(file, callback) return resultTrack end)
		if not status then
			io.close(file)
			mainTools.show(SV:T("Failed to process MIDI file:") .. midiFilename .. "\r" .. retval)
		else
			io.close(file)
		end
		
		-- Track count in result
		result =  {
			status = status,
			tracksCount = retval
		}
		return result
	end,

	-- Get notes from midi file
	getNotesFromMidiFile = function(project, MidiReader, midiFilename, trackList, trackPos)
		local timeSecondEndPhrase = ""
		local lyricsIndice = 0
		local endTrack = false
		local trackFilterSynthV = 1
		local trackFilterMidi = 1
		local done = false
		
		if not fileTools.checkExternalFile(midiFilename) then 
			mainTools.show(SV:T("Failed to open MIDI from ") .. midiFilename)
			return done
		end
		
		local resultExtractMidi = mainTools.extractMidiData(MidiReader, midiFilename)
		local resultExtractMidiStatus = resultExtractMidi.status
		local tracksCount = resultExtractMidi.tracksCount
		
		if not resultExtractMidiStatus  then
			mainTools.show(SV:T("Nothing found during processing the MIDI file!"))
			return done
		end

		-- Result infos
		if #InternalData.notesTable > 0 then
			-- Message result
				
			local userInput = mainTools.getForm(trackList)
			
			if userInput.status then
				trackFilterMidi = InternalData.listAllTracks[userInput.answers.trackMidi + 1]
		
				-- Create groups from midi
				local result = groupsTools.createGroupsFromMidi(project, trackFilterMidi)
				if DEBUG then mainTools.show(SV:T("result: ") .. result) end
				done = true
			end

		else
			mainTools.show(SV:T("Nothing found!"))
		end
		
		return done
	end,
	
	-- Show message
	show = function(message)
		SV:showMessageBox(SV:T(SCRIPT_TITLE), message) 
	end,
	
	__FUNC__ = function() 
		return debug.getinfo(2, 'n').name
	end	
}


recordTools = {
	-- Store data from midi file
	recordDeltaTimes = function(timeBegin, ticks, timeSecond, channel, key, velocity)
		table.insert(InternalData.notesTable, {
			index = InternalData.INDEX_NOTE,
			track = InternalData.CURRENT_TRACK,
			ticksBegin  =  ticks,
			ticksEnd  = nil, -- not a duration but ticks for end of note
			timeBegin  =  timeBegin,
			timeEnd  =  nil, -- note duration
			timeSecondBegin = timeSecond,
			timeSecondEnd = nil,
			channel = channel,
			key = key,
			velocity = velocity,
			lyric = InternalData.CURRENT_LYRIC
		})
	end,

	-- Store controller data from midi file
	recordControllerDeltaTimes = function(timeBegin, ticks, timeSecond, channel, number, value)
		table.insert(InternalData.controllersTable, {
			index = InternalData.INDEX_NOTE,
			track = InternalData.CURRENT_TRACK,
			ticksBegin  =  ticks,
			timeBegin  =  timeBegin,
			timeSecondBegin = timeSecond,
			channel = channel,
			number = number, 
			value = value
		})
	end,

	-- Store markers data from midi file
	recordMarkerDeltaTimes = function(timeBegin, ticks, timeSecond, marker)
		table.insert(InternalData.markers, {
			index = InternalData.INDEX_NOTE,
			track = InternalData.CURRENT_TRACK,
			position = timeTools.ticksToBlicks(ticks),
			ticksBegin  =  ticks,
			timeBegin  =  timeBegin,
			timeSecondBegin = timeSecond,
			marker = marker
		})
	end,

	-- Store channel pressure data from midi file
	recordChannelPressureDeltaTimes = function(timeBegin, ticks, timeSecond, channel, pressure)
		table.insert(InternalData.channelPressure, {
			index = InternalData.INDEX_NOTE,
			track = InternalData.CURRENT_TRACK,
			ticksBegin  =  ticks,
			timeBegin  =  timeBegin,
			timeSecondBegin = timeSecond,
			channel = channel,
			pressure = pressure
		})
	end,

	-- Store time Signature data from midi file
	recordtimeSignatureDeltaTimes = function(timeBegin, ticks, timeSecond, numerator, denominator, metronome, dotted)
		table.insert(InternalData.timeSignature, {
			index = InternalData.INDEX_NOTE,
			track = InternalData.CURRENT_TRACK,
			ticksBegin  =  ticks,
			timeBegin  =  timeBegin,
			timeSecondBegin = timeSecond,
			numerator = numerator,
			denominator = denominator,
			metronome = metronome,
			dotted = dotted
		})
	end
}

-- time tools
timeTools = {
	-- Convert ticks to Blicks
	ticksToBlicks = function(ticks)
		if ticks ~= nil then
			return ticks / ticksPerQuarter * InternalData.blicksPerQuarter
		else
			return 1
		end
	end,

	-- Convert blicks to ticks
	blicksToTicks = function(blicks)
		return blicks / InternalData.blicksPerQuarter * ticksPerQuarter 
	end,
	
	-- Get string format from seconds
	secondsToClock = function(timestamp)
		return string.format("%02d:%06.3f", 
		  math.floor(timestamp/60)%60, 
		  timestamp%60):gsub("%.",",")
	end,
	
	-- Get time gap in blicks
	getTimeGapInBlicks = function(seconds)
		-- A flick (frame-tick) is a very small unit of time.
		-- It is 1/705600000 (SV.QUARTER) of a second, exactly.
		return InternalData.timeAxis:getBlickFromSeconds(seconds)
	end,
	
	-- Get project tempo marks list
	getProjectTempoMarksList = function()
		local result = ""
		local tempoMarks = InternalData.timeAxis:getAllTempoMarks()
		
		for iTempo = 1, #tempoMarks do
			local tempoMark = tempoMarks[iTempo]
			result = result .. "position: " .. tostring(tempoMark.position)
					.. ", seconds: " .. tostring(tempoMark.positionSeconds)
					.. ", bpm: " .. tostring(tempoMark.bpm)
					.. "\r"
		end
		return result
	end,

	-- Get current project tempo
	getProjectTempo = function(blicks)
		local tempoActive = 120
		local tempoMarks = InternalData.timeAxis:getAllTempoMarks()
		for iTempo = 1, #tempoMarks do
			local tempoMark = tempoMarks[iTempo]
			if tempoMark ~= nil and blicks > tempoMark.position then
				tempoActive = tempoMark.bpm
			end
		end
		return tempoActive
	end,
	
	getTimeLaps = function(blicks)
		-- 1s = 1411200000 blicks at 120 and 705600000 at 60
		--local posTempoMark, secondsTempoMark, bpmTempoMark = InternalData.timeAxis:getTempoMarkAt(blicks)
		local bpmTempoMark = timeTools.getProjectTempo(blicks)
		
		local timeLapsMax = 1
		if bpmTempoMark ~= nil then
			local timeLapsSeconds = 1+ ((120-bpmTempoMark)/bpmTempoMark) -- Tempo 60 = 2s and tempo 120 = 1s
			timeLapsMax = timeTools.getTimeGapInBlicks(timeLapsSeconds)
		end
		return timeLapsMax
	end
}

-- File tools
fileTools = {
	-- Check existing external file
	checkExternalFile = function(filename)
		local fileToOpen = io.open(filename, "r")	
		if fileToOpen ~= nil then io.close(fileToOpen) end
		return fileToOpen
	end,

	-- Get name for track
	getTrackName = function(iTrackPos)
		local trackName = ""
		for iTrack = 1, #InternalData.midiTrackNames do
			if InternalData.midiTrackNames[iTrack].track == iTrackPos then
				trackName = InternalData.midiTrackNames[iTrack].trackName
			end
		end
		return trackName
	end,

	-- Get Midi track list
	getMidiTrackList = function()
		local list = {}
		local listTracks = {}
		local trackNotesCount = 0
		local currentTrack = 1
		local positionTrack = 0
		local previousTrack = -1
		local firstTrackWithNotes = -1
		
		for iMidiNote = 1, #InternalData.notesTable do
			local note = InternalData.notesTable[iMidiNote]
			currentTrack = note.track
					
			if previousTrack >= 0 and previousTrack ~= currentTrack then
				if trackNotesCount > 0 then
					trackTools.addTrackList(list, listTracks, previousTrack, trackNotesCount)
					
					if firstTrackWithNotes < 0 then
						firstTrackWithNotes = positionTrack
					end
					positionTrack = positionTrack  + 1			
					trackNotesCount = 0
				end
			end
			
			previousTrack = currentTrack
			trackNotesCount = trackNotesCount + 1
		end
		
		if firstTrackWithNotes < 0 and trackNotesCount > 0 then
			firstTrackWithNotes = positionTrack
		end
		trackTools.addTrackList(list, listTracks, previousTrack, trackNotesCount)
		
		-- if DEBUG then mainTools.show("infos: " .. infos) end
		
		return list, listTracks, firstTrackWithNotes
	end,
	
	-- getCleanFilename
	getCleanFilename = function(file)
		local filename = file
		if string.len(filename) > 0 then
			if string.find(filename, '"') ~= nil then
				filename = filename:gsub('"', '')
			end
		end
		return filename
	end
}

-- Track tools
trackTools = {
	-- Add track list
	addTrackList = function(list, listTracks, iTrack, trackNotesCount)
		local trackLabel = SV:T("Track")
		local trackName = fileTools.getTrackName(iTrack)
		
		if string.len(trackName) > 0 then
			trackName = " '" .. trackName .. "'"
		end
		table.insert(list, trackLabel 
					.. string.format(InternalData.formatTrack, iTrack)
					.. trackName
					.. " (" .. string.format(InternalData.formatCount, trackNotesCount) .. ")")
		table.insert(listTracks, iTrack)
	end,

	-- Get list of tempo infos
	getTempoList = function()
		local list = ""
		
		for iTempo = 1, #InternalData.tempoMarkers do
			local tempoMarker = InternalData.tempoMarkers[iTempo]
			list = list 
							.. SV:T("Tempo pos: ") .. tempoMarker.position .. ", " 
							.. SV:T("ticks: ")     .. tempoMarker.ticksBegin .. ", " 
							.. SV:T("tempo: ")     .. tempoMarker.tempo .. "\r"
		end
		if DEBUG then mainTools.show(SV:T("list tempo: ") .. list) end
		return list
	end,

	-- Get time Signature track list
	getMidiTimeSignatureTrackList = function()
		local list = {}
		local value = 0
		local currentTrack = 1
		local trackLabel = SV:T("Track")
		
		for iMidiInfo = 1, #InternalData.timeSignature do
			local data = InternalData.timeSignature[iMidiInfo]
			currentTrack = data.track
			table.insert(list, trackLabel 
						.. string.format(InternalData.formatTrack, currentTrack)
						.. " (" .. timeTools.ticksToBlicks(data.ticksBegin) .. "/"
						.. "" .. data.ticksBegin .. "/"
						.. ""   .. data.timeBegin .. ")"
						.. ": " .. data.timeSecondBegin .. ": "
						.. " ".. SV:T("numerator:") .. " " .. string.format(InternalData.formatNumber, data.numerator)
						.. " " .. SV:T("denominator:") .. " " .. string.format(InternalData.formatNumber, data.denominator)
						.. " " .. SV:T("metronome:") .. " " .. string.format(InternalData.formatNumber, data.metronome)
						.. " " .. SV:T("dotted:") .. " " .. string.format(InternalData.formatNumber, data.dotted)
						)		
		end

		mainTools.show("timeSignature count: " .. #InternalData.timeSignature .. "\r" 
			.. "content:\r" ..  table.concat(list, "\r") )
		return list
	end,

	--- Get first note lyrics
	getFirstNotesLyrics = function(numNotes, groupNotesMain)
		local lyrics = ""
			if numNotes > 0 then
				local firstNote = groupNotesMain:getNote(1) -- First note
				if firstNote ~= nil then
					lyrics = firstNote:getLyrics()
				end
			end 
			if numNotes > 1 then
				local secondNote = groupNotesMain:getNote(2)
				if secondNote ~= nil then
					lyrics = lyrics .. " " .. secondNote:getLyrics()	
				end
			end
			
			if string.len(lyrics) > 0 then
				lyrics = " : " .. string.sub(lyrics, 1, 10)
			end
		return lyrics
	end,

	--- Get track list
	getTracksList = function()
		local list = {}
		local listPos = {}
		local tracks = InternalData.project:getNumTracks()
		for iTrack = 1, tracks do
			local track = InternalData.project:getTrack(iTrack)
			local mainGroupRef = track:getGroupReference(1) -- main group
			local groupNotesMain = mainGroupRef:getTarget()
			local numGroups = track:getNumGroups()
			local numNotes = groupNotesMain:getNumNotes()
			local lyrics = trackTools.getFirstNotesLyrics(numNotes, groupNotesMain)
			local trackName = track:getName()
			
			if (string.find(trackName, InternalData.midiFileExtension, 1, true) == nil and numNotes > 0) then
				table.insert(list, trackName
								.. " ("  .. string.format(InternalData.formatCount, numNotes) .. ") "
								.. lyrics
								)
				table.insert(listPos, iTrack - 1)
			end
			if string.find(trackName, InternalData.midiFileExtension, 1, true) ~= nil then
				InternalData.midiFileNameFromTrack = fileTools.getCleanFilename(trackName)
			end
		end
		return list, listPos
	end,
	
	-- Get tempo
	getTempo = function(ticks)
		local newTempo = InternalData.tempoActive
		
		for iTempo = 1, #InternalData.tempoMarkers do
			local tempoMarker = InternalData.tempoMarkers[iTempo]
			if tempoMarker.ticksBegin <= ticks then
				newTempo = tempoMarker.tempo
			end
		end
		return newTempo
	end,
	
	-- Get markers
	getMarkers = function()
		local result = ""
		for iMarker = 1, #InternalData.markers do
			local markerTemp = InternalData.markers[iMarker]
			result = result 
				.. SV:T("iMarker: ") .. iMarker .. ", " 
				.. SV:T("Marker pos: ") .. InternalData.timeAxis:getSecondsFromBlick(markerTemp.position) .. ", " 
				.. SV:T("Ticks: ")     .. markerTemp.ticksBegin .. ", " 
				-- .. SV:T("Time: ")     .. markerTemp.timeBegin .. ", " 
				.. SV:T("Seconds: ")     .. markerTemp.timeSecondBegin .. ", " 
				-- .. SV:T("Marker: ")     .. markerTemp.marker 
				.. "\r"
		end
		mainTools.show("result: " .. result)
	end,

	-- Get notes 
	getNotes = function()
		local result = ""
		
		for iMidiNote = 1, #InternalData.notesTable do
			local note = InternalData.notesTable[iMidiNote]
			result = result 
				.. "(" .. iMidiNote .. "): "
				--.. SV:T("Note pos: ") .. InternalData.timeAxis:getSecondsFromBlick(note.position) .. ", " 
				.. SV:T("Tk: ")     .. note.ticksBegin .. ", "
				-- .. SV:T("Time: ")     .. note.timeBegin .. ", " 
				.. SV:T("Sec: ")     .. note.timeSecondBegin .. ", " 
				.. SV:T("note: ")     .. note.key .. ": "
				.. note.lyric
				.. "\r"
		end
		mainTools.show("result: " .. result)
	end,

	-- Get metronome
	getMetronome = function(ticks)
		local newMetronome = InternalData.metronomeActive
		
		for iSignature = 1, #InternalData.timeSignature do
			local infoSignature = InternalData.timeSignature[iSignature]
			if infoSignature.ticksBegin <= ticks then
				newMetronome = infoSignature.metronome
			end
		end
		return newMetronome
	end,

	-- Get signature
	getSignature = function(ticks)
		local numerator = InternalData.signatureActive
		local denominator = InternalData.denominatorActive
		local metronome = InternalData.metronomeActive
		local dotted = InternalData.dottedActive
		
		for iSignature = 1, #InternalData.timeSignature do
			local infoSignature = InternalData.timeSignature[iSignature]
			if infoSignature.ticksBegin <= ticks then
				numerator = infoSignature.numerator
				denominator = infoSignature.denominator
				metronome = infoSignature.metronome
				dotted = infoSignature.dotted
			end
		end
		return numerator, denominator, metronome, dotted
	end,
	
	createTrack = function(project)
		local newTrack = SV:create("Track")
		local newTrackIndex = project:addTrack(newTrack)
		newTrack = project:getTrack(newTrackIndex)
		return newTrack
	end
}

-- groups tools
groupsTools = {

	-- Create groups from midi 
	createGroupsFromMidi = function(project, trackFilterMidi)
		local secondRef = 6
		local result = ""
		local groups = {}
		local groupNotes = {}
		local previousNote = nil
		-- if DEBUG then 
			-- result = result .. timeTools.getProjectTempoMarksList()
		-- end
		for iMidiNote = 1, #InternalData.notesTable do
			local note = InternalData.notesTable[iMidiNote]
			-- local noteSeconds = InternalData.timeAxis:getSecondsFromBlick(note.position)
			--local noteSeconds = note.timeSecondBegin
			currentTrack = note.track

			if trackFilterMidi == currentTrack then			
				local timeLaps = 0
				
				if previousNote ~= nil then
					-- if noteOff event missing => no ticksEnd and timeEnd updated
					if previousNote.ticksEnd ~= nil then
						local noteBlicks = timeTools.ticksToBlicks(note.ticksBegin)
						local previousNoteEndBlicks = timeTools.ticksToBlicks(previousNote.ticksEnd)
						
						local timeLaps = noteBlicks - previousNoteEndBlicks
						local timeLapsSecond = InternalData.timeAxis:getSecondsFromBlick(timeLaps)
						local timeLapsMax = timeTools.getTimeLaps(noteBlicks)
						local timeLapsMaxSecond = InternalData.timeAxis:getSecondsFromBlick(timeLapsMax)
						
						-- if DEBUG then 
							-- result = result .. "timeLapsMax: " .. timeLapsMax .. " timeLapsMaxSecond: " .. timeTools.secondsToClock(timeLapsMaxSecond)
								-- .. "\r"
						-- end
						
						if timeLapsSecond > timeLapsMaxSecond then
							-- New group with previous notes
							table.insert(groups, groupNotes )
							groupNotes = {}
						end
					end
				end
				-- Store new note into groups
				table.insert(groupNotes, note)
				
			end
			previousNote = note
		end

		if #groupNotes > 0 then
			table.insert(groups, groupNotes )
			groupNotes = {}
		end
		
		local track = trackTools.createTrack(project)
		for iGroup = 1, #groups do
			groupsTools.createGroup(project, track, groups[iGroup], iGroup)
		end
		
		
		-- if DEBUG then 
			-- mainTools.show("result: " .. string.sub(result, 1, 2000)) 
		-- end
		
		return result
	end,

	-- Create group from selected note and starting group from first nearest bar
	createGroup = function(project, track, groupNotes, iGroup)
		local maxLengthResult = 30
		local result = ""
		local measurePos = 0
		local measureBlick = 0
		local noteFirst = groupNotes[1]
		
		local measureFirst = InternalData.timeAxis:getMeasureAt(timeTools.ticksToBlicks(noteFirst.ticksBegin))
		local checkExistingMeasureMark = InternalData.timeAxis:getMeasureMarkAt(measureFirst)
		
		if checkExistingMeasureMark ~= nil then
			if checkExistingMeasureMark.position == measureFirst then
				measurePos = checkExistingMeasureMark.position
				measureBlick = checkExistingMeasureMark.positionBlick
			else 
				InternalData.timeAxis:addMeasureMark(measureFirst, 4, 4)
				local measureMark = InternalData.timeAxis:getMeasureMarkAt(measureFirst)
				measurePos = measureMark.position
				measureBlick = measureMark.positionBlick
				InternalData.timeAxis:removeMeasureMark(measureFirst)
			end
		else
			InternalData.timeAxis:addMeasureMark(measureFirst, 4, 4)
			local measureMark = InternalData.timeAxis:getMeasureMarkAt(measureFirst)
			measurePos = measureMark.position
			measureBlick = measureMark.positionBlick
			InternalData.timeAxis:removeMeasureMark(measureFirst)
		end
		
		-- Create new group 
		local noteGroup = SV:create("NoteGroup")
		
		for iNote = 1, #groupNotes do
			local noteMidi = groupNotes[iNote]
			
			local note = SV:create("Note")
			note:setOnset(timeTools.ticksToBlicks(noteMidi.ticksBegin) - measureBlick)
			note:setLyrics(noteMidi.lyric)
			note:setPitch(noteMidi.key)
			note:setDuration(timeTools.ticksToBlicks(noteMidi.timeEnd))
			
			if DEBUG then 
				result = result .. "note: " .. noteMidi.key 
					.. " : " .. timeTools.ticksToBlicks(noteMidi.ticksBegin) 
					.. "-" .. measureBlick 
					.. " Pos end note: " .. timeTools.ticksToBlicks(noteMidi.ticksEnd)
					.. " note duration: " .. timeTools.ticksToBlicks(noteMidi.timeEnd)
					.. "\r"
			end
			noteGroup:addNote(note)
		end

		noteGroup:setName("Group: " .. iGroup)
		project:addNoteGroup(noteGroup)
		
		local resultLyrics = groupsTools.renameOneGroup(maxLengthResult, noteGroup)
		
		local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
		newGrouptRef:setTimeOffset(measureBlick)
		track:addGroupReference(newGrouptRef)
		
		-- if DEBUG then 
			-- mainTools.show("result: " .. result)
		-- end
		return true
	end,

	-- Rename one group
	renameOneGroup = function(maxLengthResult, noteGroup)
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
					
						-- Filter char '+' & '-' & 'br' & ' & .cl & .pau & .sil
						if groupsTools.isTextAccepted(InternalData.timeAxis, note) then
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
			resultLyrics = groupsTools.limitStringLength(lyricsLine, maxLengthResult)
			-- Update if new lyrics only
			if string.len(resultLyrics)> 0 and 
				noteGroup:getName() ~= resultLyrics then
				noteGroup:setName(resultLyrics)
			end
		end

		return resultLyrics
	end,

	-- Limit string max length
	limitStringLength = function(resultLyrics, maxLengthResult)
		-- Limit string max length
		if string.len(resultLyrics) > maxLengthResult then
			local posStringChar = string.find(resultLyrics," ", maxLengthResult - 10)
			if posStringChar == nil then posStringChar = maxLengthResult end
			resultLyrics = string.sub(resultLyrics, 1, posStringChar)
		end
		return resultLyrics
	end,

	-- Is lyrics is a text accepted
	isTextAccepted = function(timeAxis, note)
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
}

handlers  = {
	-- Get header from midi file
	header = function(format, trackCount, tickCount)
		ticksPerQuarter = tickCount
	end,

	-- Get delta times from midi file
	deltatime = function(delta)
		ticks = ticks + delta
		InternalData.DELTA_TIME = delta
	end,

	-- Get noteOn from midi file
	noteOn = function(channel, key, velocity)
		InternalData.INDEX_NOTE = InternalData.INDEX_NOTE + 1
		
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, channel, key, velocity)
	end,

	-- Get noteOff from midi file
	noteOff = function(channel, key, velocity)
		-- Note duration (same note than noteOn event)
		InternalData.notesTable[InternalData.INDEX_NOTE].timeEnd = InternalData.DELTA_TIME
		
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		InternalData.notesTable[InternalData.INDEX_NOTE].timeSecondEnd = timeSecond
		InternalData.notesTable[InternalData.INDEX_NOTE].ticksEnd = ticks
	end,

	-- Get controller from midi file
	controller = function(channel, number, value)	
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordControllerDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, channel, number, value)
	end,

	-- Get modeMessage from midi file
	modeMessage = function(channel, number, value)
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordModeMessageDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, channel, number, value)
	end,

	-- Get channelPressure from midi file
	channelPressure = function(channel, pressure)
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordChannelPressureDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, channel, pressure)
	end,

	-- Get time Signature from midi file
	timeSignature = function(numerator, denominator, metronome, dotted)
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordtimeSignatureDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, numerator, denominator, metronome, dotted)
	end,

	-- Get status from midi file
	status = function(status)
		local timeSecond = 0
		if ticks > 0 then
			local secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordStatusDeltaTimes(InternalData.DELTA_TIME, ticks, timeSecond, status)
	end,

	-- Get markers from midi file
	marker = function(marker)
		local secNotePos = 0
		local timeSecond = 0
		if ticks > 0 then
			secNotePos = InternalData.timeAxis:getSecondsFromBlick(timeTools.ticksToBlicks(ticks))
			timeSecond = timeTools.secondsToClock(secNotePos)
		end
		recordTools.recordMarkerDeltaTimes(secNotePos, ticks, timeSecond, marker)
	end,

	-- Get lyrics from midi file
	lyric = function(data)
		InternalData.CURRENT_LYRIC = data
	end,

	-- Get sequencer or track name from midi file
	sequencerOrTrackName = function(data)
		table.insert(InternalData.midiTrackNames, {
			track = InternalData.CURRENT_TRACK,
			trackName = data
		})
	end,

	-- Get track number from midi file
	track = function(track) 
		if InternalData.CURRENT_TRACK ~= track then
			InternalData.PREVIOUS_TRACK = InternalData.CURRENT_TRACK
			InternalData.DELTA_TIME = 0
			ticks = 0
		end
		InternalData.CURRENT_TRACK = track
	end,

	-- Get tempo midi file data
	setTempo = function(tempo)
		table.insert(InternalData.tempoMarkers, {
			position = timeTools.ticksToBlicks(ticks),
			ticksBegin = ticks,
			tempo = tempo
		})
	end
}

--[[
  Avoiding to manage dependencies,
  getMidiReader is imported from https://github.com/Possseidon/lua-midi/blob/main/lib/midi.lua
  version from 04/2024
--]]

function getMidiReader()
	---Reads exactly count bytes from the given stream, raising an error if it can't.
	---@param stream file* The stream to read from.
	---@param count integer The count of bytes to read.
	---@return string data The read bytes.
	local function read(stream, count)
		local result = ""
		while #result ~= count do
			result = result .. assert(stream:read(count), SV:T("missing value"))
		end
		return result
	end

	---Reads a variable length quantity from the given stream, raising an error if it can't.
	---@param stream file* The stream to read from.
	---@return integer value The read value.
	---@return integer length How many bytes were read in total.
	local function readVLQ(stream)
		local value = 0
		local length = 0
		repeat
			local byte = assert(stream:read(1), SV:T("incomplete or missing variable length quantity")):byte()
			value = value << 7
			value = value | byte & 0x7F
			length = length + 1
		until byte < 0x80
		return value, length
	end
	
	local midiEvent = {
		[0x80] = function(stream, callback, channel, fb)
			local key, velocity = ("I1I1"):unpack(fb .. stream:read(1))
			callback("noteOff", channel, key, velocity / 0x7F)
			return 2
		end,
		[0x90] = function(stream, callback, channel, fb)
			local key, velocity = ("I1I1"):unpack(fb .. stream:read(1))
			callback("noteOn", channel, key, velocity / 0x7F)
			return 2
		end,
		[0xA0] = function(stream, callback, channel, fb)
			local key, pressure = ("I1I1"):unpack(fb .. stream:read(1))
			callback("keyPressure", channel, key, pressure / 0x7F)
			return 2
		end,
		[0xB0] = function(stream, callback, channel, fb)
		local number, value = ("I1I1"):unpack(fb .. stream:read(1))
			if number < 120 then
			  callback("controller", channel, number, value)
			else
			  callback("modeMessage", channel, number, value)
			end
			return 2
		end,
		[0xC0] = function(stream, callback, channel, fb)
			local program = fb:byte()
			callback("program", channel, program)
			return 1
		end,
		[0xD0] = function(stream, callback, channel, fb)
			local pressure = fb:byte()
			callback("channelPressure", channel, pressure / 0x7F)
			return 1
		end,
		[0xE0] = function(stream, callback, channel, fb)
			local lsb, msb = ("I1I1"):unpack(fb .. stream:read(1))
			callback("pitch", channel, (lsb | msb << 7) / 0x2000 - 1)
			return 2
		end
	}

	---Processes a manufacturer specific SysEx event.
	---@param stream file* The stream, pointing to one byte after the start of the SysEx event.
	---@param callback function The feedback providing callback function.
	---@param fb string The first already read byte, representing the manufacturer id.
	---@return integer length The total length of the read SysEx event in bytes (including fb).
	local function sysexEvent(stream, callback, fb)
		local manufacturer = fb:byte()
		local data = {}
		repeat
			local char = stream:read(1)
			table.insert(data, char)
		until char:byte() == 0xF7
		callback("sysexEvent", data, manufacturer, table.concat(data))
		return 1 + #data
	end

	---Creates a simple function, forwarding the provided name and read data to a callback function.
	---@param name string The name of the event, which is passed to the callback function.
	---@return function function The function, calling the provided callback function with name and read data.
	local function makeForwarder(name)
		return function(data, callback)
			callback(name, data)
		end
	end

	local metaEvents = {
		[0x00] = makeForwarder("sequenceNumber"),
		[0x01] = makeForwarder("text"),
		[0x02] = makeForwarder("copyright"),
		[0x03] = makeForwarder("sequencerOrTrackName"),
		[0x04] = makeForwarder("instrumentName"),
		[0x05] = makeForwarder("lyric"),
		[0x06] = makeForwarder("marker"),
		[0x07] = makeForwarder("cuePoint"),
		[0x19] = makeForwarder("newEvent"),
		[0x20] = makeForwarder("channelPrefix"),
		[0x2F] = makeForwarder("endOfTrack"),
		[0x51] = function(data, callback)
			local rawTempo = (">I3"):unpack(data)
			callback("setTempo", 6e7 / rawTempo)
		end,
		[0x54] = makeForwarder("smpteOffset"),
		[0x58] = function(data, callback)
			local numerator, denominator, metronome, dotted = (">I1I1I1I1"):unpack(data)
			callback("timeSignature", numerator, 1 << denominator, metronome, dotted)
		end,
		[0x59] = function(data, callback)
			local count, minor = (">I1I1"):unpack(data)
			callback("keySignature", math.abs(count), 
				count < 0 and "flat" or count > 0 and "sharp" or "C", 
				minor == 0 and "major" or "minor")
		end,
		[0x7F] = makeForwarder("sequenceEvent")
	}

	---Processes a midi meta event.
	---@param stream file* A stream pointing one byte after the meta event.
	---@param callback function The feedback providing callback function.
	---@param fb string The first already read byte, representing the meta event type.
	---@return integer length The total length of the read meta event in bytes (including fb).
	local function metaEvent(stream, callback, fb)
		local event = fb:byte()
		local length, vlqLength = readVLQ(stream)
		local data = read(stream, length)
		local handler = metaEvents[event]
		if handler then
			handler(data, callback)
		end
		return 1 + vlqLength + length
	end

	---Reads the four magic bytes and length of a midi chunk.
	---@param stream file* A stream, pointing to the start of a midi chunk.
	---@return string type The four magic bytes the chunk type (usually `MThd` or `MTrk`).
	---@return integer length The length of the chunk in bytes.
	local function readChunkInfo(stream)
		local chunkInfo = stream:read(8)
		if not chunkInfo then
			return false
		end
		assert(#chunkInfo == 8, "incomplete chunk info")
		return (">c4I4"):unpack(chunkInfo)
	end

	---Reads the content in a header chunk of a midi file.
	---@param stream file* A stream, pointing to the data part of a header chunk.
	---@param callback function The feedback providing callback function.
	---@param chunkLength integer The length of the chunk in bytes.
	---@return integer format The format of the midi file (0, 1 or 2).
	---@return integer tracks The total number of tracks in the midi file.
	local function readHeader(stream, callback, chunkLength)
		local header = read(stream, chunkLength)
		assert(header and #header == 6, "incomplete or missing header")
		local format, tracks, division = (">I2I2I2"):unpack(header)
		callback("header", format, tracks, division)
		return format, tracks
	end

	---Reads only a single event from the midi stream.
	---@param stream file* A stream, pointing to a midi event.
	---@param callback function The callback function, reporting the midi event.
	---@param runningStatus? integer A running status of a previous midi event.
	---@return integer length, integer runningStatus Returns both read length and the updated running status.
	local function processEvent(stream, callback, runningStatus)
		local firstByte = assert(stream:read(1), "missing event")
		local status = firstByte:byte()
		local length = 0
		
		if status < 0x80 then
			status = assert(runningStatus, "no running status")
		else
			firstByte = stream:read(1)
			length = 1
			runningStatus = status
		end
		
		if status >= 0x80 and status < 0xF0 then
			length = length + midiEvent[status & 0xF0](stream, callback, (status & 0x0F) + 1, firstByte)
		elseif status == 0xF0 then
			length = length + sysexEvent(stream, callback, firstByte)
		elseif status == 0xF2 then
			length = length + 2
		elseif status == 0xF3 then
			length = length + 1
		elseif status == 0xFF then
			length = length + metaEvent(stream, callback, firstByte)
		else
			callback("ignore", status)
		end

		return length, runningStatus
	end

	---Reads the content of a track chunk of a midi file.
	---@param stream file* A stream, pointing to the data part of a track chunk.
	---@param callback function The feedback providing callback function.
	---@param chunkLength number The length of the chunk in bytes.
	---@param track integer The one-based index of the track, used in the "track" callback.
	local function readTrack(stream, callback, chunkLength, track)
		callback("track", track)

		local runningStatus

		while chunkLength > 0 do
			local ticks, vlqLength = readVLQ(stream)

			if ticks > 0 then
				callback("deltatime", ticks)
			end

			local readChunkLength
			readChunkLength, runningStatus = processEvent(stream, callback, runningStatus)
			chunkLength = chunkLength - readChunkLength - vlqLength
		end
	end

	---Processes a midi file by calling the provided callback for midi events.
	---@param stream file* A stream, pointing to the start of a midi file.
	---@param callback? function The callback function, reporting the midi events.
	---@param onlyHeader? boolean Wether processing should stop after the header chunk.
	---@param onlyTrack? integer If specified, only this single track (one-based) will be processed.
	---@return integer tracks Returns the total number of tracks in the midi file.
	local function process(stream, callback, onlyHeader, onlyTrack)
		callback = callback or function() end

		local format, tracks
		local track = 0
		while true do
			local chunkType, chunkLength = readChunkInfo(stream)

			if not chunkType then
				break
			end

			if chunkType == "MThd" then
				assert(not format, SV:T("only a single header chunk is allowed"))
				format, tracks = readHeader(stream, callback, chunkLength)
				assert(tracks == 1 or format ~= 0, SV:T("midi format 0 can only contain a single track"))
				assert(not onlyTrack or onlyTrack >= 1 and onlyTrack <= tracks, SV:T("track out of range"))
				if onlyHeader then
					break
				end
			elseif chunkType == "MTrk" then
				track = track + 1
				assert(format, SV:T("no header chunk before the first track chunk"))
				assert(track <= tracks, SV:T("found more tracks than specified in the header"))
				assert(track == 1 or format ~= 0, SV:T("midi format 0 can only contain a single track"))

				if not onlyTrack or track == onlyTrack then
					readTrack(stream, callback, chunkLength, track)
					if onlyTrack then
						break
					end
					else
					stream:seek("cur", chunkLength)
				end
			else
				local data = read(chunkLength)
				callback("unknownChunk", chunkLength, chunkType, data)
			end
		end

		if not onlyHeader and not onlyTrack then
			assert(track == tracks, SV:T("found less tracks than specified in the header"))
		end

		return tracks
	end

	---Processes only the header chunk.
	---@param stream file* A stream, pointing to the start of a midi file.
	---@param callback function The callback function, reporting the midi events.
	---@return integer tracks Returns the total number of tracks in the midi file.
	local function processHeader(stream, callback)
		return process(stream, callback, true)
	end

	---Processes only the header chunk and a single, specified track.
	---@param stream file* A stream, pointing to the start of a midi file.
	---@param callback function The callback function, reporting the midi events.
	---@param track integer The one-based track index to read.
	---@return integer tracks Returns the total number of tracks in the midi file.
	local function processTrack(stream, callback, track)
		return process(stream, callback, false, track)
	end

	return {
		process = process,
		processHeader = processHeader,
		processTrack = processTrack,
		processEvent = processEvent
	}

end