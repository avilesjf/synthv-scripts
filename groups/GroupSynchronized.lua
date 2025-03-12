local SCRIPT_TITLE = 'Group multitracks synchronized V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: GroupSynchronized.lua

Usage: Run this script to start group synchronization. Run again to stop it.
Splitting notes will stop the sync process.

Group synchronization for duplicated groups across multiple tracks (eg: groups harmonies).
Note: Cloned note groups are already synchronized (excluded here).

Run this script on the main track to control all "Equivalent Groups" on other tracks.
Equivalent groups: the same number of notes and the same time (approximately).
The main track's color flashes to indicate the running script execution.
The synced track's color changes to display the synced groups.
Running the script again interrupts this process.

Warning! Only getOnset notes are managed (not pitched notes => harmonies)
!Splitting notes will stop the sync process! (criteria for notes count)
The undo action stack is affected by the updated track color (visual processing).
Do this for each note groups on your main track you need to synchronize.

2025 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Waiting: ", "Waiting: "},
			{"Error nil value with param: ", "Error nil value with param: "},
			{"Error in stored parameters, try again!", "Error in stored parameters, try again!"},
			{"No group found in current track and playhead position!", "No group found in current track and playhead position!"},
		},
	}
end

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
	threshold = 41505882,  -- 0.03 seconds (120)
	currentTrack = nil,
	initialTrackName = "",
	initialTrackNameRef = "initialTrackName",
	initialColorTrackRef = "initialColorTrack",
	numTracksRef = "numTracks",
	currentTrackRef = "currentTrack",
	tracksColorRef =  "tracksColor",
	tracksColor = {},
	tracksColorStored = {},
	initialColorTrack = "",
	currentTrackColor = "",
	currentTrackColorRef = "FFFF0000",
	currentTrackColorOn = false,
	trackTarget = {},
	trackTargetInit = true,
	trackTargetColor = "",
	trackTargetColorRef = "FFFFF000",
	currentTrack = nil,
	currentTrackNumber = nil,
	groupSource = nil,
	groupSourceNumNotes = 0,
	numTracks = 0,
	playBack = nil,
	currentSeconds = 0,
	stopProcess = false,
	sepParam = "|",
	groupTag = "GroupData:",
	groupStoredRefFound = nil,
	groupStoredFound = nil,
	groupStopTag = "GroupStop:",
	groupStoredRefToStopPrevious = nil,
	groupStoredToStopPrevious = nil,
	groupFound = {}
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
	
	notesObject.playBack = SV:getPlayback()	
	notesObject.currentSeconds = notesObject.playBack:getPlayhead()
	notesObject.currentSecondsDisplay = self:secondsToClock(notesObject.currentSeconds)

	notesObject.currentTrack = SV:getMainEditor():getCurrentTrack()
	notesObject.currentTrackNumber = notesObject.currentTrack:getIndexInParent()
	notesObject.initialTrackName = notesObject.currentTrack:getName()
	notesObject.initialColorTrack = notesObject.currentTrack:getDisplayColor()
	-- Get the current group in the time position
	notesObject.groupSource = notesObject:getGroupRef(notesObject.currentTrack, self.currentSeconds)
	notesObject.tracksColor = notesObject:getTracksColor()
	
    return notesObject
end

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get string format from seconds
function NotesObject:secondsToClock(timestamp)
	return string.format("%02d:%06.3f", 
	  --math.floor(timestamp/3600), 
	  math.floor(timestamp/60)%60, 
	  timestamp%60):gsub("%.",",")
end

-- Create group with data
function NotesObject:createGroup()
	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	self.project:addNoteGroup(noteGroup)
	
	local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	
	return newGrouptRef, noteGroup
end

-- Set new group name with data
function NotesObject:setNewGroupName(noteGroup, groupTag, data)
	noteGroup:setName(groupTag .. "\r" .. data)
end

-- Get previous stored data group
function NotesObject:getPreviousStoredGroup(groupTag)
	local groupStoredRefFound = nil
	local groupStoredFound = nil
	
	for iNoteGroup = 1, self.project:getNumNoteGroupsInLibrary() do
		local group = self.project:getNoteGroup(iNoteGroup)
		if group ~= nil then
			local groupRef = group:getParent()
			if groupRef ~= nil then
				local groupName = group:getName()
				local pos = string.find(groupName, groupTag)
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
	local pos = string.find(data, self.groupTag)
	if pos ~= nil then
		data = string.sub(data, pos + string.len(self.groupTag) + 1)
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
			self.currentTrackColor = self.currentTrackColorRef
		end
		self.currentTrack:setDisplayColor("#" .. self.currentTrackColor)
	end
end

-- Set color for track target
function NotesObject:setTrackTargetColor(track)
	if track ~= nil then
		self.trackTargetColor = self.trackTargetColorRef
		track:setDisplayColor("#" .. self.trackTargetColor)
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

-- Check same groups
function NotesObject:isSameGroup(groupRef)
	local result = false
	if groupRef:getTarget():getNumNotes() == self.groupSource:getTarget():getNumNotes() then
		local lyricsTarget = self:getGroupLyrics(groupRef:getTarget())
		local currentGroupLyrics = self:getGroupLyrics(self.groupSource:getTarget())
		
		if lyricsTarget == currentGroupLyrics then
			result = true
		end
	end
	return result
end

-- get group lyrics
function NotesObject:getGroupLyrics(group)
	local lyrics = ""
	for iNote = 1, group:getNumNotes() do
		lyrics = lyrics .. group:getNote(iNote):getLyrics() .. " "
	end
	return lyrics
end

-- Get not similar notes in target group
function NotesObject:getNotSimilarNotes(group)
	local targetGroupNotes = {}
	local currentTargetGroup = self.groupSource:getTarget()
	for iNote = 1, group:getNumNotes() do
		local noteDiff = false
		if group:getNote(iNote):getOnset() ~= currentTargetGroup:getNote(iNote):getOnset() then
			table.insert(targetGroupNotes, group:getNote(iNote))
			noteDiff = true
			group:getNote(iNote):setOnset(currentTargetGroup:getNote(iNote):getOnset())
		end
		if group:getNote(iNote):getEnd() ~= currentTargetGroup:getNote(iNote):getEnd() then
			if not noteDiff then
				table.insert(targetGroupNotes, group:getNote(iNote))
			end
			group:getNote(iNote):setDuration(currentTargetGroup:getNote(iNote):getDuration())
		end
	end
	return targetGroupNotes
end

-- Main loop
function NotesObject:loop()
	-- local titleTrack = SV:T("Waiting: ")
	local cause = ""
	local isSimilarGroupFound = false
	self.groupFound = {}
	
	self.groupStoredRefToStopPrevious, self.groupStoredToStopPrevious = 
		self:getPreviousStoredGroup(self.groupStopTag)

	if self.groupStoredToStopPrevious ~= nil then
		self.stopProcess = true
	end
	
	if self.stopProcess then
		self:endOfScript()
	else
		-- if a track is deleted by another script or action
		if self.numTracks < self.project:getNumTracks() or not self:isSameGroupSourceNotesCount() then
			self.stopProcess = true
			self:endOfScript()
		else
			SV:setTimeout(10, function() self:setCurrentTrackColor() end)
			self.currentSeconds = self.playBack:getPlayhead()
			self.currentSecondsDisplay = self:secondsToClock(self.currentSeconds)
			-- self.currentTrack:setName(titleTrack .. self.currentSecondsDisplay)
			
			-- Find current group
			self:scanTracks()

			SV:setTimeout(400, function() self:loop() end)
		end			
	end	
end

-- Check if notes count is updated
function NotesObject:isSameGroupSourceNotesCount()
	return self.groupSourceNumNotes == self.groupSource:getTarget():getNumNotes()
end

-- Scan tracks
function NotesObject:scanTracks()
	-- Find current group
	for iTrack = 1, self.numTracks do
		-- Find all tracks except the current one
		if iTrack ~= self.currentTrackNumber then
			local track = self.project:getTrack(iTrack)
			local groupRefTrack = self:getGroupRef(track, self.currentSeconds)
			local isgroupRefTrackFound = (groupRefTrack ~= nil)
			
			if isgroupRefTrackFound then
				local targetGroup = groupRefTrack:getTarget()
				local currentTargetGroup = self.groupSource:getTarget()

				-- Only target groups not synchronized by copy/paste
				if targetGroup:getUUID() ~= currentTargetGroup:getUUID() then
					-- Same group to synchronize
					isSimilarGroupFound = self:isSameGroup(groupRefTrack)
					
					if isSimilarGroupFound then
						if self.trackTargetInit then
							SV:setTimeout(10, function() self:setTrackTargetColor(track) end)
							-- Store initial track & color
							table.insert(self.trackTarget, {iTrack, track, track:getDisplayColor()})
						end
						local groupNotesModified = self:getNotSimilarNotes(targetGroup)
						table.insert(self.groupFound, {iTrack, track, groupRefTrack, groupNotesModified})
					 end
				end
			end
		end
	end
	self.trackTargetInit = false
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

-- Get stored data 
function NotesObject:getStoredData()
	local result = false
	
	-- self.groupTag .. self.sepParam .. |initialTrackName=Track 1
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
			if string.find(data, self.initialTrackNameRef) ~= nil then
				result = true
			end
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

-- Set parameters from stored hidden group
function NotesObject:setParametersFromStoredGroup(paramName, value)
	if string.find(paramName, self.initialTrackNameRef) then
		self.initialTrackName = value
	end
	if string.find(paramName, self.initialColorTrackRef) then
		self.initialColorTrack = value
	end
	if string.find(paramName, self.numTracksRef) then
		self.numTracks = tonumber(value)
	end
	if string.find(paramName,self.currentTrackRef) then
		local iTrack = tonumber(value)
		if iTrack <= self.numTracks then
			self.currentTrack = self.project:getTrack(iTrack)
		else
			self:show(SV:T("Error in stored parameters, try again!"))
			self:stopScript()
		end
	end
	if string.find(paramName, self.tracksColorRef) then
		-- tracksColor=1-fff09c9c,2-fff09c9c
		local tracks = self:split(value, ",")
		
		for iTrack = 1, #tracks do
			local track = self:split(tracks[iTrack], "-")
			table.insert(self.tracksColorStored, {track[1], track[2]})
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

-- Store data to hidden group
function NotesObject:storeToHiddenGroup()
	
	if self.groupStoredFound == nil then
		self.groupStoredRefFound, self.groupStoredFound = self:createGroup()
		local data = self.initialTrackNameRef	.. "=" .. self.initialTrackName		.. self.sepParam
			.. self.initialColorTrackRef		.. "=" .. self.initialColorTrack 	.. self.sepParam
			.. self.numTracksRef				.. "=" .. self.numTracks			.. self.sepParam
			.. self.currentTrackRef				.. "=" .. self.currentTrack:getIndexInParent() .. self.sepParam
			.. self.tracksColorRef				.. "=" .. self.tracksColor
		self:setNewGroupName(self.groupStoredFound, self.groupTag, data)
		
		-- Get this stored data
		self:getStoredData()
	end
end

-- Create groups to stop process
function NotesObject:groupToStopProcess()
	self.groupStoredRefToStopPrevious, self.groupStoredToStopPrevious = self:createGroup()
	self:setNewGroupName(self.groupStoredFound, self.groupStopTag, "STOP")
end

-- Start process
function NotesObject:startProcess()
	self.groupSourceNumNotes = self.groupSource:getTarget():getNumNotes()
	self.groupStoredRefFound, self.groupStoredFound = self:getPreviousStoredGroup(self.groupTag)
	
	-- Previous script process
	if self.groupStoredFound == nil then	
		self:storeToHiddenGroup()
		SV:setTimeout(100, function() self:loop() end)
	else
		local result = self:getStoredData()
		self:groupToStopProcess()
		SV:setTimeout(100, function() self:endOfScript() end)
		
	end
end

-- Main processing task	
function main()
	local notesObject = NotesObject:new()
	if notesObject.groupSource ~= nil then
		notesObject:startProcess()
	else
		notesObject:show(SV:T("No group found in current track and playhead position!"))
	end
end

