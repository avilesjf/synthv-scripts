local SCRIPT_TITLE = 'Extract velocity from midi file V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ExtractVelocityFromMidi.lua

This script will extract the velocity notes coming a midi file
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

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%06.3f", 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

local ticksPerQuarter = nil
local blicksPerQuarter = 705600000
local DEBUG = false

local DEFAULT_FILE_PATH = "D:\\Cubase Projects\\"
if DEBUG then 
	DEFAULT_FILE_PATH = "D:\\Cubase Projects\\I can't hear you\\i can't hear you2.mid" 
end

local ticks = 0
local tempoMarkers = {}
local notesTable = {}

local CURRENT_LYRIC = ""
local INDEX_NOTE = 0
local CURRENT_TRACK = 0
local DELTA_TIME = 0
local project = SV:getProject()
local timeAxis = project:getTimeAxis()
local formatCount = "Count: %04d"
local formatTrack = "%2d"
local handlers = {}

-- Store data from midi file
function recordDeltaTimes(timeBegin, timeSecond, channel, key, velocity)
    table.insert(notesTable, {
        index = INDEX_NOTE,
		track = CURRENT_TRACK,
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
	
	local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
	local timeSecond = SecondsToClock(secNotePos)
	recordDeltaTimes(DELTA_TIME, timeSecond, channel, key, velocity)
end

-- Get noteOff from midi file
function handlers.noteOff(channel, key, velocity)
	notesTable[INDEX_NOTE].timeEnd = DELTA_TIME
	
	local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
	local timeSecond = SecondsToClock(secNotePos)
	notesTable[INDEX_NOTE].timeSecondEnd = timeSecond
end

-- Get lyrics from midi file
function handlers.lyric(data)
	CURRENT_LYRIC = data
end

-- Get track number from midi file
function handlers.track(track) 
	CURRENT_TRACK = track
end

-- Get tempo midi file data
function handlers.setTempo(tempo)
    table.insert(tempoMarkers, {
        position = ticksToBlicks(ticks),
        tempo = tempo
    })
end

-- Convert ticks to Blicks
function ticksToBlicks(ticks)
    return ticks / ticksPerQuarter * blicksPerQuarter
end

-- Call back to dispatch content data from midi file
local function callback(name, ...)
    local handler = handlers[name]
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

-- Get Midi track list
function getMidiTrackList()
	local list = {}
	local trackNotesCount = 0
	local lyrics = ""
	local velocity = 0
	local currentTrack = 1
	local previousTrack = 1
	local timeSecondBegin = 0
	local trackLabel = SV:T("Track")
	
	for iMidiNote = 1, #notesTable do
		local note = notesTable[iMidiNote]
		currentTrack = note.track
		
		if previousTrack ~= currentTrack then
			if trackNotesCount == 0 then
				table.insert(list, trackLabel 
							.. string.format(formatTrack, previousTrack) 
							.. " (" .. string.format(formatCount, trackNotesCount) .. ")" )
			else
				table.insert(list, trackLabel 
							.. string.format(formatTrack, previousTrack)
							.. " (" .. string.format(formatCount, trackNotesCount) .. ")"
							.. " : " .. string.sub(lyrics, 1, 15))
			end
			trackNotesCount = 0
			lyrics = ""
		end
		
		if lyrics == "" then
			timeSecondBegin = note.timeSecondBegin
			velocity = note.velocity
		end
		lyrics = lyrics .. note.lyric .. " "
		
		previousTrack = currentTrack
		trackNotesCount = trackNotesCount + 1
	end
	
	table.insert(list, trackLabel 
				.. string.format(formatTrack, previousTrack ) 
				.. " (" .. string.format(formatCount, trackNotesCount)  .. ")"
				.. " : " .. string.sub(lyrics, 1, 10) )	
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
		
		table.insert(list, track:getName() 
							.. " (" .. string.format(formatCount, numNotes) .. ")"
							.. lyrics
							)
	end
	return list
end

-- Create user input form
function getForm()
	local trackList = getTracksList()
	local midiTrackList = getMidiTrackList()
	local velocityGainDefaultValue = 10
	local velocityGainMinValue =  0
	local velocityGainMaxValue =  20
	local velocityGainInterval =  5
	local trackDefault =  0

	local form = {
		title = SV:T(SCRIPT_TITLE),
		message =  SV:T("Select source & target track to update loudness,") .. "\r" 
				.. SV:T("|Count| => Notes count found into a midi track,") .. "\r" 
				.. SV:T("Seleted track must match the midi file track!"),
		buttons = "OkCancel",
		widgets = {
			{
				name = "trackMidi", type = "ComboBox",
				label = SV:T("Select midi track source"),
				choices = midiTrackList, 
				default = trackDefault
			},
			{
				name = "trackSynthV", type = "ComboBox",
				label = SV:T("Select target track to update loudness"),
				choices = trackList, 
				default = trackDefault
			},
			{
				name = "velocityGain", type = "Slider",
				label = SV:T("Velocity gain"),
				format = "%3.0f",
				minValue = velocityGainMinValue, 
				maxValue = velocityGainMaxValue, 
				interval = velocityGainInterval, 
				default = velocityGainDefaultValue
			},			
			{
				name = "reduceGain", type = "CheckBox", text = SV:T("Reduce loudness between separate notes"),
				default = false
			},
			{
				name = "separator", type = "TextArea", label = "", height = 0
			}
		}
	}
	return SV:showCustomDialog(form)
end
	
-- Check tracks
function checkTrack(trackFilterSynthV)
    local track = project:getTrack(trackFilterSynthV)
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	local numGroups = track:getNumGroups()
	local numNotes = groupNotesMain:getNumNotes()

	return numNotes
end

-- Set first parameter Loudness in track
function setFirstParameterLoudnessInTrack(trackFilterSynthV)
    local track = project:getTrack(trackFilterSynthV)
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	local numGroups = track:getNumGroups()
	local numNotes = groupNotesMain:getNumNotes()
	local firstNote = groupNotesMain:getNote(1) -- First note

	local loudness = groupNotesMain:getParameter("loudness")
	local time1 = firstNote:getOnset()
	
	-- Decay before applying first loudness value in next steps
	local newTimeOffset = firstNote:getOnset() - timeAxis:getBlickFromSeconds(0.1)
	if newTimeOffset <  0 then newTimeOffset = 0 end  -- Negative is not possible
	
	loudness:removeAll()
	loudness:add(newTimeOffset, 0)
	
	return firstNote
end

-- Set last parameter Loudness in track
function setLastParameterLoudnessInTrack(trackFilterSynthV)
    local track = project:getTrack(trackFilterSynthV)
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	local numGroups = track:getNumGroups()
	local numNotes = groupNotesMain:getNumNotes()
	local lastNote = groupNotesMain:getNote(numNotes) -- last note

	local loudness = groupNotesMain:getParameter("loudness")
	
	-- Decay after applying last loudness value
	local time = lastNote:getEnd() + timeAxis:getBlickFromSeconds(0.1)
	loudness:add(time, 0)
	
	return lastNote
end

-- Set volume notes for each tracks
function setLoudnessOnTracks(trackFilterMidi, trackFilterSynthV, velocityGain, reduceGain)
	local lyricContent = ""
	local currentTrack = 1
	local previousTrack = 1
	local lastTrack = 0
	local iSynthVNote = 0
	local trackNotesCount = 0
	local lyrics = ""
	
	local result = ""

	for iMidiNote = 1, #notesTable do
		local midiNote = notesTable[iMidiNote]
		currentTrack = midiNote.track
		
		if previousTrack ~= currentTrack then
			result = result .. "currentTrack: " .. previousTrack
				.. "/Midi track: " .. trackFilterMidi
				.. "/SynthV track:" .. trackFilterSynthV
				.. ", trackNotesCount : " .. trackNotesCount 
				.. ", lyric: " .. lyrics .. "\r"
			trackNotesCount = 0
			lyrics = ""
		end
		lyrics = midiNote.lyric
		
		if currentTrack == trackFilterMidi then
			iSynthVNote = iSynthVNote + 1
			
			if previousTrack ~= currentTrack then
				result = result .. "currentTrack: " .. previousTrack .. ", iSynthVNote: " .. iSynthVNote .. "\r"
			end
			
			local track = project:getTrack(trackFilterSynthV)
			local numGroups = track:getNumGroups()
			local mainGroupRef = track:getGroupReference(1) -- main group
			local groupNotesMain = mainGroupRef:getTarget()
			local numNotes = groupNotesMain:getNumNotes()
			local loudness = groupNotesMain:getParameter("loudness")
			
			if previousTrack ~= currentTrack then
				result = result .. "numGroups: " .. numGroups .. "\r"
			end

			local noteSynthV = groupNotesMain:getNote(iSynthVNote)
			if noteSynthV ~= nil then
				local midiNoteVelocity = midiNote.velocity
				if midiNoteVelocity == nil then
					midiNoteVelocity = 0
				end
				
				-- ticksToBlicks(midiNote.timeBegin)
				local timeNote = noteSynthV:getOnset()
				loudness:add(timeNote, midiNoteVelocity * velocityGain)
				
				if iSynthVNote + 1 <= numNotes then
					local noteNextSynthV = groupNotesMain:getNote(iSynthVNote + 1)
					if noteNextSynthV ~= nil then
						local timeNoteEnd = noteSynthV:getEnd()
						local timeNoteNext = noteNextSynthV:getOnset()
						
						-- Decay after applying last loudness value
						local timeEnd = noteSynthV:getEnd() + timeAxis:getBlickFromSeconds(0.01)
						if timeNoteNext - timeNoteEnd > 10000 then
							loudness:add(timeEnd, 0)
						end
						
						if reduceGain then
							-- Reduce ending value if notes are nearest
							if timeNoteNext - timeNoteEnd > 100 then
								local reduceVelocity = (midiNoteVelocity / 2) * velocityGain
								loudness:add(timeEnd, reduceVelocity)
							end
						end
					end
				end
			end
		end
		previousTrack = currentTrack
		trackNotesCount = trackNotesCount + 1
	end
	
	result = result .. "currentTrack: " .. currentTrack .. "/Midi track: " 
		.. trackFilterMidi .. "/SynthV track: " .. trackFilterSynthV 
		.. ", trackNotesCount : " .. trackNotesCount 
		.. ", lyric: " .. lyrics .. "\r"

	-- if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), "result: " .. result) end
	return result
end

-- Get fist note position in current track
function getFirstNoteInTrack(trackFilter)
    local track = project:getTrack(trackFilter)
	local mainGroupRef = track:getGroupReference(1)
	local groupNotesMain = mainGroupRef:getTarget()
	local numGroups = track:getNumGroups()
	local numNotes = groupNotesMain:getNumNotes() 
	local firstNote = groupNotesMain:getNote(1)
	local secondNote = groupNotesMain:getNote(2)
	local loudness = groupNotesMain:getParameter("loudness")
	
	local time1 = firstNote:getOnset()
	local time2 = secondNote:getOnset()
	
	SV:showMessageBox(SV:T(SCRIPT_TITLE), "numGroups: " .. numGroups .. ", numNotes: " 
		.. numNotes .. ", firstNote: " .. firstNote:getLyrics() .. ", time1:" .. tostring(time1))
	
	return note
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
function getNotesFromMidiFile(MidiReader, midiFilename)
	local project = SV:getProject()
	local timeSecondEndPhrase = ""
	local lyricsIndice = 0
	local endTrack = false
	local trackFilterSynthV = 1
	local trackFilterMidi = 1
	local velocityGain = 0
	local reduceGain = false
	
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
		-- local resultMessage = SV:T("Lyrics placed on clipboard!") .. "\r"
		local resultMessage = ""
		
		if string.len(tracksCount) > 0 then
			resultMessage = resultMessage .. SV:T("tracks:") .. " " .. tracksCount .. "\r"
		end
		
		for i = 1, #tempoMarkers do
			local tempoMarker = tempoMarkers[i]
			resultMessage = resultMessage .. SV:T("Tempo pos:") .. " " .. tostring(tempoMarker.position) .. ", " .. SV:T("tempo:") .. " " .. tostring(tempoMarker.tempo) .. "\r"
		end
			
		local userInput = getForm()
		
		if userInput.status then				
			trackFilterSynthV = userInput.answers.trackSynthV + 1
			trackFilterMidi = userInput.answers.trackMidi + 1

			--velocityGain = math.floor(userInput.answers.velocityGain)
			velocityGain = userInput.answers.velocityGain
			reduceGain = userInput.answers.reduceGain
			
			-- check track contents
			local numnotes = checkTrack(trackFilterSynthV)
			if numnotes == 0 then
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes found in tracks!"))
				return false
			end
		
			setVelocityToSynthV(trackFilterMidi, trackFilterSynthV, velocityGain, reduceGain)
		end

		--if DEBUG then SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage ) end
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found!"))
	end
	
	return true
end

-- Set velocity from midi file to SynthV
function setVelocityToSynthV(trackFilterMidi, trackFilterSynthV, velocityGain, reduceGain)

	-- Set first parameter loudness default value (0)
	local firstNote = setFirstParameterLoudnessInTrack(trackFilterSynthV)

	-- Set loudness from midi velocity
	local result = setLoudnessOnTracks(trackFilterMidi, trackFilterSynthV, velocityGain, reduceGain)
	
	-- set last parameter loudness to default value  (0)
	local lastNote = setLastParameterLoudnessInTrack(trackFilterSynthV)	
end

-- Main procedure
function main()

	local midiFilename = SV:showInputBox(SV:T(SCRIPT_TITLE), 'Enter the full path to your MIDI file.', DEFAULT_FILE_PATH)

	getNotesFromMidiFile(getMidiReader(), midiFilename)

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
	  [0x06] = makeForwarder("marker"),
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