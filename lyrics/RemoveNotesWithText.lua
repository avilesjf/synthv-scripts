local SCRIPT_TITLE = 'Remove notes with text V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: RemoveNotesWithText.lua

Remove all notes containing matched lyric or phoneme
Inside the main group and all group of notes
Note: A duplicate track is created to keep source track safe

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Clone current track and delete found notes on this", "Clone current track and delete found notes on this"},
			{"Click Cancel to abort.", "Click Cancel to abort."},
			{"Text", "Text"},
			{"Match phonemes?", "Match phonemes?"},
			{"New Track to export", "New Track to export"},
			{"Removing notes with text in a new track: DONE!", "Removing notes with text in a new track: DONE!"},
			{"Notes deleted: ", "Notes deleted: "},
			{"Removing notes with text in a new track: ERROR!", "Removing notes with text in a new track: ERROR!"},
			{"Notes not deleted: ", "Notes not deleted: "},
			{"No lyric found!", "No lyric found!"},
			{"No phoneme found!", "No phoneme found!"},
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

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	editor = nil,
	track = nil,
	newTrack = nil,
	trackTargetColor = "FFF09C9C",
	defaultText = "br",
	isPhoneme = false,
	notesFound = {},
	textToFind = "",
	groupPhonemes = {},
	notesFoundCount = 0,
	notesDeleted = 0,
	notesUnDeleted = 0
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
	
    return notesObject
end

-- Trim string
function NotesObject:trim(s)
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Quote string
function NotesObject:quote(str)
	return "\""..str.."\""
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

-- Dialog box for search text
function NotesObject:promptForText()
	local resultAction = false

	local waitForm = {
		title = SV:T(SCRIPT_TITLE),
		message = SV:T("Clone current track and delete found notes on this") .. "\r"
				  .. SV:T("Click Cancel to abort."),
		buttons = "OkCancel",
		widgets = {
			{
				name = "text",
				label = SV:T("Text"),
				type = "TextBox",
				default = self.defaultText
			},
			{
				name = "phonemes",
				text = SV:T("Match phonemes?"),
				type = "CheckBox",
				default = false
			}
		}
	}

	local result = SV:showCustomDialog(waitForm)	
	if result.status == true then
		resultAction = true		
		self:start(result)
	else
		resultAction = false
	end
	return resultAction	
end

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Clone track from track reference
function NotesObject:cloneTrack()
	self.newTrack = self.track:clone()
	self.newTrack:setDisplayColor("#" .. self.trackTargetColor)
	self.newTrack:setName(SV:T("New Track to export"))
	self.project:addTrack(self.newTrack)
	return self.newTrack
end

-- Remove notes containing text found
function NotesObject:removeNotes()
	local result = false
	local infos = ""
	self.notesDeleted = 0
	self.notesUnDeleted = 0
	
	for iNote = 1, #self.notesFound do
		if self.notesFound[iNote].notesGroup ~= nil then
			local notesGroup = self.notesFound[iNote].notesGroup
			local indexNote = self.notesFound[iNote].noteIndex
			local lyrics = ""
			if self.notesFound[iNote].note ~= nil then
				lyrics = self.notesFound[iNote].note:getLyrics()
			else
				lyrics = "not found!"
			end
			notesGroup:removeNote(indexNote)
			self.notesDeleted = self.notesDeleted + 1
		else
			self.notesUnDeleted = self.notesUnDeleted + 1
		end
	end	
	
	result = self.notesDeleted > 0
	return result
end

-- Clone groups from source track
function NotesObject:cloneGroupsInNewTrack()
	local newGroups = {}
	local iGroups = self.newTrack:getNumGroups()			
	--[[
		Track
			group reference 1 isMain() timeAxis
				group target 1 getname()
			group reference 2
				group target 1
	-- ]]
	
	-- clone groups from source track
	while iGroups > 1 do
		local groupRef = self.newTrack:getGroupReference(iGroups)
		if groupRef ~= nil then
			local indexGroupRef = groupRef:getIndexInParent()
			local groupRefTimeoffset = groupRef:getTimeOffset()
			local group = groupRef:getTarget()
			
			if not groupRef:isMain() then
				-- Clone target group
				local groupCloned = group:clone()
				self.project:addNoteGroup(groupCloned)
				
				local data = {groupTimeoffset = groupRefTimeoffset, 
					index = indexGroupRef,
					group = groupCloned, 
					isMain = false, groupRef = groupRef}
				table.insert(newGroups, data)
				
				self.newTrack:removeGroupReference(indexGroupRef)
				iGroups = self.newTrack:getNumGroups()			
			end
		end
	end
	
	-- Add main group if notes exists
	local iGoupMain = 1
	local groupRef = self.newTrack:getGroupReference(iGoupMain)
	if groupRef ~= nil then
		local groupRefTimeoffset = groupRef:getTimeOffset()
		local group = groupRef:getTarget()
		
		if group:getNumNotes() > 0 then
			-- Add main group
			local data = {groupTimeoffset = groupRefTimeoffset, 
				index = iGoupMain,
				group = group, 
				isMain = true, groupRef = groupRef}
			table.insert(newGroups, data)
		end
	end
	return newGroups
end

-- get all groups from source track
function NotesObject:getAllGroups()
	local allGroups = {}
	local iGroups = self.track:getNumGroups()			

	-- loop groups linked from source track
	for iGroup = 1, iGroups do
		local groupRef = self.track:getGroupReference(iGroup)
		if groupRef ~= nil then
			local indexGroupRef = groupRef:getIndexInParent()
			local groupRefTimeoffset = groupRef:getTimeOffset()
			local group = groupRef:getTarget()
			
			if group:getNumNotes() > 0 then
				SV:setTimeout(10, function() self:getPhonemesFromGroup(indexGroupRef, groupRef) end)
				
				if not groupRef:isMain() then			
					local data = {groupTimeoffset = groupRefTimeoffset, 
						index = indexGroupRef,
						group = group, 
						isMain = false, groupRef = groupRef}
					table.insert(allGroups, data)
				else
					-- Add main group
					local data = {groupTimeoffset = groupRefTimeoffset, 
						index = indexGroupRef,
						group = group, 
						isMain = true, groupRef = groupRef}
					table.insert(allGroups, data)
				end
			end
		end
	end
	
	return allGroups
end

-- Get phonemes from group
function NotesObject:getPhonemesFromGroup(index, groupRef)
	if self.isPhoneme then
		local data = { index = index, groupRef = groupRef, phonemes = SV:getPhonemesForGroup(groupRef) }
		table.insert(self.groupPhonemes, data)
	end
end

-- Add group reference
function NotesObject:addGroupReference(notesGroup, timeOffset)
	-- Add group reference to project new track
	local newGrouptRef = SV:create("NoteGroupReference", notesGroup)
	-- Adjust time offset
	newGrouptRef:setTimeOffset(timeOffset)
	self.newTrack:addGroupReference(newGrouptRef)
	return newGrouptRef
end

-- Find text in notes
function NotesObject:findTextInNotes(isSearchOnly, notesGroup, indexGroup, groupRef, isMainGroup)
	local iNotes = notesGroup:getNumNotes()
	if iNotes > 0 then

		for iNote = 1, iNotes do
			local note = notesGroup:getNote(iNote)
			local searchText = ""
			local noteIndex = note:getIndexInParent()
			-- index = index, groupRef = groupRef, phonemes = SV:getPhonemesForGroup(groupRef) 
			if self.isPhoneme then
				if #self.groupPhonemes > 0 then
					searchText = self.groupPhonemes[indexGroup].phonemes[noteIndex]						
				end
			else
				searchText = note:getLyrics()
			end
			
			if searchText == self.textToFind then
				if not isSearchOnly then
					local data = {note = note, noteIndex = noteIndex, notesGroup = notesGroup, 
									groupRef = groupRef}
					table.insert(self.notesFound, data)
				end
				self.notesFoundCount = self.notesFoundCount + 1
			end
		end
	end
end

-- Check text exists
function NotesObject:isTextExists()
	local result = false
	local isSearchOnly = true
	self.notesFound = {}
		
	-- Loop all groups
	for iGroup = 1, #self.groups do
		local notesGroup = self.groups[iGroup].group
		local isMainGroup = self.groups[iGroup].isMain
		local groupTimeoffset = self.groups[iGroup].groupTimeoffset
		local newGroupRef = self.groups[iGroup].groupRef
		local index = self.groups[iGroup].index
		local iNotes = notesGroup:getNumNotes()
		
		if iNotes > 0 then
			-- Find text in notes
			self:findTextInNotes(isSearchOnly, notesGroup, index, newGroupRef, isMainGroup)
		end
	end
	
	result = self.notesFoundCount > 0
	
	-- continue processing
	self:processNotes(result)
	
	return result
end

-- Process notes if found
function NotesObject:processNotes(isTextFound)
	
	if isTextFound then
		self:getNotesToRemove()
		self:removeNotes()
	end
	self:endingProcess()
end

-- Get notes to remove
function NotesObject:getNotesToRemove()
	local result = false
	local isSearchOnly = false
	self.notesFound = {}
	self:cloneTrack()
	local newGroups = self:cloneGroupsInNewTrack()
	
	-- Add cloned groups
	for iGroup = 1, #newGroups do
		local notesGroup = newGroups[iGroup].group
		local isMainGroup = newGroups[iGroup].isMain
		local groupTimeoffset = newGroups[iGroup].groupTimeoffset
		local newGroupRef = nil
		local index = newGroups[iGroup].index
		
		if not isMainGroup then
			newGroupRef = self:addGroupReference(notesGroup, groupTimeoffset)
		else
			newGroupRef = newGroups[iGroup].groupRef
		end
		
		-- Find text in notes
		self:findTextInNotes(isSearchOnly, notesGroup, index, newGroupRef, isMainGroup)
	end
	result = self.notesFoundCount > 0
	
	return result
end

-- Delete cloned track 
function NotesObject:deleteClonedTrack()
	local result = false
	if self.newTrack ~= nil then
		local index = self.newTrack:getIndexInParent()
		self.project:removeTrack(index)
		result = true
	end
	return result
end

-- Ending process
function NotesObject:endingProcess()
	-- If text found
	if self.notesFoundCount > 0 then
		-- self:show("self.notesFoundCount: " .. self.notesFoundCount)		
		if self.notesDeleted > 0 then
			self:show(SV:T("Removing notes with text in a new track: DONE!") .. "\r"
				.. SV:T("Notes deleted: ") .. self.notesDeleted)
		else
			self:deleteClonedTrack()
			self:show(SV:T("Removing notes with text in a new track: ERROR!") .. "\r"
				.. SV:T("Notes not deleted: ") .. self.notesUnDeleted)
		end
	else
		local textResult = SV:T("No lyric found!")
		if self.isPhoneme then
			textResult = SV:T("No phoneme found!")
		end
		self:show(textResult)
	end
	
	-- End of script
	SV:finish()
end

-- Main processing task	
function NotesObject:start(dialogResult)
	local result = false
	
	self.textToFind = dialogResult.answers.text
	self.isPhoneme = dialogResult.answers.phonemes
	
	if #self.textToFind > 0 then
		self.groups = self:getAllGroups()
		SV:setTimeout(20, function() self:isTextExists() end)
	else
		self:show(SV:T("Nothing to search!"))
	end
	
	return result
end

-- Main processing task	
function main()
	
	local notesObject = NotesObject:new()
	notesObject:promptForText()	

end
