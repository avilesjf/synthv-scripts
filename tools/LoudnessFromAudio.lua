local SCRIPT_TITLE = 'Loudness from audio file V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: LoudnessFromAudio.lua

Read Json loudness audio data and apply loudness parameters

Json is generated from audiowaveform.exe
command line:
audiowaveform.exe -i audioFile -o jsonFile

Warnings! 
AudioFile must be a wav file format!
This version tested on Windows 11 only!
AudioWaveform v1.10.1

audiowaveform:
https://github.com/bbc/audiowaveform

Json source code included:
https://gist.github.com/tylerneylon/59f4bcf316be525b30ab

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Enter the full path audio filename", "Enter the full path audio filename"},
			{"not found!", "not found!"},
			{"Done!", "Done!"},
			{"Nothing to read!", "Nothing to read!"},
		},
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	audioWaveFormExe = "D:/Tools/audiowaveform-1.10.1.win64/audiowaveform.exe",
	pathAudioFile = "D:/Mes musiques/Autre/GoogleFemale1/",
	audioFile = "GoogleFemale1.wav",
	jsonFile = "GoogleFemale1.json",
	jsonExt = ".json",
	loudnessWeight = 2000, -- divide sample value (2000) to reduce loudness to ~10 db
	askForWaveFile = false,
	isExecutableChained = true
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = SV:getProject():getTimeAxis()
	
    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get group notes
function NotesObject:getGroupNotes()
	local groupNotes = nil
	local track = SV:getMainEditor():getCurrentTrack()
	local mainGroupRef = track:getGroupReference(1) -- main group
	local groupNotesMain = mainGroupRef:getTarget()
	local numNotes = groupNotesMain:getNumNotes()
	
	if numNotes > 0 then
		groupNotes = groupNotesMain
	else
		local numGroups = track:getNumGroups()
		local lyrics = ""
		for iGroup = 1, numGroups do
			local groupRef = track:getGroupReference(iGroup)
			local groupNotesFound = groupRef:getTarget()
			numNotes = groupNotesFound:getNumNotes()
			if numNotes > 0 then
				groupNotes = groupNotesFound
				break
			end
		end
	end
	return groupNotes
end

-- Read file content
function NotesObject:readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

-- Check if file exists
function NotesObject:isFileExists(fileName)
	local result = false
	local file = io.open(fileName, "r")
	if file ~= nil then
		io.close(file)
		result = true
	end
	return result
end

function NotesObject:quotedFile(file)
	local quote = '"'
	return quote .. file .. quote
end

function NotesObject:getJsonFilename(audioFile)
	local extension = audioFile:match("^.+%.(.+)$")
	local jsonFile = string.gsub(audioFile, "%." .. extension, self.jsonExt) -- rename (wav or mp3) to json
	return jsonFile
end

-- Get host os
function NotesObject:getHostOs()
	local hostinfo = SV:getHostInfo()
	local osType = hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	return osType
end

-- Get waveform in json
function NotesObject:getJsonWaveform(audioWaveFormExe, audioFile)
	local hostOS = self:getHostOs()
	local jsonFile = self:getJsonFilename(audioFile)
	local parameters = "-i" .. ' ' .. audioFile .. ' ' .. "-o" .. ' ' .. jsonFile
	local command = ""
	
	if hostOS == "Windows" then
		command = "call "
		.. self:quotedFile(audioWaveFormExe) 
		.. " -i "
		.. self:quotedFile(audioFile) 
		.. " -o "
		.. self:quotedFile(jsonFile)	
	else
		-- TODO:
		command = "call "
		.. self:quotedFile(audioWaveFormExe) 
		.. " -i "
		.. self:quotedFile(audioFile) 
		.. " -o "
		.. self:quotedFile(jsonFile)		
	end
	
	-- Clear previous json file
	if self:isFileExists(jsonFile) then
		-- Check to be sure to remove a json file
		if string.find(jsonFile, self.jsonExt) ~= nil then
			os.remove(jsonFile)
		end
	end
	
	os.execute(command)
	return jsonFile
end

-- Get clean filename
function NotesObject:getCleanFilename(file)
	local filename = file
	if #filename > 0 then
		if string.find(filename, '"') ~= nil then
			filename = filename:gsub('"', '')
		end
	end
	return filename
end

-- Get wave file path
function NotesObject:getWaveFile()
	local filename = SV:showInputBox(SV:T(SCRIPT_TITLE), SV:T("Enter the full path audio filename"), "")
	return filename
end

-- Start project notes processing
function NotesObject:start()
	local result = false
	self.jsonFile = ""
	local filename = ""
	
	if self.askForWaveFile then
		filename = self:getWaveFile()
		if #filename == 0 then
			return result
		end
		
		filename = self:getCleanFilename(filename)
		if not self:isFileExists(filename) then
			self:show(filename .. " " .. SV:T("not found!"))
			return result
		end
		self.audioFile = filename
	else
		self.audioFile = self.pathAudioFile .. self.audioFile
	end

	-- Chain a command line to generate the Json loudness file
	if self.isExecutableChained then
		self.jsonFile = self:getJsonWaveform(self.audioWaveFormExe, self.audioFile)
	else 
		self.jsonFile = self:getJsonFilename(self.audioFile)
	end
	
	-- if process not ok
	if not self:isFileExists(self.jsonFile) then
		self:show(self.jsonFile .. " " .. SV:T("not found!"))
	else
		-- Process is ok
		local groupNotes = self:getGroupNotes()
		local lastNote = groupNotes:getNote(groupNotes:getNumNotes())
		local loudness = groupNotes:getParameter("loudness")
		loudness:removeAll()
		
		local jsonData = self:readAll(self.jsonFile)
		
		if jsonData ~= nil then
			if #jsonData > 0 then
				load_json()
				local js = json.parse(jsonData)
				-- channels":1,"sample_rate":44100,"samples_per_pixel":256,"bits":16,"length":1796,
				local version = js.version
				local channels = js.channels
				local sample_rate = js.sample_rate
				local samples_per_pixel = js.samples_per_pixel
				local bits = js.bits
				local length = js.length
				local data = js.data
				
				local lastPos = self.timeAxis:getSecondsFromBlick(lastNote:getEnd())
				local timeRatio = length / lastPos * 2 -- 1796 / 10.379 = 173.19 * 2 = 346.38
				
				for iPos = 1, #data, 1 do
					local timeInfo = self.timeAxis:getBlickFromSeconds(iPos/timeRatio)
					if data[iPos] > 0 then
						loudness:add(timeInfo, data[iPos]/self.loudnessWeight) -- Add loudness
					end
				end
				loudness:simplify(groupNotes:getNote(1):getOnset(), lastNote:getOnset(), 0.01)
				result = true
				self:show(SV:T("Done!"))
			else
				self:show(SV:T("Nothing to read!"))
			end
		else
			self:show(SV:T("Nothing to read!"))
		end
	end
	return result
end

-- Main process
function main()
	local notesObject = NotesObject:new()
	notesObject:start()
	
	-- End of script
	SV:finish()
end

--https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
--[[ json.lua

A compact pure-Lua JSON library.
The main functions are: json.stringify, json.parse.

## json.stringify:

This expects the following to be true of any tables being encoded:
 * They only have string or number keys. Number keys must be represented as
   strings in json; this is part of the json spec.
 * They are not recursive. Such a structure cannot be specified in json.

A Lua table is considered to be an array if and only if its set of keys is a
consecutive sequence of positive integers starting at 1. Arrays are encoded like
so: `[2, 3, false, "hi"]`. Any other type of Lua table is encoded as a json
object, encoded like so: `{"key1": 2, "key2": false}`.

Because the Lua nil value cannot be a key, and as a table value is considerd
equivalent to a missing key, there is no way to express the json "null" value in
a Lua table. The only way this will output "null" is if your entire input obj is
nil itself.

An empty Lua table, {}, could be considered either a json object or array -
it's an ambiguous edge case. We choose to treat this as an object as it is the
more general type.

To be clear, none of the above considerations is a limitation of this code.
Rather, it is what we get when we completely observe the json specification for
as arbitrary a Lua object as json is capable of expressing.

## json.parse:

This function parses json, with the exception that it does not pay attention to
\u-escaped unicode code points in strings.

It is difficult for Lua to return null as a value. In order to prevent the loss
of keys with a null value in a json string, this function uses the one-off
table value json.null (which is just an empty table) to indicate null values.
This way you can check if a value is null with the conditional
`val == json.null`.

If you have control over the data and are using Lua, I would recommend just
avoiding null values in your data to begin with.

--]]

function load_json()
	json = {}


	-- Internal functions.

	local function kind_of(obj)
	  if type(obj) ~= 'table' then return type(obj) end
	  local i = 1
	  for _ in pairs(obj) do
		if obj[i] ~= nil then i = i + 1 else return 'table' end
	  end
	  if i == 1 then return 'table' else return 'array' end
	end

	local function escape_str(s)
	  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
	  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
	  for i, c in ipairs(in_char) do
		s = s:gsub(c, '\\' .. out_char[i])
	  end
	  return s
	end

	-- Returns pos, did_find; there are two cases:
	-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
	-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
	-- This throws an error if err_if_missing is true and the delim is not found.
	local function skip_delim(str, pos, delim, err_if_missing)
	  pos = pos + #str:match('^%s*', pos)
	  if str:sub(pos, pos) ~= delim then
		if err_if_missing then
		  error('Expected ' .. delim .. ' near position ' .. pos)
		end
		return pos, false
	  end
	  return pos + 1, true
	end

	-- Expects the given pos to be the first character after the opening quote.
	-- Returns val, pos; the returned pos is after the closing quote character.
	local function parse_str_val(str, pos, val)
	  val = val or ''
	  local early_end_error = 'End of input found while parsing string.'
	  if pos > #str then error(early_end_error) end
	  local c = str:sub(pos, pos)
	  if c == '"'  then return val, pos + 1 end
	  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
	  -- We must have a \ character.
	  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
	  local nextc = str:sub(pos + 1, pos + 1)
	  if not nextc then error(early_end_error) end
	  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
	end

	-- Returns val, pos; the returned pos is after the number's final character.
	local function parse_num_val(str, pos)
	  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
	  local val = tonumber(num_str)
	  if not val then error('Error parsing number at position ' .. pos .. '.') end
	  return val, pos + #num_str
	end


	-- Public values and functions.

	function json.stringify(obj, as_key)
	  local s = {}  -- We'll build the string as an array of strings to be concatenated.
	  local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
	  if kind == 'array' then
		if as_key then error('Can\'t encode array as key.') end
		s[#s + 1] = '['
		for i, val in ipairs(obj) do
		  if i > 1 then s[#s + 1] = ', ' end
		  s[#s + 1] = json.stringify(val)
		end
		s[#s + 1] = ']'
	  elseif kind == 'table' then
		if as_key then error('Can\'t encode table as key.') end
		s[#s + 1] = '{'
		for k, v in pairs(obj) do
		  if #s > 1 then s[#s + 1] = ', ' end
		  s[#s + 1] = json.stringify(k, true)
		  s[#s + 1] = ':'
		  s[#s + 1] = json.stringify(v)
		end
		s[#s + 1] = '}'
	  elseif kind == 'string' then
		return '"' .. escape_str(obj) .. '"'
	  elseif kind == 'number' then
		if as_key then return '"' .. tostring(obj) .. '"' end
		return tostring(obj)
	  elseif kind == 'boolean' then
		return tostring(obj)
	  elseif kind == 'nil' then
		return 'null'
	  else
		error('Unjsonifiable type: ' .. kind .. '.')
	  end
	  return table.concat(s)
	end

	json.null = {}  -- This is a one-off table to represent the null value.

	function json.parse(str, pos, end_delim)
	  pos = pos or 1
	  if str == nil or pos > #str then error('Reached unexpected end of input, pos: ' .. pos) end
	  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
	  local first = str:sub(pos, pos)
	  if first == '{' then  -- Parse an object.
		local obj, key, delim_found = {}, true, true
		pos = pos + 1
		while true do
		  key, pos = json.parse(str, pos, '}')
		  if key == nil then return obj, pos end
		  if not delim_found then error('Comma missing between object items.') end
		  pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
		  obj[key], pos = json.parse(str, pos)
		  pos, delim_found = skip_delim(str, pos, ',')
		end
	  elseif first == '[' then  -- Parse an array.
		local arr, val, delim_found = {}, true, true
		pos = pos + 1
		while true do
		  val, pos = json.parse(str, pos, ']')
		  if val == nil then return arr, pos end
		  if not delim_found then error('Comma missing between array items.') end
		  arr[#arr + 1] = val
		  pos, delim_found = skip_delim(str, pos, ',')
		end
	  elseif first == '"' then  -- Parse a string.
		return parse_str_val(str, pos + 1)
	  elseif first == '-' or first:match('%d') then  -- Parse a number.
		return parse_num_val(str, pos)
	  elseif first == end_delim then  -- End of an object or array.
		return nil, pos + 1
	  else  -- Parse true, false, or null.
		local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
		for lit_str, lit_val in pairs(literals) do
		  local lit_end = pos + #lit_str - 1
		  if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
		end
		local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
		error('Invalid json syntax starting at ' .. pos_info_str)
	  end
	end

	return json
end
