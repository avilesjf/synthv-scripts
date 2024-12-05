local SCRIPT_TITLE = 'Extract pitchbend from midi file V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ExtractPitchbendFromMidi.lua

This script will extract the pitchbend variations coming a midi file
and copy them to pitch deviation SynthV parameter.

Midi file path:
To avoid copy/paste the midi file path each time running this script:
Midi file path is retrieved from: Clipboard or trackname

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

local ticks = 0

-- Times infos
local tempoActive = 120
local metronomeActive = 24
local signatureActive = 4 -- numerator
local denominatorActive = 4
local dottedActive = 8

local notesTable = {}
local tempoMarkers = {}
local midiTrackNames = {}
local controllersTable = {}
local pitchbendTable = {}
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

-- Store pitch data from midi file
function recordPitchDeltaTimes(timeBegin, ticks, timeSecond, channel, value, lsb, msb, msb1, msb2)
    table.insert(pitchbendTable, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
		ticksBegin  =  ticks,
		timeBegin  =  timeBegin,
		timeSecondBegin = timeSecond,
		channel = channel,
		value = value,
		lsb = lsb,
		msb = msb
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

-- Get pitchbend from midi file
function handlers.pitch(channel, value, lsb, msb, msb1, msb2)
	local timeSecond = 0
	if ticks > 0 then
		local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
		timeSecond = SecondsToClock(secNotePos)
	end
	recordPitchDeltaTimes(DELTA_TIME, ticks, timeSecond, channel, value, lsb, msb)
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

-- Get lyrics from midi file
function handlers.lyric(data)
	CURRENT_LYRIC = data
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

-- Get sequencer or track name from midi file
function handlers.sequencerOrTrackName(data)
    table.insert(midiTrackNames, {
		track = CURRENT_TRACK,
        trackName = data
    })
end

-- Convert ticks to Blicks
function ticksToBlicks(ticks)
    return (ticks / ticksPerQuarter) * blicksPerQuarter
end

-- Convert blicks to ticks
function blicksToTicks(blicks)
	return (blicks / blicksPerQuarter) * ticksPerQuarter
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
				addTrackList(list, listTracks, previousTrack, trackNotesCount, positionTrack)
				
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
	addTrackList(list, listTracks, previousTrack, trackNotesCount, positionTrack)
	
	-- if DEBUG then SV:showMessageBox("", "firstTrackWithNotes: " .. firstTrackWithNotes) end
	
	return list, listTracks, firstTrackWithNotes
end

-- Add track list
function addTrackList(list, listTracks, iTrack, trackNotesCount, positionTrack)
	local trackLabel = SV:T("Track")
	
	table.insert(list, trackLabel 
				.. string.format(formatTrack, iTrack)
				.. " '" .. getTrackName(iTrack) .. "'"
				.. " (" .. string.format(formatCount, trackNotesCount) .. ")")
	table.insert(listTracks,  iTrack)
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
	local tracks = project:getNumTracks()
	for iTrack = 1, tracks do
		local track = project:getTrack(iTrack)
		local mainGroupRef = track:getGroupReference(1) -- main group
		local groupNotesMain = mainGroupRef:getTarget()
		
		local numNotes = groupNotesMain:getNumNotes()
		local lyrics = getFirstNotesLyrics(numNotes, groupNotesMain)
		local trackName = track:getName()
		if (string.find(trackName, midiFileExtension, 1, true) == nil and numNotes > 0) then
			table.insert(list, trackName
								.. " (" .. string.format(formatCount, numNotes) .. ")"
								.. lyrics
								)
		end
		if string.find(trackName, midiFileExtension, 1, true) ~= nil then
			midiFileNameFromTrack = getCleanFilename(trackName)
		end
	end
	return list
end

-- Create user input form
function getForm(midiTrackList, trackList, firstTrackWithNotes)
	local reduceGainDefaultValue = 0
	local reduceGainMinValue =  0
	local reduceGainMaxValue =  80
	local reduceGainInterval =  10
	local trackDefault =  0
	
	local form = {
		title = SV:T(SCRIPT_TITLE),
		message =  SV:T("Select source & target track to update deviation,") .. "\r" 
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
				label = SV:T("Select target track to update pitch deviation"),
				choices = trackList, 
				default = trackDefault
			},
			-- {
				-- name = "reduceGain", type = "Slider",
				-- label = SV:T("Reduce gain %"),
				-- format = "%3.0f",
				-- minValue = reduceGainMinValue, 
				-- maxValue = reduceGainMaxValue, 
				-- interval = reduceGainInterval, 
				-- default = reduceGainDefaultValue
			-- },			
			{
				name = "separator", type = "TextArea", label = "", height = 0
			}
		}
	}
	return SV:showCustomDialog(form)
end

-- Check tracks
function checkTrack(trackFilterSynthV)
	local groupNotesMain = getGroupMainFromTrack(trackFilterSynthV)
	local numNotes = groupNotesMain:getNumNotes()
	return numNotes
end

-- Set last parameter pitch deviation in track
function setLastParameterPitchDeviationInTrack(trackFilterSynthV, lastValue)
	local groupNotesMain = getGroupMainFromTrack(trackFilterSynthV)
	local numNotes = groupNotesMain:getNumNotes()
	local lastNote = groupNotesMain:getNote(numNotes) -- last note

	local pitchDelta = groupNotesMain:getParameter("pitchDelta")
	
	pitchDelta:add(lastNote:getEnd(), lastValue)
	-- Decay after applying last pitchDelta value
	local time = lastNote:getEnd() + timeAxis:getBlickFromSeconds(2)
	pitchDelta:add(time, 0)
	
	return lastNote
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

-- Get pitch Deviation from track
function getPitchDeviationFromTrack(trackFilterSynthV)
	local groupNotesMain = getGroupMainFromTrack(trackFilterSynthV)
	local pitchDelta = groupNotesMain:getParameter("pitchDelta")
	
	return pitchDelta
end

-- Get group main from track
function getGroupMainFromTrack(trackFilterSynthV)
	local track = project:getTrack(trackFilterSynthV)
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	
	return groupNotesMain
end

-- Set pitch deviation for tracks
function setPitchDeviationOnTracks(trackFilterMidi, trackFilterSynthV, reduceGain)
	local lyricContent = ""
	local currentTrack = 1
	local previousTrack = 1
	local iSynthVNote = 0
	local trackNotesCount = 0
	local lyrics = ""
	local result = ""
	local pitchDeviation = getPitchDeviationFromTrack(trackFilterSynthV)
	pitchDeviation:removeAll()
	
	-- Pitchbend from midi
	local currentTrack = 1
	local pitchInfosCount = 0
		
	for iMidiInfo = 1, #pitchbendTable do
		local pitchData = pitchbendTable[iMidiInfo]
		currentTrack = pitchData.track
		
		if currentTrack == trackFilterMidi then
			-- get Blicks with new tempo
			local timeInfo = ticksToBlicks(pitchData.ticksBegin)
			
			-- midi values => -16 0 +16
			-- midi value base pitchbend = 15
			-- -100 to +100 => -200 to +200 (eq. 2 semitones)
			-- 200/16 = 12
			local midiPitchBase = 15
			local coef = 12
			local newValue = (pitchData.value - midiPitchBase) * coef
			-- useless reduceGain, pitch relates to 2 semitones only, default value is: 0
			newValue = newValue - (newValue * (reduceGain/100))
				
			-- Get track infos for pitch deviation
			pitchDeviation:add(timeInfo, newValue) -- Add pitchdelta
			pitchInfosCount = pitchInfosCount + 1
			
		end
		
	end	
	
	-- Set last parameter pitch deviation to default value  (0)
	local lastNote = setLastParameterPitchDeviationInTrack(trackFilterSynthV, newValue)

	-- if DEBUG then 
		-- SV:showMessageBox(SV:T(SCRIPT_TITLE), "result: " .. string.sub(result, 1, 1000))
	-- end
	
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
function getNotesFromMidiFile(MidiReader, midiFilename, trackList)
	local project = SV:getProject()
	local timeSecondEndPhrase = ""
	local lyricsIndice = 0
	local endTrack = false
	local trackFilterSynthV = 1
	local trackFilterMidi = 1
	local reduceGain = 0
	
	if not checkExternalFile(midiFilename) then 
		SV:showMessageBox(SV:T(SCRIPT_TITLE), 'Failed to open MIDI from ' .. midiFilename)
		return false
	end
	
	local resultExtractMidi = extractMidiData(MidiReader, midiFilename)
	local resultExtractMidiStatus = resultExtractMidi.status
	local tracksCount = resultExtractMidi.tracksCount
	
	if not resultExtractMidiStatus  then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found during processing the MIDI file!"))
		return false
	end
	
	-- Result infos
	if #notesTable > 0 then
		-- Message result
		local resultMessage = ""
		
		if string.len(tracksCount) > 0 then
			resultMessage = resultMessage .. SV:T("tracks count:") .. " " .. tracksCount .. "\r"
		end
		
		local midiTrackList, listTracks, firstTrackWithNotes = getMidiTrackList()

		local userInput = getForm(midiTrackList, trackList, firstTrackWithNotes)
		
		if userInput.status then
			
			trackFilterMidi = listTracks[userInput.answers.trackMidi + 1]
			trackFilterSynthV = userInput.answers.trackSynthV + 1

			-- useless reduceGain, pitch relates to 2 semitones only
			-- reduceGain = userInput.answers.reduceGain
			
			-- check track contents
			local numnotes = checkTrack(trackFilterSynthV)
			if numnotes == 0 then
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes found in tracks!"))
				return false
			end
		
			-- Set pitch deviation from midi
			local result = setPitchDeviationOnTracks(trackFilterMidi, trackFilterSynthV, reduceGain)
		end

		--if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage ) end
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found!"))
	end
	
	return true
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
	if string.find(contentInfo, midiFileExtension, 1, true) ~= nil then
		filenameInit = getCleanFilename(contentInfo)
	end
	
	local trackList = getTracksList()
	
	-- Get file name with path from a track name in SynthV
	if string.len(midiFileNameFromTrack) > 0 then
		filenameInit = midiFileNameFromTrack
	end
	
	local midiFilename = SV:showInputBox(SV:T(SCRIPT_TITLE), 'Enter the full path to your MIDI file.', filenameInit)
	
	if string.len(midiFilename) > 0 then
		local filename = getCleanFilename(midiFilename)
		getNotesFromMidiFile(getMidiReader(), filename, trackList)
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
			-- callback("pitch", channel, (lsb | msb << 7) / 0x2000 - 1)
			callback("pitch", channel, (lsb | msb << 7) / 0x200 - 1, lsb, msb)
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
		-- [0x07] = makeForwarder("cuePoint"),
		[0x07] = function(data, callback)
			callback("cuePoint", data)
		end,
		
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