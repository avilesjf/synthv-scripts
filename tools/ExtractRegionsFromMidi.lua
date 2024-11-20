local SCRIPT_TITLE = 'Extract regions from midi file V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ExtractRegionsFromMidi.lua

This script will extract the regions (maskers) inside a midi file
and copy them to loudness SynthV parameter.

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

-- A flick (frame-tick) is a very small unit of time. It is 1/705600000 of a second, exactly.
local blicksPerQuarter = SV.QUARTER -- 705600000 
local ticksPerQuarter = nil
local DEBUG = false
local DEBUG_RESULT = ""
local midiFileNameFromTrack = ""
local midiFileExtension = ".mid"
local DEFAULT_FILE_PATH = ""
if DEBUG then 
	DEFAULT_FILE_PATH = "D:\\Cubase Projects\\SimpleLife\\SimpleLifeLead1.mid"
end

local ticks = 0

-- Times infos
local tempoActive = 120
local metronomeActive = 24
local signatureActive = 4 -- numerator
local denominatorActive = 4
local dottedActive = 8

local tempoMarkers = {}
local markers = {}
local midiTrackNames = {}
local markerTickActive = 0
local markerSecondActive = 0
local notesTable = {}
local controllersTable = {}
local channelPressure = {}
local modeMessage = {}
local timeSignature = {}
local listAllTracks = {}
local controllerCC = 1  -- CC 1

local CURRENT_LYRIC = ""
local INDEX_NOTE = 0
local CURRENT_TRACK = 0
local PREVIOUS_TRACK = 0
local DELTA_TIME = 0
local project = SV:getProject()
local timeAxis = project:getTimeAxis()
local formatCount = "Count: %04d"
local formatNumber = "%4d"
local formatTrack = "%2d"
local handlers = {}

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%06.3f", 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Store data from midi file
function recordDeltaTimes(timeBegin, ticks, timeSecond, channel, key, velocity)
    table.insert(notesTable, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		ticksEnd  = nil,
		timeBegin  =  timeBegin,
		timeEnd  =  nil,
		timeSecondBegin = timeSecond,
		timeSecondEnd = nil,
		channel = channel,
		key = key, 
		velocity = velocity,
        lyric = CURRENT_LYRIC
    })
end

-- Store controller data from midi file
function recordControllerDeltaTimes(timeBegin, ticks, timeSecond, channel, number, value)
    table.insert(controllersTable, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		timeBegin  =  timeBegin,
		timeSecondBegin = timeSecond,
		channel = channel,
		number = number, 
		value = value
    })
end

-- Store mode Message data from midi file
function recordModeMessageDeltaTimes(timeBegin, ticks, timeSecond, channel, number, value)
    table.insert(modeMessage, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		timeBegin  =  timeBegin,
		timeSecondBegin = timeSecond,
		channel = channel,
		number = number, 
		value = value
    })
end

-- Store channel pressure data from midi file
function recordChannelPressureDeltaTimes(timeBegin, ticks, timeSecond, channel, pressure)
    table.insert(channelPressure, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		timeBegin  =  timeBegin,
		timeSecondBegin = timeSecond,
		channel = channel,
		pressure = pressure
    })
end

-- Store time Signature data from midi file
function recordtimeSignatureDeltaTimes(timeBegin, ticks, timeSecond, numerator, denominator, metronome, dotted)
    table.insert(timeSignature, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		timeBegin  =  timeBegin,
		timeSecondBegin = timeSecond,
		numerator = numerator,
		denominator = denominator,
		metronome = metronome,
		dotted = dotted
    })
end

-- Get header from midi file
function handlers.header(format, trackCount, tickCount)
    ticksPerQuarter = tickCount
end

-- Get delta times from midi file
function handlers.deltatime(delta)
    ticks = ticks + delta
	DELTA_TIME = delta
end

-- Get noteOn from midi file
function handlers.noteOn(channel, key, velocity)
    INDEX_NOTE = INDEX_NOTE + 1
	
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordDeltaTimes(DELTA_TIME, ticks, timeSecond, channel, key, velocity)
end

-- Get noteOff from midi file
function handlers.noteOff(channel, key, velocity)
	notesTable[INDEX_NOTE].timeEnd = DELTA_TIME
	
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	notesTable[INDEX_NOTE].timeSecondEnd = timeSecond
	notesTable[INDEX_NOTE].ticksEnd = ticks
end

-- Get controller from midi file
function handlers.controller(channel, number, value)	
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordControllerDeltaTimes(DELTA_TIME, ticks, timeSecond, channel, number, value)
end

-- Get modeMessage from midi file
function handlers.modeMessage(channel, number, value)
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordModeMessageDeltaTimes(DELTA_TIME, ticks, timeSecond, channel, number, value)
end

-- Get channelPressure from midi file
function handlers.channelPressure(channel, pressure)
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordChannelPressureDeltaTimes(DELTA_TIME, ticks, timeSecond, channel, pressure)
end

-- Get time Signature from midi file
function handlers.timeSignature(numerator, denominator, metronome, dotted)
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordtimeSignatureDeltaTimes(DELTA_TIME, ticks, timeSecond, numerator, denominator, metronome, dotted)
end

-- Get markers from midi file
function handlers.marker(marker)
    table.insert(markers, {
        position = ticksToBlicks(ticks),
        ticksBegin = ticks,
        timeBegin = 0,
        marker = marker
    })
end

-- Get lyrics from midi file
function handlers.lyric(data)
	CURRENT_LYRIC = data
end

-- Get sequencer or track name from midi file
function handlers.sequencerOrTrackName(data)
    table.insert(midiTrackNames, {
		track = CURRENT_TRACK,
        trackName = data
    })
end

-- Get track number from midi file
function handlers.track(track) 
	if CURRENT_TRACK ~= track then
		PREVIOUS_TRACK = CURRENT_TRACK
		DELTA_TIME = 0
		ticks = 0
	end
	CURRENT_TRACK = track
end

-- Get tempo midi file data
function handlers.setTempo(tempo)
    table.insert(tempoMarkers, {
        position = ticksToBlicks(ticks),
        ticksBegin = ticks,
        tempo = tempo
    })
end

-- Convert ticks to Blicks
function ticksToBlicks(ticks)
    return ticks / ticksPerQuarter * blicksPerQuarter
end

-- Convert blicks to ticks
function blicksToTicks(blicks)
	return blicks / blicksPerQuarter * ticksPerQuarter 
end

-- Call back to dispatch content data from midi file
local function callback(name, ...)
    local handler = handlers[name]
	-- DEBUG_RESULT = DEBUG_RESULT .. "handlers:" .. name .. "\r"
    if handler then
		handler(...)
    end
end

-- Check existing external file
function checkExternalFile(filename)
    local filetoOpen = io.open(filename, "r")	
	if filetoOpen ~= nil then io.close(filetoOpen) end
    return filetoOpen
end

-- Get name for track
function getTrackName(iTrackPos)
	local trackName = ""
	for iTrack = 1, #midiTrackNames do
		if midiTrackNames[iTrack].track == iTrackPos then
			trackName = midiTrackNames[iTrack].trackName
		end
	end
	return trackName
end

-- Get Midi track list
function getMidiTrackList()
	local list = {}
	local listTracks = {}
	local trackNotesCount = 0
	local currentTrack = 1
	local positionTrack = 0
	local previousTrack = -1
	local firstTrackWithNotes = -1
	
	for iMidiNote = 1, #notesTable do
		local note = notesTable[iMidiNote]
		currentTrack = note.track
				
		if previousTrack >= 0 and previousTrack ~= currentTrack then
			if trackNotesCount > 0 then
				addTrackList(list, listTracks, previousTrack, trackNotesCount)
				
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
	addTrackList(list, listTracks, previousTrack, trackNotesCount)
	
	-- if DEBUG then SV:showMessageBox("", "infos: " .. infos) end
	
	return list, listTracks, firstTrackWithNotes
end

-- Add track list
function addTrackList(list, listTracks, iTrack, trackNotesCount)
	local trackLabel = SV:T("Track")
	
	table.insert(list, trackLabel 
				.. string.format(formatTrack, iTrack)
				.. " '" .. getTrackName(iTrack) .. "'"
				.. " (" .. string.format(formatCount, trackNotesCount) .. ")")
	table.insert(listTracks, iTrack)
end

-- Get list of tempo infos
function getTempoList()
	local list = ""
	
	for iTempo = 1, #tempoMarkers do
		local tempoMarker = tempoMarkers[iTempo]
		list = list 
						.. SV:T("Tempo pos: ") .. tempoMarker.position .. ", " 
						.. SV:T("ticks: ")     .. tempoMarker.ticksBegin .. ", " 
						.. SV:T("tempo: ")     .. tempoMarker.tempo .. "\r"
	end
	if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), "list tempo: " .. list) end
	return list
end

-- Get time Signature track list
function getMidiTimeSignatureTrackList()
	local list = {}
	local value = 0
	local currentTrack = 1
	local trackLabel = SV:T("Track")
	
	for iMidiInfo = 1, #timeSignature do
		local data = timeSignature[iMidiInfo]
		currentTrack = data.track
		table.insert(list, trackLabel 
					.. string.format(formatTrack, currentTrack)
					.. " (" .. ticksToBlicks(data.ticksBegin) .. "/"
					.. "" .. data.ticksBegin .. "/"
					.. ""   .. data.timeBegin .. ")"
					.. ": " .. data.timeSecondBegin .. ": "
					.. " numerator: " .. string.format(formatNumber, data.numerator)
					.. " denominator: " .. string.format(formatNumber, data.denominator)
					.. " metronome: " .. string.format(formatNumber, data.metronome)
					.. " dotted: " .. string.format(formatNumber, data.dotted)
					)		
	end

	SV:showMessageBox(SV:T(SCRIPT_TITLE), 
		"timeSignature count: " .. #timeSignature .. "\r" 
		.. "content:\r" ..  table.concat(list, "\r")
		)
	return list
end

--- Get first note lyrics
function getFirstNotesLyrics(numNotes, groupNotesMain)
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
end

--- Get track list
function getTracksList()
	local list = {}
	local listPos = {}
	local tracks = project:getNumTracks()
	for iTrack = 1, tracks do
		local track = project:getTrack(iTrack)
		local mainGroupRef = track:getGroupReference(1) -- main group
		local groupNotesMain = mainGroupRef:getTarget()
		local numGroups = track:getNumGroups()
		local numNotes = groupNotesMain:getNumNotes()
		local lyrics = getFirstNotesLyrics(numNotes, groupNotesMain)
		local trackName = track:getName()
		
		if (string.find(trackName, midiFileExtension) == nil and numNotes > 0) then
			table.insert(list, trackName
							.. " ("  .. string.format(formatCount, numNotes) .. ") "
							.. lyrics
							)
			table.insert(listPos, iTrack - 1)
		end
		if string.find(trackName, midiFileExtension) ~= nil then
			midiFileNameFromTrack = getCleanFilename(trackName)
		end
	end
	return list, listPos
end

-- Create user input form
function getForm(trackList)	
	local midiTrackList, listTracks, firstTrackWithNotes = getMidiTrackList()
	local trackDefault =  0
	
	listAllTracks = listTracks
	
	local form = {
		title = SV:T(SCRIPT_TITLE),
		message =  SV:T("Select source & target track to create groups,") .. "\r" 
				.. SV:T("Seleted track must match the midi file track!"),
		buttons = "OkCancel",
		widgets = {
			{
				name = "trackMidi", type = "ComboBox",
				label = SV:T("Select midi track source"),
				choices = midiTrackList, 
				default = firstTrackWithNotes
			},
			{
				name = "trackSynthV", type = "ComboBox",
				label = SV:T("Select target track to create groups"),
				choices = trackList, 
				default = trackDefault
			},
			{
				name = "separator", type = "TextArea", label = "", height = 0
			}
		}
	}
	return SV:showCustomDialog(form)
end

-- Get tempo
function getTempo(ticks)
	local newTempo = tempoActive
	
	for iTempo = 1, #tempoMarkers do
		local tempoMarker = tempoMarkers[iTempo]
		if tempoMarker.ticksBegin <= ticks then
			newTempo = tempoMarker.tempo
		end
	end
	return newTempo
end

-- Get marker from ticks
function getMarkerFromTicks(ticks)
	local newMarker = markerTickActive
	
	for iMarker = 1, #markers do
		local markerTemp = markers[iMarker]
		if markerTemp.ticksBegin <= ticks then
			newMarker = marker.ticksBegin
		end
	end
	return newMarker
end

-- Get markers
function getMarkers()
	local result = ""
	for iMarker = 1, #markers do
		local markerTemp = markers[iMarker]
		result = result 
						.. SV:T("iMarker: ") .. iMarker .. ", " 
						.. SV:T("Marker pos: ") .. timeAxis:getSecondsFromBlick(markerTemp.position) .. ", " 
						.. SV:T("Ticks: ")     .. markerTemp.ticksBegin .. ", " 
						-- .. SV:T("Time: ")     .. markerTemp.timeBegin .. ", " 
						.. SV:T("Seconds: ")     .. SecondsToClock(ticksToBlicks(markerTemp.ticksBegin)) .. ", " 
						-- .. SV:T("Marker: ")     .. markerTemp.marker 
						.. "\r"
	end
	SV:showMessageBox(SV:T(SCRIPT_TITLE), "result: " .. result)
end

-- Set marker in seconds
function updateMarkersInSeconds()
	-- local result = ""
	
	for iMarker = 1, #markers do
		local markerTemp = markers[iMarker]
		
		local markerTempSecond = timeAxis:getSecondsFromBlick(ticksToBlicks(markerTemp.ticksBegin))
		
		-- result = result
			-- .. "S: " .. string.format(formatNumber, math.floor(markerTempSecond)) .. ", "
			-- .. "\r"
		
		markers[iMarker].timeBegin = markerTempSecond
	end
	
	-- if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), "result: " .. result) end
	
	return markers
end

-- Get metronome
function getMetronome(ticks)
	local newMetronome = metronomeActive
	
	for iSignature = 1, #timeSignature do
		local infoSignature = timeSignature[iSignature]
		if infoSignature.ticksBegin <= ticks then
			newMetronome = infoSignature.metronome
		end
	end
	return newMetronome
end

-- Get signature
function getSignature(ticks)
	local numerator = signatureActive
	local denominator = denominatorActive
	local metronome = metronomeActive
	local dotted = dottedActive
	
	for iSignature = 1, #timeSignature do
		local infoSignature = timeSignature[iSignature]
		if infoSignature.ticksBegin <= ticks then
			numerator = infoSignature.numerator
			denominator = infoSignature.denominator
			metronome = infoSignature.metronome
			dotted = infoSignature.dotted
		end
	end
	return numerator, denominator, metronome, dotted
end

-- Get group main from track
function getGroupMainFromTrack(trackFilterSynthV)
	local track = project:getTrack(trackFilterSynthV)
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	
	return track, mainGroupRef, groupNotesMain
end

-- Get seconds 
function getSecondsFromTicks(ticksBegin,  ticksPerQuarterNew, dottedActive)
	local seconds = (ticksBegin / (ticksPerQuarterNew * dottedActive) )	
	return seconds
end

-- Create groups from midi markers
function createGroupsFromMarkers(trackFilterMidi, trackFilterSynthV)
	local secondRef = 6
	local result = ""
	local groups = {}
	local groupNotes = {}
	local groupNb = 0
	local iOldMarkerFound = 0

	-- Update makers ticks with time in second
	updateMarkersInSeconds()
	
	if DEBUG then getMarkers() end

	local track, mainGroupRef, groupNotesMain = getGroupMainFromTrack(trackFilterSynthV)

	local numNotes = groupNotesMain:getNumNotes()	
	
	for iNotes = 1, numNotes do
		local note = groupNotesMain:getNote(iNotes)
		local noteSeconds = timeAxis:getSecondsFromBlick(note:getOnset())
		local markerFirst, markerSecond, iMarkerFound = getMarkerRangeFromSecond(noteSeconds)
		
		-- result = result .. "markerFirst: " .. tostring(SecondsToClock(markerFirst))
				-- .. ", markerSecond: " .. tostring(SecondsToClock(markerSecond))
				-- .. ", iMarkerFound: " .. tostring(iMarkerFound)
				-- .. ", noteSeconds: " .. tostring(SecondsToClock(noteSeconds))
				-- .. "\r"
		
		if iMarkerFound > 0  then
			
			if iOldMarkerFound > 0 and iOldMarkerFound < iMarkerFound then
				table.insert(groups, {iOldMarkerFound, groupNotes} )
				groupNotes = {}
			end
			table.insert(groupNotes, {iMarkerFound, note, noteSeconds} )

		end
		iOldMarkerFound = iMarkerFound
	end
	
	if #groupNotes > 0 then
		table.insert(groups, {iOldMarkerFound, groupNotes} )
		groupNotes = {}
	end

	for iGroup = 1, #groups do
		CreateGroup(track, groups[iGroup][2])
	end
	
	-- Remove previous notes
	for iGroup = 1, #groups do
		local gNotes = groups[iGroup][2]
		for igNotes = 1, #gNotes do
			-- Remove previous selected notes
			groupNotesMain:removeNote(gNotes[igNotes][2]:getIndexInParent())
		end
	end
	
	-- if DEBUG then 
		-- SV:showMessageBox(SV:T(SCRIPT_TITLE), "result: " .. string.sub(result, 1, 2000)) 
	-- end
	
	return result
end

-- Get marker range in second
function getMarkerRangeFromSecond(noteSeconds)
	local markerFirst  = 1200
	local markerSecondInit = 9999
	local iMarkerFound = 0
	local endOfMarkers = false
	
	for iMarker = 1, #markers do
		if iMarker + 1 <= #markers then
			markerSecond = markers[iMarker + 1].timeBegin
		else
			markerSecond = markerSecondInit
		end
		if noteSeconds >= markers[iMarker].timeBegin and noteSeconds < markerSecond then
			markerFirst = markers[iMarker].timeBegin
			iMarkerFound = iMarker
			break
		end
	end
	
	return markerFirst, markerSecond, iMarkerFound
end

-- Create group from selected note and starting group from first nearest bar
function CreateGroup(track, groupNotes)
	local maxLengthResult = 30
	local measurePos = 0
	local measureBlick = 0
	-- local noteFirst = selectedNotes[1]	
	local noteFirst = groupNotes[1][2]
	
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
	
	local groupRefMain = track:getGroupReference(1)
	local groupNotesMain = groupRefMain:getTarget()

	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	for iNote = 1, #groupNotes do
		local note = groupNotes[iNote][2]:clone()
		note:setOnset(note:getOnset() - measureBlick)
		noteGroup:addNote(note)
	end

	noteGroup:setName("")
	SV:getProject():addNoteGroup(noteGroup)
	local resultLyrics = renameOneGroup(maxLengthResult, noteGroup)
	
	local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	newGrouptRef:setTimeOffset(measureBlick)
	track:addGroupReference(newGrouptRef)

	return true
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
				
					-- Filter char '+' & '-' & 'br' & ' & .cl & .pau & .sil
					if isTextAccepted(timeAxis, note) then
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

-- Extract data from midi file
function extractMidiData(MidiReader, midiFilename)
	local file = io.open(midiFilename, 'rb')
	local result = {}
	
	-- Protected external call function
	local status, retval = pcall(function() resultTrack = MidiReader.process(file, callback) return resultTrack end)
    if not status then
		io.close(file)
        SV:showMessageBox(SV:T(SCRIPT_TITLE), 'Failed to process MIDI file:' .. midiFilename .. "\r" .. retval)
	else
		io.close(file)
	end
	
	-- Track count in result
	result =  {
		status = status,
		tracksCount = retval
	}
	return result
end

-- Get notes from midi file
function getNotesFromMidiFile(MidiReader, midiFilename, trackList, trackPos)
	local project = SV:getProject()
	local timeSecondEndPhrase = ""
	local lyricsIndice = 0
	local endTrack = false
	local trackFilterSynthV = 1
	local trackFilterMidi = 1
	local done = false
	
	if not checkExternalFile(midiFilename) then 
		SV:showMessageBox(SV:T(SCRIPT_TITLE), 'Failed to open MIDI from ' .. midiFilename)
		return done
	end
	
	local resultExtractMidi = extractMidiData(MidiReader, midiFilename)
	local resultExtractMidiStatus = resultExtractMidi.status
	local tracksCount = resultExtractMidi.tracksCount
	
	if not resultExtractMidiStatus  then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found during processing the MIDI file!"))
		return done
	end
	
	-- Result infos
	if #notesTable > 0 then
		-- Message result
		local resultMessage = ""
		
		if #markers == 0 then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No markers found!"))
		end 
		
		-- if string.len(tracksCount) > 0 then
			-- if DEBUG then resultMessage = resultMessage .. SV:T("tracks count:") 
				-- .. " " .. tracksCount .. "\r"
			-- end
		-- end
			
		local userInput = getForm(trackList)
		
		if userInput.status then
			trackFilterSynthV = trackPos[userInput.answers.trackSynthV + 1] + 1
			trackFilterMidi = listAllTracks[userInput.answers.trackMidi + 1]
			-- if DEBUG then getTempoList() end
			-- if DEBUG then getMidiTimeSignatureTrackList(trackFilterMidi) end
	
			-- check track contents
			local track, mainGroupRef, groupNotesMain = getGroupMainFromTrack(trackFilterSynthV)
			local numNotes = groupNotesMain:getNumNotes()
			if numnotes == 0 then
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes found in tracks!"))
				return done
			end
		
			-- Create groups form markers
			local result = createGroupsFromMarkers(trackFilterMidi, trackFilterSynthV)
			done = true
		end

		-- if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage ) end
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found!"))
	end
	
	return done
end

-- getCleanFilename
function getCleanFilename(file)
	local filename = file
	if string.len(filename) > 0 then
		if string.find(filename, '"') ~= nil then
			filename = filename:gsub('"', '')
		end
	end
	return filename
end

-- Main procedure
function main()
	local contentInfo = SV:getHostClipboard()
	local filenameInit = DEFAULT_FILE_PATH

	-- Get file name from last clipboard
	if string.find(contentInfo, midiFileExtension) ~= nil then
		filenameInit = getCleanFilename(contentInfo)
	end
	
	local trackList, trackPos = getTracksList()
	
	-- Get file name with path from a track name in SynthV
	if string.len(midiFileNameFromTrack) > 0 then
		filenameInit = midiFileNameFromTrack
	end
	
	local midiFilename = SV:showInputBox(SV:T(SCRIPT_TITLE), 'Enter the full path to your MIDI file.', filenameInit)
	
	if string.len(midiFilename) > 0 then
		local filename = getCleanFilename(midiFilename)
		getNotesFromMidiFile(getMidiReader(), filename, trackList, trackPos)
	end

	SV:finish()
end

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
			result = result .. assert(stream:read(count), "missing value")
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
			local byte = assert(stream:read(1), "incomplete or missing variable length quantity"):byte()
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
		-- [0x06] = makeForwarder("marker"),
		[0x06] = function(data, callback)
			callback("marker", data)
		end,
		[0x07] = makeForwarder("cuePoint"),
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
			callback("keySignature", math.abs(count), count < 0 and "flat" or count > 0 and "sharp" or "C", minor == 0 and "major" or "minor")
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
				assert(not format, "only a single header chunk is allowed")
				format, tracks = readHeader(stream, callback, chunkLength)
				assert(tracks == 1 or format ~= 0, "midi format 0 can only contain a single track")
				assert(not onlyTrack or onlyTrack >= 1 and onlyTrack <= tracks, "track out of range")
				if onlyHeader then
					break
				end
			elseif chunkType == "MTrk" then
				track = track + 1
				assert(format, "no header chunk before the first track chunk")
				assert(track <= tracks, "found more tracks than specified in the header")
				assert(track == 1 or format ~= 0, "midi format 0 can only contain a single track")

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
				callback("unknownChunk", chunkType, data)
			end
		end

		if not onlyHeader and not onlyTrack then
			assert(track == tracks, "found less tracks than specified in the header")
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