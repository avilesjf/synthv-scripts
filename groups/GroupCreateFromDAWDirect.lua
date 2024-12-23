local SCRIPT_TITLE = 'Group create from DAW direct V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: GroupCreateFromDAWDirect.lua

Drag and drop notes from DAW: Automate group creation
1/ Waiting any newly created track
2/ Move imported DAW notes into a new group of notes
Version with NO dialog box

Note: Stopping this script:
A/ Without finish it with a drag&drop DAW): 
	1- Update numbers of selected notes by selecting a new existing note
	2- Creating a new note on the piano roll
	3- Run this script again! (host clipboard is used for this feature)

Remark: 
Do not stop script by "Abort All Running Scripts", 
this will loose your original track name!

2024 - JF AVILES
--]]

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Groups",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	editor = nil,
	linkNotesActive = true,
	threshold = 41505882,  -- 0.03 seconds (120)
	trackTarget = nil,
	trackTargetName = SV:T("Track"),
	initialTrackName = "",
	scriptInstance = "",
	initialColorTrack = "",
	trackTargetColor = "FFF09C9C",
	trackTargetColorRef = "FFFF0000",
	trackTargetColorOn = false,
	newDAWTrack = nil,
	currentTrack = nil,
	isNewTrack = false,
	numTracks = 0,
	selection = nil,
	selectedNotes = nil,
	numSelectedNotes = 0,
	playBack = nil,
	currentSeconds = 0,
	noteInfo = nil,
	numNotes = 0,
	numGroups = 0,
	stopProcess = false,
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
	local thresholdBlicks = self.threshold
	local coef = 17 -- Convert 1/quarterBlicks to 0.03 seconds (120)
	local bpm = self:getProjectTempo(positionSeconds)
	
	if bpm ~= nil then
		-- "120:" time: 0.03s, 1s: blicks 1411200000 quarter 2
		-- "60: " time: 0.06s, 1s: blicks 705600000 quarter 1
		local blicks = SV:seconds2Blick(1, bpm) -- get blicks 1 second with bpm
		local quarterBlicks = SV:blick2Quarter(blicks)
		local gapMax = (1/quarterBlicks) / coef  -- result gap in seconds
		thresholdBlicks = self.timeAxis:getBlickFromSeconds(gapMax)
	end
	return thresholdBlicks
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

-- Remove track info
function NotesObject:removeTrackTarget()
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
	local groupRefMain = self.newDAWTrack:getGroupReference(1)
	local groupNotesMain = groupRefMain:getTarget()
	local noteFirst = groupNotesMain:getNote(1)
	local measureBlick = self:getFirstMesure(noteFirst:getOnset())
	local mainGroupNotes = {}
	self.threshold = self:getMaxTimeGapFromBPM(targetPosition) -- 41505882 = 0.06 seconds
	
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
	
	local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	newGrouptRef:setTimeOffset(measureBlick + startPosition)
	
	track:addGroupReference(newGrouptRef)
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
	if gapNotes < 0 and math.abs(gapNotes) < self.threshold then
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
			self.trackTargetColor = self.trackTargetColorRef
		end
		self.trackTarget:setDisplayColor("#" .. self.trackTargetColor)
	end
end

-- Main loop
function NotesObject:loop()
	local newSelectedNotes = #self.selection:getSelectedNotes()
	local titleTrack = SV:T("Waiting: ")
	local cause = ""
	
	if self.numSelectedNotes ~= newSelectedNotes then
		cause = "Selected notes: " .. self.numSelectedNotes .. "/" .. newSelectedNotes
		self.stopProcess = true
	end
	
	if self.stopProcess then
		-- self:show("cause: " .. cause)
		self:endOfScript()
	else
		-- if a new same script instance is running or track is deleted by another script
		if self:isAnotherInstance() or self.numTracks > self.project:getNumTracks() then
			if self.scriptInstance ~= SV:T(SCRIPT_TITLE) then
				self:endOfScript()
			else
				self:stopScript()
			end
		else
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
				else
					-- a new track is created with no notes
				end
				
				if not self.stopProcess then
					self.numTracks = self.project:getNumTracks() -- update new number of tracks
					SV:setTimeout(500, function() self:loop() end)
				else
					-- End of process
					self:endOfScript(true)
				end
			else
				SV:setTimeout(500, function() self:loop() end)
			end			
		end			
	end	
end

-- Stop script 
function NotesObject:stopScript()
		self.stopProcess = true
		SV:finish()
end

-- End of script 
function NotesObject:endOfScript(status)
	self.stopProcess = true
	
	if self.trackTarget ~= nil then
		if self.isNewTrack then
			-- set last track name & color
			self.trackTarget:setName(self.trackTargetName .. " " .. self.project:getNumTracks())
			self.trackTarget:setDisplayColor("#" .. self.trackTargetColorRef)
		end
	end
	
	if not self.isNewTrack then
		if self.trackTarget ~= nil then
			self.trackTarget:setName(self.initialTrackName)
			self.trackTarget:setDisplayColor("#" .. self.initialColorTrack)
		end
	end

	if not status then
		self:removeTrackTarget()
	end
	
	SV:setHostClipboard("")
	
	-- End of script
	SV:finish()
end

-- trim string
function NotesObject:trim(s)
	  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Check previous process
function NotesObject:previousProcess()
	local result = false
	
	-- Script=Group create from DAW direct V1.0|initialTrackName=Track 1
	-- |initialColorTrack=ffff0000|isNewTrack=false|linkNotesActive=true|numTracks=2|trackTarget=1
	local hostCB = SV:getHostClipboard()
	if self:isParametersOk(hostCB) then
		local paramSlitted = self:split(hostCB, self.sepParam)
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
			self:setParametersFromClipBoard(paramKey, paramValue)
		end		
		self:addNewInstance(hostCB)
		local hostCBNew = SV:getHostClipboard()
		result = true
	end

	return result
end

-- Check if parameters OK
function NotesObject:isParametersOk(hostCB)
	local result = false
	if hostCB ~= nil then
		if type(hostCB) == "string" then
			if string.find(hostCB, "Script=") ~= nil then
				result = true
			end
		end
	end
	return result
end

-- Is another script instance exists
function NotesObject:isAnotherInstance()
	local result = false
	local instanceKey = "instance"
	local hostCB = SV:getHostClipboard()
	if self:isParametersOk(hostCB) then
		if string.find(hostCB, instanceKey .. "=") ~= nil then
			self.isInstanceFound = true
			-- self:show("Another script is running: " .. hostCB)
			local scriptName = self:scriptNameInstance(hostCB, instanceKey)
			-- if string.len(scriptName) > 0 then
				-- self:show("Another script is running: " .. scriptName)
			-- end
			result = true
		end
	end
	
	return result
end

-- Get the script name of the other instance
function NotesObject:scriptNameInstance(hostCB, instanceKey)
	local scriptName = ""
	local paramSlitted = self:split(hostCB, self.sepParam)
	
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
		
		if paramKey == instanceKey then
			scriptName = paramValue
		end
	end
	return scriptName
end

-- Add a new instance parameters to clipboard
function NotesObject:addNewInstance(hostCB)
	local hostCBNew = hostCB	.. self.sepParam
								.. "instance=" .. SV:T(SCRIPT_TITLE)
	SV:setHostClipboard(hostCBNew)
end

-- Set clipboard parameters 
function NotesObject:setParametersFromClipBoard(paramName, value)
	if string.find(paramName, "Script") then
		self.scriptInstance = value
	end
	if string.find(paramName, "initialTrackName") then
		self.initialTrackName = value
	end
	if string.find(paramName, "initialColorTrack") then
		self.initialColorTrack = value
	end
	if string.find(paramName, "isNewTrack") then
		self.isNewTrack = false
		if value == "true" then 
			self.isNewTrack = true
		end
	end
	if string.find(paramName, "linkNotesActive") then
		self.linkNotesActive = false
		if value == "true" then 
			self.linkNotesActive = true
		end
	end
	if string.find(paramName, "numTracks") then
		self.numTracks = tonumber(value)
	end
	if string.find(paramName, "trackTarget") then
		local iTrack = tonumber(value)
		if iTrack <= self.numTracks then
			self.trackTarget = self.project:getTrack(iTrack)
		else
			self:show("Error in clipboard parameters, try again!")
			self:stopScript()
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

-- Store data to clipboard
function NotesObject:storeToClipboard()

	local projectStatus = 
		"Script=" .. SV:T(SCRIPT_TITLE) .. self.sepParam
		.."initialTrackName="	.. self.initialTrackName 			.. self.sepParam
		.. "initialColorTrack=" .. self.initialColorTrack 			.. self.sepParam
		.. "isNewTrack=" 		.. tostring(self.isNewTrack) 		.. self.sepParam
		.. "linkNotesActive="	.. tostring(self.linkNotesActive)	.. self.sepParam
		.. "numTracks=" 		.. self.numTracks					.. self.sepParam
		.. "trackTarget="		.. self.trackTarget:getIndexInParent()
	-- Script=Group create from DAW direct V1.0|initialTrackName=Track 1
	-- |initialColorTrack=fff09c9c|isNewTrack=false|linkNotesActive=true|numTracks=2|trackTarget=1
	SV:setHostClipboard(projectStatus)
end

-- Start process
function NotesObject:startProcess()
	
	if not self:previousProcess() then
		self.currentSeconds = self.playBack:getPlayhead()
		
		if self.isNewTrack then
			self.trackTarget = self:createTrackTarget()
		else
			self.currentTrack = SV:getMainEditor():getCurrentTrack()
			self.initialTrackName = self.currentTrack:getName()
			self.initialColorTrack = self.currentTrack:getDisplayColor()
			self.trackTarget = self.currentTrack
		end
		self.numTracks = self.project:getNumTracks()
		
		self:storeToClipboard()
		
		SV:setTimeout(500, function() self:loop() end)
	else
		-- if instance is another script
		if self.scriptInstance ~= SV:T(SCRIPT_TITLE) then
			self:stopScript()
		else
			self:endOfScript()
		end
	end
end


-- Main processing task	
function main()	
	local notesObject = NotesObject:new()
	notesObject:startProcess()
end

