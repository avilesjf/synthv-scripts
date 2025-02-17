local SCRIPT_TITLE = 'Lyrics from midi to Clipboard V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ExtractLyricsFromMidi.lua

Copy into clipboard, all lyrics for video subtitles (.SRT) format
all tracks from an external midi file.

This will extract the lyrics from a midi file
separate all not linked notes,
and generate de subtile file format (.SRT) with lyrics found.

Example :
1
00:00:06,873 --> 00:00:09,709
Lyrics of the song

External Mifi library is comming from:
https://github.com/Possseidon/lua-midi/blob/main/lib/midi.lua

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Nothing found during processing the MIDI file!", "Nothing found during processing the MIDI file!"},
			{"Lyrics placed on clipboard!", "Lyrics placed on clipboard!"},
			{"tracks:", "tracks:"},
			{"Tempo pos:", "Tempo pos:"},
			{"tempo:", "tempo:"},
			{"Track:", "Track:"},
			{"Lyric length:", "Lyric length:"},
			{"Track selected (with max length lyrics):", "Track selected (with max length lyrics):"},
			{"Nothing found!", "Nothing found!"},
			{"Enter the full path to your MIDI file", "Enter the full path to your MIDI file"},
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

-- Get string format from seconds
function SecondsToClock(timestamp)
	return string.format("%02d:%02d:%06.3f", 
	  math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

local ticksPerQuarter = nil
local blicksPerQuarter = 705600000

local ticks = 0
local tempoMarkers = {}
local lyricsTable = {}

local DEBUG = true
local CURRENT_LYRIC = ""
local INDEX_NOTE = 0
local CURRENT_TRACK = 0
local PREVIOUS_TRACK = 0
local DELTA_TIME = 0
local project = SV:getProject()
local timeAxis = project:getTimeAxis()

local handlers = {}

-- Store data from midi file
function recordDeltaTimes(timeBegin, timeSecond, channel, key, velocity)
    table.insert(lyricsTable, {
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
	lyricsTable[INDEX_NOTE].timeEnd = DELTA_TIME
	
	local secNotePos = timeAxis:getSecondsFromBlick(ticksToBlicks(ticks))
	local timeSecond = SecondsToClock(secNotePos)
	lyricsTable[INDEX_NOTE].timeSecondEnd = timeSecond
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

-- Check existing external file
function checkExternalFile(filename)
    local filetoOpen = io.open(filename, "r")	
	if filetoOpen ~= nil then io.close(filetoOpen) end
    return filetoOpen
end

-- Format result string to debug
function debugLyricsData(lyrics)
	local resultLyrics = ""
	
	local timeBegin = 0
	if lyrics.timeEnd ~= nil then timeBegin = lyrics.timeBegin end
	local timeEnd = 0
	if lyrics.timeEnd ~= nil then timeEnd = lyrics.timeEnd end
	local channel = 0
	if lyrics.channel ~= nil then channel = lyrics.channel end
	local key = 0
	if lyrics.key ~= nil then key = lyrics.key end
	local velocity = 0
	if lyrics.velocity ~= nil then velocity = lyrics.velocity end
	local timeSecondEnd = "-- Empty  --"
	if lyrics.timeSecondEnd ~= nil then timeSecondEnd = lyrics.timeSecondEnd end

	resultLyrics = resultLyrics .. "Pos: " .. string.format("%04d", lyrics.index)
	.. ", track: " .. string.format("%03d", lyrics.track)
	.. ", begin: " .. string.format("%06d", timeBegin)
	.. ", end: " .. string.format("%05d", timeEnd)
	.. ", timeSecBegin: " .. lyrics.timeSecondBegin
	.. ", timeSecEnd: " .. timeSecondEnd
	.. ", channel: " .. string.format("%05d", channel)
	.. ", key: " .. string.format("%05d", key)
	.. ", velocity: " .. string.format("%05d", velocity)
	.. ", lyric: " .. lyrics.lyric .. "\r"
	return resultLyrics
end 

-- Check tracks with lyrics
function checkTracksWithLyrics(lyricsTable)
	local lyricContent = ""
	local currentTrack = 0
	local lastTrack = 0
	local lastLyricSizeLength = 0
	local lyricSizeLength = 0
	local lyricsExistingTracks = {}
	local Track_Filter = 1
	local result = {}
	
	for i = 1, #lyricsTable do
		local lyrics = lyricsTable[i]
		currentTrack = lyrics.track
		
		-- Next track
		if string.len(lyricContent) > 0 and currentTrack > lastTrack then
			if lastTrack > 0 then 
				table.insert(lyricsExistingTracks, {
					index = i,
					track = lastTrack,
					lyric_length = string.len(lyricContent),
					lyric = lyricContent
				})
				
				lyricSizeLength = string.len(lyricContent)					
				if lyricSizeLength > lastLyricSizeLength then
					Track_Filter = lastTrack
					lastLyricSizeLength = lyricSizeLength
				end
				lyricContent = lyrics.lyric
			end				
		else 
			if string.len(lyrics.lyric) > 0 and lyrics.lyric ~= "+" and lyrics.lyric ~= "-" then
				lyricContent = lyricContent .. lyrics.lyric
			end
		end
		lastTrack = currentTrack
	end
	
	result = {
		trackFilter = Track_Filter,
		lyrics = lyricsExistingTracks
	}
	
	return result

end

-- Store lyrics strings
function storeLyricsInString(lyricsTable, Track_Filter)
	local result = {}
	local resultLyrics = ""
	local lyricsSRT = ""
	local lyricInfoLast = ""
	local lyricsIndice = 0
	
	for i = 1, #lyricsTable do
		local lyrics = lyricsTable[i]
		--if DEBUG then resultLyrics = debugLyricsData(lyrics) end
		
		-- limit to one track 
		if lyrics.track == Track_Filter then
			local lyricInfo = lyrics.lyric
			
			-- Filter special chars
			if lyricInfo ~= "+" and lyricInfo ~= "-" then
				if lyricInfoLast ~= nil and string.len(lyricInfoLast) > 0 then
					lyricsSRT = lyricsSRT .. " --> " .. timeSecondEndPhrase .. "\r"
					.. lyricInfoLast .. "\r\r"
					resultLyrics = resultLyrics .. lyricInfoLast .. "\r"
				end
				lyricsIndice = lyricsIndice + 1
				timeSecondEndPhrase = ""
				lyricInfoLast = ""
				lyricsSRT = lyricsSRT .. tostring(lyricsIndice) .. "\r"  .. lyrics.timeSecondBegin
				lyricInfoLast = lyricInfo
				timeSecondEndPhrase = lyrics.timeSecondEnd				
			else
				timeSecondEndPhrase = lyrics.timeSecondEnd
			end 
		else
			if not endTrack then
				endTrack = true
				if string.len(lyricInfoLast) > 0 then				
					lyricsSRT = lyricsSRT .. " --> " .. timeSecondEndPhrase .. "\r"
					.. lyricInfoLast .. "\r\r"				
				end
			end
		end
	end

	result = {
		lyricsSRT = lyricsSRT,
		lyrics = resultLyrics
	}
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

-- Get lyrics from midi file
function getLyrics(MidiReader, midiFilename)
	
	local timeSecondEndPhrase = ""
	local lyricsIndice = 0
	local endTrack = false
	local trackFilter = 1
	local maxLyricsCount = 0
	local lyricsExistingTracks = {}
	
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
	if #lyricsTable > 0 then
		-- Message result
		local resultMessage = SV:T("Lyrics placed on clipboard!") .. "\r"
		
		if string.len(tracksCount) > 0 then
			resultMessage = resultMessage .. SV:T("tracks:") .. " " .. tracksCount .. "\r"
		end
		
		for i = 1, #tempoMarkers do
			local tempoMarker = tempoMarkers[i]
			resultMessage = resultMessage .. SV:T("Tempo pos:") .. " " .. tostring(tempoMarker.position) .. ", " .. SV:T("tempo:") .. " " .. tostring(tempoMarker.tempo) .. "\r"
		end
		
		local resultCheck = checkTracksWithLyrics(lyricsTable)
		trackFilter = resultCheck.trackFilter
		lyricsExistingTracks = resultCheck.lyrics
		
		local resultStoreLyrics = storeLyricsInString(lyricsTable, trackFilter)
		local lyricsSRT = resultStoreLyrics.lyricsSRT
		local resultLyrics = resultStoreLyrics.lyrics
		
		-- to Clipboard
		if DEBUG then
			SV:setHostClipboard(resultLyrics)
		else
			SV:setHostClipboard(lyricsSRT)
		end
		
		for i = 1, #lyricsExistingTracks do
			local lyricsExist = lyricsExistingTracks[i]
			resultMessage = resultMessage 
			.. SV:T("Track:") .. tostring(lyricsExist.track) .. " "
			.. SV:T("Lyric length:") ..  tostring(lyricsExist.lyric_length) .. " "
			.. string.sub(lyricsExist.lyric, 1, 30) .. "\r"
		end
		resultMessage = resultMessage .. SV:T("Track selected (with max length lyrics):") .. " " .. tostring(trackFilter) .. "\r"

		SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage )
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Nothing found!"))
	end
	
	return true
end

-- Main procedure
function main()
	local DEFAULT_FILE_PATH = "D:\\Cubase Projects\\"
	-- !!! JFA debug only !!!
	if DEBUG then DEFAULT_FILE_PATH = "D:\\Cubase Projects\\I can't hear you\\i can't hear you.mid" end
	
	local midiFilename = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Enter the full path to your MIDI file"), DEFAULT_FILE_PATH)

	getLyrics(getMidiReader(), midiFilename)
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