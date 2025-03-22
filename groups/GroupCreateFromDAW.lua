local SCRIPT_TITLE = 'Group create from DAW V1.1'

--[[

Synthesizer V Studio Pro Script
 
lua file name: GroupcreatefromDAW.lua

Drag and drop notes from DAW: Automate group creation
1/ Waiting any newly created track
2/ Move imported DAW notes into a new group of notes
Version with dialog box

Note: Stopping this script:
A/ Without finish it with a drag&drop DAW): 
	1- Update numbers of selected notes by selecting a new existing note
	2- Creating a new note on the piano roll
	3- Run this script again! (hidden group used for this feature)

Warning: 
Do not stop script by "Abort All Running Scripts", 
this will loose your original track name!

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Track", "Track"},
			{"Waiting: ", "Waiting: "},
			{"Error nil value with param: ", "Error nil value with param: "},
			{"Error in saved parameters, try again!", "Error in saved parameters, try again!"},
		},
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Groups",
		author = "JFAVILES",
		versionNumber = 2,
		minEditorVersion = 65540
	}
end

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	editor = nil,
	THRESHOLD = 41505882,  -- 0.03 seconds (120)
	INITIAL_TRACK_NAME_REF = "initialTrackName",
	INITIAL_COLOR_TRACK_REF = "initialColorTrack",
	NUM_TRACKS_REF = "numTracks",
	CURRENT_TRACK_REF = "currentTrack",
	TRACKS_COLOR_REF =  "tracksColor",
	GROUP_TAG = "GroupData:",
	GROUP_STOP_TAG = "GroupStop:",
	CURRENT_TRACK_COLOR_REF = "FFFF0000",
	TRACK_TARGET_COLOR_REF = "FFFF0000",
	IS_NEW_TRACK = "isNewTrack",
	LINK_NOTES_ACTIVE = "linkNotesActive",
	TRACK_TARGET_REF = "trackTarget",
	tracksColor = {},
	tracksColorStored = {},
	currentTrackColor = "",
	currentTrackColorOn = false,
	groupStoredRefFound = nil,
	groupStoredFound = nil,
	groupStoredRefToStopPrevious = nil,
	groupStoredToStopPrevious = nil,
	initialColorTrack = "",
	linkNotesActive = true,
	trackTarget = nil,
	trackTargetName = SV:T("Track"),
	initialTrackName = "",
	scriptInstance = "",
	trackTargetColor = "",
	trackTargetColorOn = false,
	newDAWTrack = nil,
	newGrouptRef = nil,
	currentTrack = nil,
	isNewTrack = false,
	numTracks = 0,
	selection = nil,
	selectedNotes = nil,
	numSelectedNotes = 0,
	dialogTitle = "",
	playBack = nil,
	currentSeconds = 0,
	stopProcess = false,
	stopProcessOK = false,
	sepParam = "|"
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = notesObject.project:getTimeAxis()
    notesObject.editor =  SV:getMainEditor()
	notesObject.numTracks = notesObject.project:getNumTracks()
	
	notesObject.selection = notesObject.editor:getSelection()
	notesObject.selectedNotes = notesObject.selection:getSelectedNotes()
	notesObject.numSelectedNotes = #notesObject.selection:getSelectedNotes()
	
	notesObject.playBack = SV:getPlayback()	
	notesObject.currentSeconds = notesObject.playBack:getPlayhead()
	notesObject.tracksColor = notesObject:getTracksColor()
	notesObject.currentTrack = notesObject.editor:getCurrentTrack()
	notesObject.initialTrackName = notesObject.currentTrack:getName()
	notesObject.initialColorTrack = notesObject.currentTrack:getDisplayColor()
	notesObject.trackTarget = notesObject.currentTrack

    return notesObject
end

-- Get track notes count
function NotesObject:getTrackNumNotes(track)
	local numNotes = 0
	for iGroupNote = 1, track:getNumGroups() do
		local groupRef = track:getGroupReference(iGroupNote)
		local group = groupRef:getTarget()
		numNotes = numNotes + group:getNumNotes()
	end
	return numNotes
end

--- Get last created track
function NotesObject:getLastTrack()
	return self.project:getTrack(self.project:getNumTracks())
end

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get time max gap between notes
function NotesObject:getMaxTimeGapFromBPM(positionSeconds)
	local THRESHOLDBlicks = self.THRESHOLD
	local coef = 17 -- Convert 1/quarterBlicks to 0.03 seconds (120)
	local bpm = self:getProjectTempo(positionSeconds)
	
	if bpm ~= nil then
		-- "120:" time: 0.03s, 1s: blicks 1411200000 quarter 2
		-- "60: " time: 0.06s, 1s: blicks 705600000 quarter 1
		local blicks = SV:seconds2Blick(1, bpm) -- get blicks 1 second with bpm
		local quarterBlicks = SV:blick2Quarter(blicks)
		local gapMax = (1/quarterBlicks) / coef  -- result gap in seconds
		THRESHOLDBlicks = self.timeAxis:getBlickFromSeconds(gapMax)
	end
	return THRESHOLDBlicks
end

-- Get current project tempo
function NotesObject:getProjectTempo(seconds)
	local blicks = self.timeAxis:getBlickFromSeconds(seconds)
	local tempoActive = 120
	local tempoMarks = self.timeAxis:getAllTempoMarks()
	for iTempo = 1, #tempoMarks do
		local tempoMark = tempoMarks[iTempo]
		if tempoMark ~= nil and blicks > tempoMark.position then
			tempoActive = tempoMark.bpm
		end
	end
	return math.floor(tempoActive)
end

-- Get string format from seconds
function NotesObject:secondsToClock(timestamp)
	return string.format("%02d:%06.3f", 
	  --math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Get first mesure before fist note
function NotesObject:getFirstMesure(notePos)
	local measurePos = 0
	local measureBlick = 0
	local measureFirst = self.timeAxis:getMeasureAt(notePos)
	local checkExistingMeasureMark = self.timeAxis:getMeasureMarkAt(measureFirst)
	
	if checkExistingMeasureMark ~= nil then
		if checkExistingMeasureMark.position == measureFirst then
			measurePos = checkExistingMeasureMark.position
			measureBlick = checkExistingMeasureMark.positionBlick
		else 
			self.timeAxis:addMeasureMark(measureFirst, 
						checkExistingMeasureMark.numerator, 
						checkExistingMeasureMark.denominator)
			local measureMark = self.timeAxis:getMeasureMarkAt(measureFirst)
			measurePos = measureMark.position
			measureBlick = measureMark.positionBlick
			self.timeAxis:removeMeasureMark(measureFirst)
		end
	else
		-- Temporary measure mark addition
		self.timeAxis:addMeasureMark(measureFirst, 4, 4)
		local measureMark = self.timeAxis:getMeasureMarkAt(measureFirst)
		measurePos = measureMark.position
		measureBlick = measureMark.positionBlick
		self.timeAxis:removeMeasureMark(measureFirst)
	end
	return measureBlick
end

-- Create track target
function NotesObject:createTrackTarget(name)
	local newTrackTarget = SV:create("Track")
	local newTrackIndex = self.project:addTrack(newTrackTarget)
	newTrackTarget = self.project:getTrack(newTrackIndex)
	newTrackTarget:setName(self.trackTargetName)
	return newTrackTarget
end

-- Remove track DAW
function NotesObject:removeTrackDAW()
	if self.newDAWTrack ~= nil then
		self.project:removeTrack(self.newDAWTrack:getIndexInParent())
		self.newDAWTrack = nil
	end
end

-- Remove track info if new track
function NotesObject:removeTrackTargetForNewTrack()
	if self.isNewTrack then
		if self.trackTarget ~= nil then
			self.project:removeTrack(self.trackTarget:getIndexInParent())
			self.trackTarget = nil
		end
	end
end

-- Create group for new track with new notes
function NotesObject:createGroup(startPosition, targetPosition, track)
	local maxLengthResult = 30
	local numGroups = self.newDAWTrack:getNumGroups()
	local groupRefMain = self.newDAWTrack:getGroupReference(self.newDAWTrack:getNumGroups())
	local groupNotesMain = groupRefMain:getTarget()
	local measureBlick = 0
	if groupNotesMain:getNumNotes() > 0 then
		measureBlick = self:getFirstMesure(groupNotesMain:getNote(1):getOnset())
	end
	local mainGroupNotes = {}
	self.THRESHOLD = self:getMaxTimeGapFromBPM(targetPosition) -- 41505882 = 0.06 seconds
	
	-- Save notes to groups
	for iNote = 1, groupNotesMain:getNumNotes() do
		table.insert(mainGroupNotes, groupNotesMain:getNote(iNote))
	end

	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	local previousNote = nil
	for iNote = 1, #mainGroupNotes do
		local note = mainGroupNotes[iNote]:clone()
		-- Update position within the new group
		note:setOnset(mainGroupNotes[iNote]:getOnset() - measureBlick)
		
		if self.linkNotesActive then
			if previousNote ~= nil then
				self:linkedTheNotes(previousNote, note, noteGroup:getNote(iNote - 1))
			end
		end
		
		noteGroup:addNote(note)
		previousNote = note
	end
		
	noteGroup:setName("")
	self.project:addNoteGroup(noteGroup)
	local resultLyrics = self:renameOneGroup(self.timeAxis, maxLengthResult, noteGroup)
	
	self.newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	self.newGrouptRef:setTimeOffset(measureBlick + startPosition)
	
	track:addGroupReference(self.newGrouptRef)
	return true
end

-- Linked the notes
function NotesObject:linkedTheNotes(previousNote, note, storedNote)
	local gapNotes = previousNote:getEnd() - note:getOnset()
	-- SIL = 29400000 => 0.02s
	-- if iNote == 2 then 
		-- self:show("gapNotes: " .. gapNotes .. ", " 
		-- .. self.timeAxis:getSecondsFromBlick(gapNotes))
	-- end
	
	-- Notes overlay
	if gapNotes > 0 then
	-- if previousNote:getEnd() > note:getOnset() then
		-- Reduce previous note duration
		storedNote:setDuration(previousNote:getDuration() - gapNotes)
	end
				
	-- SIL = short time between notes
	if gapNotes < 0 and math.abs(gapNotes) < self.THRESHOLD then
		-- Spread previous note duration
		storedNote:setDuration(previousNote:getDuration() + math.abs(gapNotes))
	end
end

-- Rename one group
function NotesObject:renameOneGroup(timeAxis, maxLengthResult, noteGroup)
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
					if self:isTextAccepted(timeAxis, note) then
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
		resultLyrics = self:limitStringLength(lyricsLine, maxLengthResult)
		-- Update if new lyrics only
				if string.len(resultLyrics)> 0 and
			noteGroup:getName() ~= resultLyrics then
			noteGroup:setName(resultLyrics)
		end
	end

	return resultLyrics
end

-- Limit string max length
function NotesObject:limitStringLength(resultLyrics, maxLengthResult)
	-- Limit string max length
	if string.len(resultLyrics) > maxLengthResult then
		local posStringChar = string.find(resultLyrics," ", maxLengthResult - 10)
		if posStringChar == nil then posStringChar = maxLengthResult end
		resultLyrics = string.sub(resultLyrics, 1, posStringChar)
	end
	return resultLyrics
end

-- Check lyrics "a" less than .1s for special effect
function NotesObject:isLyricsEffect(timeAxis, note)
	local result = false
	local notelength = timeAxis:getSecondsFromBlick(note:getDuration())
	-- ie: 0.0635
	if notelength < 0.1 then
		result = true
	end
	return result
end

-- Is lyrics is a text accepted
function NotesObject:isTextAccepted(timeAxis, note)
	local result = false
	local lyrics = note:getLyrics()
	
	-- Filter char '+' & '++' & '-' & 'br' & ' & .cl & .pau & .sil
	if lyrics ~= "+" and lyrics ~= "++" and lyrics ~= "-" and lyrics ~= "br" and lyrics ~= "'" 
		and lyrics ~= ".cl" and lyrics ~= ".pau" and lyrics ~= ".sil"  then
		result = true
	end
	
	-- Specific for personal vocal effect
	if lyrics == "a" and self:isLyricsEffect(timeAxis, note) then
		result = false
	end

	return result
end

-- Set color for track "trackTarget"
function NotesObject:setTrackTargetColor()
	if self.trackTarget ~= nil then
		self.trackTargetColorOn = not self.trackTargetColorOn

		if self.trackTargetColorOn then
			self.trackTargetColor = "FFF09C9C"
		else
			self.trackTargetColor = self.TRACK_TARGET_COLOR_REF
		end
		self.trackTarget:setDisplayColor("#" .. self.trackTargetColor)
	end
end

-- Create group for internal data
function NotesObject:createInternalGroup()
	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	self.project:addNoteGroup(noteGroup)
	
	local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	
	return newGrouptRef, noteGroup
end

-- Set new group name with data
function NotesObject:setNewGroupName(noteGroup, GROUP_TAG, data)
	noteGroup:setName(GROUP_TAG .. "\r" .. data)
end

-- Get previous stored data group
function NotesObject:getPreviousStoredGroup(GROUP_TAG)
	local groupStoredRefFound = nil
	local groupStoredFound = nil
	
	for iNoteGroup = 1, self.project:getNumNoteGroupsInLibrary() do
		local group = self.project:getNoteGroup(iNoteGroup)
		if group ~= nil then
			local groupRef = group:getParent()
			if groupRef ~= nil then
				local groupName = group:getName()
				local pos = string.find(groupName, GROUP_TAG)
				if pos ~= nil then 
					groupStoredRefFound = groupRef
					groupStoredFound = group
					break
				end
			end
		end
	end
	return groupStoredRefFound, groupStoredFound
end

-- Get data content
function NotesObject:getGroupContentData(data)
	local pos = string.find(data, self.GROUP_TAG)
	if pos ~= nil then
		data = string.sub(data, pos + string.len(self.GROUP_TAG) + 1)
	end
	return data
end

-- Set color for current track
function NotesObject:setCurrentTrackColor()
	if self.currentTrack ~= nil then
		self.currentTrackColorOn = not self.currentTrackColorOn

		if self.currentTrackColorOn then
			self.currentTrackColor = self.initialColorTrack
		else
			self.currentTrackColor = self.CURRENT_TRACK_COLOR_REF
		end
		self.currentTrack:setDisplayColor("#" .. self.currentTrackColor)
	end
end

-- Get group reference in time position
function NotesObject:getGroupRef(track, time)
	local groupRefFound = nil
	local numGroups = track:getNumGroups()
	local blicksPos = self.timeAxis:getBlickFromSeconds(time)
	
	-- All groups except the main group
	for iGroup = 2, numGroups do
		local groupRef = track:getGroupReference(iGroup)
		if not groupRef:isInstrumental() then
			local blickSeconds = self:secondsToClock(self.timeAxis:getSecondsFromBlick(groupRef:getOnset()))
			
			-- Get group on timing pos
			if blicksPos >= groupRef:getOnset() and blicksPos <= groupRef:getEnd() then
				groupRefFound = groupRef
				break
			end
		end						
	end						
	return groupRefFound
end

-- Main loop
function NotesObject:loop()
	local newSelectedNotes = #self.selection:getSelectedNotes()
	local cause = ""

	self.groupStoredRefToStopPrevious, self.groupStoredToStopPrevious = 
		self:getPreviousStoredGroup(self.GROUP_STOP_TAG)

	if self.groupStoredToStopPrevious ~= nil then
		self.stopProcess = true
	end
	
	if self.numSelectedNotes ~= newSelectedNotes then
		cause = "Selected notes: " .. self.numSelectedNotes .. "/" .. newSelectedNotes
		self.stopProcess = true
	end
	
	if self.stopProcess then
		-- self:show("cause: " .. cause)
		self:endOfScript()
	else
		-- if a new same script instance is running or track is deleted by another script
		if self.numTracks > self.project:getNumTracks() then
			self.stopProcess = true
			self:endOfScript()
		else
			-- Scan a new track
			self:scanNewTrack()
			
			if not self.stopProcess then
				SV:setTimeout(500, function() self:loop() end)
			else
				self:endOfScript()
			end
		end
	end	
end

-- Scan a new track
function NotesObject:scanNewTrack()
	local titleTrack = SV:T("Waiting: ")

	SV:setTimeout(200, function() self:setTrackTargetColor() end)
	self.currentSeconds = self.playBack:getPlayhead()
	local secondsInfo = self:secondsToClock(self.currentSeconds)
	self.trackTarget:setName(titleTrack .. secondsInfo)
	
	-- Check if a new track is created
	if self.numTracks < self.project:getNumTracks() then
		self.newDAWTrack = self:getLastTrack()
		local numNotesNewDAWTrack = self:getTrackNumNotes(self.newDAWTrack)
		-- Display the new track name
		self.trackTarget:setName(secondsInfo .. " " .. self.newDAWTrack:getName())
		
		if numNotesNewDAWTrack > 0 then
			local newStartPosition = self.timeAxis:getBlickFromSeconds(self.currentSeconds)
			local measureBlick = self:getFirstMesure(newStartPosition)
			
			local track = self.currentTrack
			if self.isNewTrack then
				track = self.trackTarget
			end
			
			-- New notes => Create a new group
			self:createGroup(measureBlick, self.currentSeconds, track)
			self:removeTrackDAW()
			self.stopProcess = true -- End of process
			self.stopProcessOK = true -- End of process OK
		else
			-- a new track is created with no notes
		end
	end
end

-- Stop script 
function NotesObject:stopScript()
		self.stopProcess = true
		SV:finish()
end

-- set track target
function NotesObject:setTrackTarget()
	
	if self.trackTarget ~= nil then
		if self.isNewTrack then
			-- set last track name & color
			self.trackTarget:setName(self.trackTargetName .. " " .. self.project:getNumTracks())
			self.trackTarget:setDisplayColor("#" .. self.TRACK_TARGET_COLOR_REF)
		end
	end
	
	if not self.isNewTrack then
		if self.trackTarget ~= nil then
			self.trackTarget:setName(self.initialTrackName)
			self.trackTarget:setDisplayColor("#" .. self.initialColorTrack)
		end
	end
	
end

-- Stop script 
function NotesObject:stopScript()
		self.stopProcess = true
		SV:setTimeout(30, function() self:finishScriptProcess() end)
end

-- Set initial tracks color
function NotesObject:setInitialTracksColor()
	if self.currentTrack ~= nil then
		self.currentTrack:setDisplayColor("#" .. self.initialColorTrack)
	end
	
	for iTrack = 1, #self.tracksColorStored do
		-- table.insert(self.tracksColorStored, {track[1], track[2]})
		local iTrackNumber = tonumber(self.tracksColorStored[iTrack][1])
		self.project:getTrack(iTrackNumber):setDisplayColor("#" .. self.tracksColorStored[iTrack][2])
	end
end

-- Delete stop stored group
function NotesObject:deleteStopStoredGroup()

	if self.groupStoredToStopPrevious ~= nil then
		local groupIndex = self.groupStoredToStopPrevious:getIndexInParent()
		self.project:removeNoteGroup(groupIndex)
		self.groupStoredRefToStopPrevious = nil
		self.groupStoredToStopPrevious = nil
	end
end

-- Delete previous stored group
function NotesObject:deletePreviousStoredGroup()

	if self.groupStoredFound ~= nil then
		local groupIndex = self.groupStoredFound:getIndexInParent()
		self.project:removeNoteGroup(groupIndex)
		self.groupStoredRefFound = nil
		self.groupStoredFound = nil
	end
end

-- End of script 
function NotesObject:endOfScript()
	self.stopProcess = true
	
	self:setTrackTarget()

	if not self.stopProcessOK then
		-- if error remove created target track
		SV:setTimeout(10, function() self:removeTrackTargetForNewTrack() end)	
	end

	self:setInitialTracksColor()
	
	-- clean previous data
	SV:setTimeout(10, function() self:deletePreviousStoredGroup() end)	
	SV:setTimeout(20, function() self:deleteStopStoredGroup() end)
	SV:setTimeout(30, function() self:finishScriptProcess() end)
end

-- Finish script processing
function NotesObject:finishScriptProcess()	
	-- End of script
	SV:finish()
end

-- trim string
function NotesObject:trim(s)
	  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Get tracks color
function NotesObject:getTracksColor()
	local sep = ""
	self.tracksColor = ""
	for iTrack = 1, self.numTracks do
		self.tracksColor = self.tracksColor .. sep 
			.. iTrack .. "-" .. self.project:getTrack(iTrack):getDisplayColor()
		sep = ","
	end
	return self.tracksColor
end

-- Get stored data 
function NotesObject:getStoredData()
	local result = false
	
	-- self.GROUP_TAG .. self.sepParam .. |initialTrackName=Track 1
	-- |initialColorTrack=ffff0000|numTracks=2|currentTrack=1|tracksColor=1-fff0000
	local groupData = self:getGroupContentData(self.groupStoredFound:getName())

	if self:isParametersOk(groupData) then

		local paramSlitted = self:split(groupData, self.sepParam)
		for iLine = 1, #paramSlitted do
			local param = paramSlitted[iLine]
			local paramArray = self:split(param, "=")
			local paramKey = ""
			local paramValue = ""
			
			if paramArray[1] ~= nil then
				paramKey = self:trim(paramArray[1])
			-- else
				-- self:show(SV:T("Error nil value with param: ") .. param)
			end
			
			if paramArray[2] ~= nil then
				paramValue = self:trim(paramArray[2])
			-- else
				-- self:show(SV:T("Error nil value with param: ") .. param)
			end
			self:setParametersFromStoredGroup(paramKey, paramValue)
		end		
		result = true
	end

	return result
end

-- Check if parameters OK
function NotesObject:isParametersOk(data)
	local result = false
	if data ~= nil then
		if type(data) == "string" then
			if string.find(data, self.INITIAL_TRACK_NAME_REF) ~= nil then
				result = true
			end
		end
	end
	return result
end

-- Set parameters from stored hidden group
function NotesObject:setParametersFromStoredGroup(paramName, value)
	if string.find(paramName, self.INITIAL_TRACK_NAME_REF) then
		self.initialTrackName = value
	end
	if string.find(paramName, self.INITIAL_COLOR_TRACK_REF) then
		self.initialColorTrack = value
	end
	if string.find(paramName, self.NUM_TRACKS_REF) then
		self.numTracks = tonumber(value)
	end	
	if string.find(paramName, self.TRACK_TARGET_REF) then
		local iTrack = tonumber(value)
		if iTrack <= self.numTracks then
			self.trackTarget = self.project:getTrack(iTrack)
		else
			self:show(SV:T("Error in saved parameters, try again!"))
			self:stopScript()
		end
	end
	if string.find(paramName,self.CURRENT_TRACK_REF) then
		local iTrack = tonumber(value)
		if iTrack <= self.numTracks then
			self.currentTrack = self.project:getTrack(iTrack)
		else
			self:show(SV:T("Error in saved parameters, try again!"))
			self:stopScript()
		end
	end
	if string.find(paramName, self.TRACKS_COLOR_REF) then
		-- tracksColor=1-fff09c9c,2-fff09c9c
		local tracks = self:split(value, ",")
		
		for iTrack = 1, #tracks do
			local track = self:split(tracks[iTrack], "-")
			table.insert(self.tracksColorStored, {track[1], track[2]})
		end
	end
	if string.find(paramName, self.IS_NEW_TRACK) then
		self.isNewTrack = false
		if value == "true" then 
			self.isNewTrack = true
		end
	end
	if string.find(paramName, self.LINK_NOTES_ACTIVE) then
		self.linkNotesActive = false
		if value == "true" then 
			self.linkNotesActive = true
		end
	end

end

-- Split string by sep char
function NotesObject:split(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
	  table.insert(result, each)
   end
   return result
end

-- Store data to hidden group
function NotesObject:storeToHiddenGroup()
	
	if self.groupStoredFound == nil then
		self.groupStoredRefFound, self.groupStoredFound = self:createInternalGroup()
		local data = self.INITIAL_TRACK_NAME_REF	.. "=" .. self.initialTrackName					.. self.sepParam
			.. self.INITIAL_COLOR_TRACK_REF			.. "=" .. self.initialColorTrack 				.. self.sepParam
			.. self.IS_NEW_TRACK					.. "=" .. tostring(self.isNewTrack)				.. self.sepParam
			.. self.LINK_NOTES_ACTIVE				.. "=" .. tostring(self.linkNotesActive)		.. self.sepParam
			.. self.NUM_TRACKS_REF					.. "=" .. self.numTracks						.. self.sepParam
			.. self.TRACK_TARGET_REF				.. "=" .. self.trackTarget:getIndexInParent()	.. self.sepParam
			.. self.CURRENT_TRACK_REF				.. "=" .. self.currentTrack:getIndexInParent()	.. self.sepParam
			.. self.TRACKS_COLOR_REF				.. "=" .. self.tracksColor
		self:setNewGroupName(self.groupStoredFound, self.GROUP_TAG, data)

		-- Get this stored data
		self:getStoredData()
	end
end

-- Create groups to stop process
function NotesObject:groupToStopProcess()
	self.groupStoredRefToStopPrevious, self.groupStoredToStopPrevious = self:createInternalGroup()
	self:setNewGroupName(self.groupStoredFound, self.GROUP_STOP_TAG, "STOP")
end

-- Dialog response callback
function NotesObject:dialogResponse(response)
	
	if response.status then
		self.isNewTrack = response.answers.isNewTrack
		self.linkNotesActive = response.answers.linkNotesActive
		if self.isNewTrack then
			self.trackTarget = self:createTrackTarget()
		else
			self.currentTrack = SV:getMainEditor():getCurrentTrack()
			self.initialTrackName = self.currentTrack:getName()
			self.initialColorTrack = self.currentTrack:getDisplayColor()
			self.trackTarget = self.currentTrack
		end
		self.numTracks = self.project:getNumTracks()
		
		self:storeToHiddenGroup()
		SV:setTimeout(100, function() self:loop() end)				
	else
		self:endOfScript()
	end
end

-- Show asynchrone custom dialog box
function NotesObject:showDialogAsync(title)
	self.groupStoredRefFound, self.groupStoredFound = self:getPreviousStoredGroup(self.GROUP_TAG)
	
	-- Is first script processing
	if self.groupStoredFound == nil then
	
		self.currentSeconds = self.playBack:getPlayhead()
		local seconds = self:secondsToClock(self.currentSeconds)
		
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message = title,
			buttons = "OkCancel",
			widgets = {
				{
					name = "timePosition", type = "TextArea", label = SV:T("Song position: ") .. seconds,
					height = 0, default = ""
				},
				{
					name = "info", type = "TextArea", label = SV:T("OK to start waiting DAW drag & drop!"), 
					height = 0, default = ""
				},
				{
					name = "isNewTrack",
					text = SV:T("Create a new track"),
					type = "CheckBox",
					default = false
				},
				{
					name = "linkNotesActive",
					text = SV:T("Update 'SIL' or overlay notes"),
					type = "CheckBox",
					default = true
				},
				{
					name = "separator", type = "TextArea", label = "", height = 0
				}
			}
		}
		self.dialogTitle = title
		self.onResponse = function(response) self:dialogResponse(response) end
		SV:showCustomDialogAsync(form, self.onResponse)	
	else
		local result = self:getStoredData()
		self:groupToStopProcess()
		SV:setTimeout(100, function() self:endOfScript() end)
	end
end

-- Main processing task	
function main()
	local notesObject = NotesObject:new()
	local title = SV:T("Click OK to start waiting a drag & drop from DAW.")
				 .. "\r" .. SV:T("To abort this script waiting drag&drop: Run it again!")

	notesObject:showDialogAsync(title)
end
