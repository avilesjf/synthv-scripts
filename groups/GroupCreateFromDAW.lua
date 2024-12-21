local SCRIPT_TITLE = 'Group create from DAW V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: GroupcreatefromDAW.lua

Drag and drop notes from DAW: Automate group creation
1/ Waiting any newly created track
2/ Move imported DAW notes into a new group of notes

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
	thresholdActive = true,
	threshold = 1,
	trackTarget = nil,
	trackTargetName = SV:T("Track"),
	initialTrackName = "",
	initialColorTrack = "",
	trackTargetColor = "FFF09C9C",
	trackTargetColorRef = "FFFF0000",
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
	numGroups = 0
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

-- get timelaps reference
function NotesObject:getTimeLaps(seconds)
	-- 1s = 1411200000 blicks at 120 and 705600000 at 60
	local bpmTempoMark = self:getProjectTempo(seconds)
	
	local timeLapsMax = 1
	if bpmTempoMark ~= nil then
		local timeLapsSeconds = 1+ ((120-bpmTempoMark)/bpmTempoMark) -- Tempo 60 = 2s and tempo 120 = 1s
		-- A flick (frame-tick) is a very small unit of time.
		-- It is 1/705600000 (SV.QUARTER) of a second, exactly.		
		-- timeLapsMax = self.timeAxis:getBlickFromSeconds(timeLapsSeconds)
		timeLapsMax = timeLapsSeconds
	end
	return timeLapsMax
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
	return tempoActive
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

-- Remove DAW track 
function NotesObject:removeDAWTrack()	
	if self.newDAWTrack ~= nil then
		self.project:removeTrack(self.newDAWTrack:getIndexInParent())
		self.newDAWTrack = nil
	end
	return true
end

-- Remove track info
function NotesObject:removetrackTarget()
	if self.isNewTrack then
		if self.trackTarget ~= nil then
			self.project:removeTrack(self.trackTarget:getIndexInParent())
			self.trackTarget = nil
		end
	end
	return true
end

-- Create group for new track with new notes
function NotesObject:createGroup(startPosition, track)
	local maxLengthResult = 30
	local numGroups = self.newDAWTrack:getNumGroups()
	local groupRefMain = self.newDAWTrack:getGroupReference(1)
	local groupNotesMain = groupRefMain:getTarget()
	local noteFirst = groupNotesMain:getNote(1)
	local measureBlick = self:getFirstMesure(noteFirst:getOnset())
	local thresholdBlicks = self.timeAxis:getBlickFromSeconds(self.threshold)
	-- self:show("thresholdBlicks: " .. thresholdBlicks)
	
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
		
		if previousNote ~= nil then
			local gapNotes = previousNote:getEnd() - note:getOnset()
			-- SIL = 29400000 => 0.02s
			-- if iNote == 2 then 
				-- self:show("gapNotes: " .. gapNotes .. ", " 
				-- .. self.timeAxis:getSecondsFromBlick(gapNotes))
			-- end
			
			if self.thresholdActive then
				-- Notes overlay
				if gapNotes > 0 then
				-- if previousNote:getEnd() > note:getOnset() then
					-- Reduce previous note duration
					noteGroup:getNote(iNote - 1):setDuration(previousNote:getDuration() - gapNotes)
				end
							
				-- SIL = short time between notes
				if gapNotes < 0 and math.abs(gapNotes) < thresholdBlicks then
					-- Spread previous note duration
					noteGroup:getNote(iNote - 1):setDuration(previousNote:getDuration() + math.abs(gapNotes))
				end
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
		if string.upper(self.trackTarget:getDisplayColor()) == self.trackTargetColorRef then
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
	local stop = false
	local cause = ""	
	
	if self.numSelectedNotes ~= newSelectedNotes then
		cause = "Selected notes: " .. self.numSelectedNotes .. "/" .. newSelectedNotes
		stop = true
	end
	
	if stop then
		-- self:show("cause: " .. cause)
		self:removetrackTarget()
		self:endOfScript()
	else
		self:setTrackTargetColor()
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
				self:createGroup(measureBlick, track)
				-- End of process
				SV:setTimeout(500, function() self:endOfScript() end)
			else
				-- a new track is created with no notes
			end
			
			self.numTracks = self.project:getNumTracks() -- update new number of tracks
			SV:setTimeout(500, function() self:loop() end)
		else
			SV:setTimeout(500, function() self:loop() end)
		end
		
	end	
end

-- End of script 
function NotesObject:endOfScript()
	-- Remove DAW track if exists
	self:removeDAWTrack()
	
	if self.trackTarget ~= nil then
		-- set last track name & color
		self.trackTarget:setName(self.trackTargetName .. " " .. self.project:getNumTracks())
		self.trackTarget:setDisplayColor("#" .. self.trackTargetColorRef)
	end
	
	if not self.isNewTrack then
		if self.currentTrack ~= nil then
			self.currentTrack:setName(self.initialTrackName)
			self.trackTarget:setDisplayColor("#" .. self.initialColorTrack)
		end
	end
	
	-- End of script
	SV:finish()
end

-- Dialog response callback
function NotesObject:dialogResponse(response)
	
	if response.status then
		self.isNewTrack = response.answers.isNewTrack
		self.thresholdActive = response.answers.thresholdActive
		
		if self.isNewTrack then
			self.trackTarget = self:createTrackTarget()
		else
			self.currentTrack = SV:getMainEditor():getCurrentTrack()
			self.initialTrackName = self.currentTrack:getName()
			self.initialColorTrack = self.currentTrack:getDisplayColor()
			self.trackTarget = self.currentTrack
		end
		self.numTracks = self.project:getNumTracks()
		
		SV:setTimeout(500, function() self:loop() end)
	else
		self:endOfScript()
	end
end

-- Show asynchrone custom dialog box
function NotesObject:showDialogAsync(title)
	self.currentSeconds = self.playBack:getPlayhead()
	local seconds = self:secondsToClock(self.currentSeconds)
	self.threshold = self:getTimeLaps(self.currentSeconds) / 30 -- (120 BPM=0.03s, 60 BPM=0.06s)
	-- self:show("self.threshold: " .. self.threshold .. ",s: " .. self.timeAxis:getBlickFromSeconds(self.threshold)) -- 1411200
	
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
				name = "thresholdActive",
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

-- Main processing task	
function main()	
	local notesObject = NotesObject:new()
	local title = SV:T("Click Ok to start waiting a drag & drop from DAW.")
				 .. "\r" .. SV:T("Select any notes to stop this script.")
	notesObject:showDialogAsync(title)
end

