local SCRIPT_TITLE = 'Playing infos V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: PlayingInfos.lua

Playing song and displaying current notes infos on groups title
and display current timing on track name

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"stopped", "stopped"},
			{"Playing", "Playing"},
			{"PlayBack status: ", "PlayBack status: "},
			{"OK to start, Cancel to stop!", "OK to start, Cancel to stop!"},
			{"Group", "Group"},
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
	editor = nil,
	track = nil,
	groupsCount = nil,
	secondDecay = 0,
	selection = nil,
	selectedNotes = nil,
	groupFromNote = nil,
	timeBegin = nil,
	timeEnd = nil,
	lyrics = "",
	currentGroupRef = nil,
	groupNotesMain = nil,
	parametersFoundCount = 0,
	parametersRemovedCount = 0,
	pasteAsyncAction = true,
	currentCopyPasteAction = 1,
	lastDialogResponse = "",
	dialogTitle = "",
	dialogsCount = 0,
	parametersFound = nil,
	playBack = nil,
	navigate = nil,
	playBackStatus = SV:T("stopped"),
	currentSeconds = 0,
	noteInfo = nil,
	projectDuration = 0,
	trackName = "",
	groups = {},
	keyNames = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"}

}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
    notesObject.timeAxis = notesObject.project:getTimeAxis()
    notesObject.editor =  SV:getMainEditor()
    notesObject.track = notesObject.editor:getCurrentTrack()
	notesObject.trackName = notesObject.track:getName()
	notesObject.groups = notesObject:storeGroupsName()
	
	notesObject.playBack = SV:getPlayback()	
	notesObject.navigate = SV:getMainEditor():getNavigation()
	notesObject.currentSeconds = notesObject.playBack:getPlayhead()
	notesObject.projectDuration = notesObject:getProjectDuration()
	
    return notesObject
end

-- Get project duration
function NotesObject:getProjectDuration()
	local maxDuration = 0	
	local iTracks = self.project:getNumTracks()
	
	for iTrack = 1, iTracks do
		local trackItem = self.project:getTrack(iTrack)
		if trackItem:getDuration() > maxDuration then
			maxDuration = trackItem:getDuration()
		end
	end
	return maxDuration
end

-- Store groups name
function NotesObject:storeGroupsName()
	self.groups = {}
	for iGroupNote = 1, self.track:getNumGroups() do
		local groupRef = self.track:getGroupReference(iGroupNote)
		local group = groupRef:getTarget()	
		table.insert(self.groups, group:getName())
	end
	return self.groups
end

-- Restore groups name
function NotesObject:restoreGroupsName()
	for iGroup = 1, #self.groups do
		local groupRef = self.track:getGroupReference(iGroup)
		local group = groupRef:getTarget()
		group:setName(self.groups[iGroup])
	end
end

-- Dialog response callback
function NotesObject:dialogResponse(response)
	self.dialogsCount = self.dialogsCount - 1
	
	if response~=nil and response.status == true then
		self.lastDialogResponse = response.answers.scaleInfos1

		if self.playBack:getStatus() == "stopped" then
			self.playBack:play()
			SV:setTimeout(1, function() self:setGroupNoteInfos() end)
		end
		SV:setTimeout(200, function() self:showDialogAsync(SV:T("Playing")) end)
	else
		if self.playBack:getStatus() == "playing" or self.playBack:getStatus() == "looping"  then
			self.playBack:stop()
		end
		self:endOfScript()
	end
end

-- End of script 
function NotesObject:endOfScript()
	-- Restore updated data to track name & groups name
	self.track:setName(self.trackName)
	self:restoreGroupsName()
	-- End of script
	SV:finish()
end

-- Show asynchrone custom dialog box
function NotesObject:showDialogAsync(title)
	self.currentSeconds = self.playBack:getPlayhead()
	self.playBackStatus = self.playBack:getStatus()
	
	local form = {
		title = SV:T(SCRIPT_TITLE),
		message = title,
		buttons = "OkCancel",
		widgets = {
			{
				name = "playBackStatus", type = "TextArea", label = SV:T("PlayBack status: ") .. self.playBackStatus, 
				height = 0
			},
			{
				name = "info", type = "TextArea", label = SV:T("OK to start, Cancel to stop!"), 
				height = 0, default = ""
			}
		}
	}
	self.dialogTitle = title
	self.dialogsCount = self.dialogsCount + 1
	self.onResponse = function(response) self:dialogResponse(response) end
	SV:showCustomDialogAsync(form, self.onResponse)	
end

-- Get string format from seconds
function NotesObject:secondsToClock(timestamp)
	return string.format("%02d:%06.3f", 
	  --math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Set group note infos
function NotesObject:setGroupNoteInfos()
	self.playBackStatus = self.playBack:getStatus()
	self.currentSeconds = self.playBack:getPlayhead()
	
	local newInfo = self:secondsToClock(self.currentSeconds)
	
	self:setGroupNotes(newInfo)
	
	-- Recursive loop 
	if self.playBack:getStatus() == "playing" or self.playBack:getStatus() == "looping"  then
		SV:setTimeout(10, function() self:setGroupNoteInfos() end)
	else
		-- On ending song, restart to begin (automate looping song)
		-- if self.currentSeconds > self.timeAxis:getSecondsFromBlick(self.track:getDuration()) then
		if self.currentSeconds > self.timeAxis:getSecondsFromBlick(self.projectDuration) then
			-- Loop playing the song
			SV:setTimeout(300, function() self:playfromStart() end)
			-- Recursive loop to display infos again
			SV:setTimeout(301, function() self:setGroupNoteInfos() end)
		end
	end
end

-- Play again from at beginning song
function NotesObject:playfromStart()
	self.playBack:seek(0)
	self.playBack:play()
end

-- Get the corresponding key note from pitch
function NotesObject:getKeyNote(pitch)
	local keyNote = self.keyNames[(pitch % 12) + 1]
	return keyNote
end

-- Set the group notes name title with the current playing note infos
function NotesObject:setGroupNotes(info)
	local infoNote = ""
	local groupName = ""
	local positionBlick = self.timeAxis:getBlickFromSeconds(self.playBack:getPlayhead())
	local isGroupNotesExists = self.track:getNumGroups() > 1
	
	for iGroupNote = 1, self.track:getNumGroups() do
		local groupRef = self.track:getGroupReference(iGroupNote)
		local timeOffset = groupRef:getTimeOffset()
		local group = groupRef:getTarget()	
		
		if (groupRef:getOnset()) <= positionBlick and (groupRef:getEnd()) >= positionBlick then
			groupName = group:getName()
		end
		
		infoNote = self:getCurrentNoteInfo(group, positionBlick, timeOffset)
		
		if string.len(infoNote) > 0 then 
			group:setName(infoNote)
			local iGroup = iGroupNote
			if isGroupNotesExists and iGroupNote > 1 then
				iGroup = iGroupNote - 1
			end
			self.track:setName(SV:T("Group") .. " " .. iGroup .. ": " .. info)
			break
		end
	end
	if string.len(groupName) == 0 then 
		self.track:setName(SV:T("Group") .. ": " .. info)
	end
	return infoNote
end

-- Get the current playing note infos
function NotesObject:getCurrentNoteInfo(group, position, timeOffset)
	local infoNote = ""	
	for iNote = 1, group:getNumNotes() do
		local note = group:getNote(iNote)
		if note ~= nil then
			if (timeOffset + note:getOnset()) <= position 
				and (note:getEnd() + timeOffset) >= position then
				
				infoNote = self:getNoteContent(note)
				break
			end
		end
	end
	return infoNote
end

-- Get the note content information
function NotesObject:getNoteContent(note)
	local infoNote = "Note: " .. self:getKeyNote(note:getPitch()) .. " (" .. string.format("%03d", note:getPitch()) .. ")"
	if note:getLyrics() ~= nil and string.len(note:getLyrics()) > 0 then
		infoNote = infoNote .. " " .. note:getLyrics()
	end
	if note:getPhonemes() ~= nil and string.len(note:getPhonemes()) > 0 then
		infoNote = infoNote .. " (" .. note:getPhonemes() .. ")"
	end						
	return infoNote
end

-- Main processing task	
function main()
	
	local notesObject = NotesObject:new()
	notesObject:showDialogAsync("Ready to play!")
end
