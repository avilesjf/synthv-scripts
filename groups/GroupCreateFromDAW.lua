local SCRIPT_TITLE = 'Group create from DAW V1.0'

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
	trackTargetName = SV:T("Track new"),
	trackNameModified = SV:T("Waiting:"),
	initialTrackName = "",
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
	dialogTitle = "",
	playBack = nil,
	currentSeconds = 0,
	noteInfo = nil,
	numNotes = 0,
	numGroups = 0,
	stopProcess = false
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
	self.threshold = self:getMaxTimeGapFromBPM(targetPosition)  -- 41505882 = 0.06 seconds
	
	local mainGroupNotes = {}
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
	local cause = ""	
	self.stopProcess = false
	
	if self.numSelectedNotes ~= newSelectedNotes then
		cause = "Selected notes: " .. self.numSelectedNotes .. "/" .. newSelectedNotes
		self.stopProcess = true
	end
	
	if self.stopProcess then
		-- self:show("cause: " .. cause)
		self:endOfScript()
	else
		-- if a track is deleted by another script
		if self.numTracks > self.project:getNumTracks() then
			self.stopProcess = true
			SV:finish()
		else
			self:setTrackTargetColor()
			self.currentSeconds = self.playBack:getPlayhead()
			local secondsInfo = self:secondsToClock(self.currentSeconds)
			self.trackTarget:setName(self.trackNameModified .. " " .. secondsInfo)
			
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

--- Get track list
function NotesObject:isTrackWaiting(wait)
	local iTracks = self.project:getNumTracks()
	local isWaiting = false
	
	for iTrack = 1, iTracks do
		local track = self.project:getTrack(iTrack)
		if string.find(track:getName(), wait) ~= nil then
			isWaiting = true
			break
		end
	end
	return isWaiting
end

-- End of script 
function NotesObject:endOfScript(status)
	self:removeTrackDAW()
	if not status then
		self:removeTrackTarget()
	end
	SV:setHostClipboard("")

	-- Remove DAW track if exists
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

	-- End of script
	SV:finish()
end

-- Check previous process
function NotesObject:previousProcess()
	local result = false
	
	-- Script="GroupCreateFromDAW", initialTrackName=Unnamed Track, 
	-- initialColorTrack=ff7db235, isNewTrack=false, linkNotesActive=true, numTracks=1, trackTarget=1	
	local hostClipboard = SV:getHostClipboard()
	
	if self:isParametersOk(hostClipboard) then
		local paramSlitted = self:split(hostClipboard, ", ")
		for iLine = 1, #paramSlitted do
			local param = paramSlitted[iLine]
			local paramArray = self:split(param, "=")
			self:setParametersFromClipBoard(paramArray[1], paramArray[2])
		end
		self:endOfScript()
		result = true
	end
	
	return result
end


-- Check if parameters OK
function NotesObject:isParametersOk(hostClipboard)
	local result = false
	if hostClipboard ~= nil then
		if type(hostClipboard) == "string" then
			if string.find(hostClipboard, "Script=") ~= nil then
				if string.find(hostClipboard, "GroupCreateFromDAW") ~= nil then
					result = true
				end
			end
		end
	end
	return result
end

-- Set clipboard parameters 
function NotesObject:setParametersFromClipBoard(paramName, value)
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
		self.trackTarget = self.project:getTrack(iTrack)
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

	local projectStatus = "Script=\"GroupCreateFromDAW\", "
		.."initialTrackName=" .. self.initialTrackName .. ", "
		.. "initialColorTrack=" .. self.initialColorTrack .. ", " 
		.. "isNewTrack=" .. tostring(self.isNewTrack) .. ", "
		.. "linkNotesActive=" .. tostring(self.linkNotesActive) .. ", "
		.. "numTracks=" .. self.numTracks .. ", "
		.. "trackTarget=" .. self.trackTarget:getIndexInParent()
	-- Script="GroupCreateFromDAW", initialTrackName=Unnamed Track, 
	-- initialColorTrack=ff7db235, isNewTrack=false, linkNotesActive=true, numTracks=1, trackTarget=1
	SV:setHostClipboard(projectStatus)
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
		
		self:storeToClipboard()
		
		SV:setTimeout(500, function() self:loop() end)
	else
		self:endOfScript()
	end
end

-- Show asynchrone custom dialog box
function NotesObject:showDialogAsync(title)

	if not self:previousProcess() then
	
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
	end
end

-- Main processing task	
function main()	
	local notesObject = NotesObject:new()
	local title = SV:T("Click OK to start waiting a drag & drop from DAW.")
				 .. "\r" .. SV:T("To abort this script waiting drag&drop: Run it again!")
	
	notesObject:showDialogAsync(title)
end
