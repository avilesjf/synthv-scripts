local SCRIPT_TITLE = 'Groups list V1.0'

--[[

lua file name: GroupsList.lua

List all groups in the project
Actions:
	Copy a linked group
	Copy a group unlinked
	Delete a group
	Delete all un referenced groups

2025 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"note", "note"},
			{"Link", "Link"},
			{"not linked", "not linked"},
			{"notes", "notes"},
			{"no notes", "no notes"},
			{"Group: ", "Group: "},
			{">", ">"},
			{"In Track", "In Track"},
			{"measure", "measure"},
			{"pitch", "pitch"},
			{"meas", "meas"},
			{"Select a group to copy!", "Select a group to copy!"},
			{"Tracks", "Tracks"},
			{"Groups notes", "Groups notes"},
			{"Select a group:", "Select a group:"},
			{"Action (copy/delete):", "Action (copy/delete):"},
			{"Copy a linked group", "Copy a linked group"},
			{"Copy a group unlinked", "Copy a group unlinked"},
			{"Delete a group", "Delete a group"},
			{"Delete all un referenced groups", "Delete all un referenced groups"},
			{"Group deleted: ", "Group deleted: "},
			{"No groups in this project!", "No groups in this project!"},
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

-- Define a class "NotesObject"
NotesObject = {
	project = nil,
	timeAxis = nil,
	hostinfo = nil,
	osType = "",
	osName = "",
	hostName = "",
	languageCode = "", 
	hostVersion = "",
	hostVersionNumber = 0,
	numTracks = 0,
	activeCurrentTrack = nil,
	playBack = nil,
	playBackCurrentSeconds = 0,
	numGroups = 0,
	groups = {},
	newTrack = nil,
	groupsLinks = {},
	groupsLinksFound = {},
	maxLenLyrics = 20,
	groupsListChoice = {},
	groupChoice = 0,
	linkedGroup = true,
	deleteGroup = false,
	deleteAllUnReferencedGroups = false,
	traceLog = ""
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
	notesObject.timeAxis = notesObject.project:getTimeAxis()
	notesObject.activeCurrentTrack = SV:getMainEditor():getCurrentTrack()
	notesObject.numGroups = notesObject.project:getNumNoteGroupsInLibrary()
	notesObject.numTracks = notesObject.project:getNumTracks()
	
	notesObject.playBack = SV:getPlayback()
	notesObject.playBackCurrentSeconds = notesObject.playBack:getPlayhead()
	
	notesObject.hostinfo = SV:getHostInfo()
	notesObject.osType = notesObject.hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	notesObject.osName = notesObject.hostinfo.osName
	notesObject.hostName = notesObject.hostinfo.hostName
	notesObject.languageCode = notesObject.hostinfo.languageCode
	notesObject.hostVersion = notesObject.hostinfo.hostVersion
	notesObject.hostVersionNumber = notesObject.hostinfo.hostVersionNumber
	
	-- Get all groups
	notesObject.groups = notesObject:getAllGroups()	
	
    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get all groups in library
function NotesObject:getAllGroups()
	local groups = {}
	
	for iGroup = 1, self.numGroups do
		local group = self.project:getNoteGroup(iGroup)
		local lyrics = self:getGroupLyrics(group)
		
		table.insert(groups, {group = group, lyrics = lyrics, 
							  numNotes = group:getNumNotes(), 
							  groupsRef={}, linked = false})
	end	
	
	-- Update linked groups
	self:linkGroupsReference(groups)
	
	return groups
end

-- Get all groups reference
function NotesObject:linkGroupsReference(groups)
	local result = false
	
	for iTrack = 1, self.numTracks do
		local track = self.project:getTrack(iTrack)
		local numGroupsRef = track:getNumGroups()
		for iGroupRef = 1, numGroupsRef do
			local groupRef = track:getGroupReference(iGroupRef)
			if not groupRef:isMain() then
				self:updateLinkedGroups(groups, groupRef)
			end
		end
		result = true
	end
	return result
end

-- Update linked groups
function NotesObject:updateLinkedGroups(groups, groupRef)
	local result = false
	for iGroup = 1, #groups do
		local storedGroup = groups[iGroup].group
		
		-- Is linked to group notes
		if storedGroup:getUUID() == groupRef:getTarget():getUUID() then
			table.insert(groups[iGroup].groupsRef, groupRef)
			groups[iGroup].linked = true
			result = true
		end
	end
	
	return result
end

-- Get group lyrics
function NotesObject:getGroupLyrics(group)
	local lyrics = ""
	for iNote = 1, group:getNumNotes() do
		local lyricsNote = group:getNote(iNote):getLyrics()
		if #lyrics >= self.maxLenLyrics then
			break
		end
		if self:isTextAccepted(lyricsNote) then
			lyrics = lyrics .. lyricsNote .. " "
		end
	end
	return lyrics
end

-- Is lyrics is a text accepted
function NotesObject:isTextAccepted(lyrics)
	local result = false
	-- Filter char '+' & '++' & '-' & 'br' & ' & .cl & .pau & .sil
	if lyrics ~= "+" and lyrics ~= "++" and lyrics ~= "-" and lyrics ~= "br" and lyrics ~= "'" 
		and lyrics ~= ".cl" and lyrics ~= ".pau" and lyrics ~= ".sil"  then
		result = true
	end	
	return result
end

-- Get groups list
function NotesObject:getGroupsList()
	local result = ""
	
	for iGroup = 1, #self.groups do
		local groupName = self.groups[iGroup].group:getName()
		local lyrics = self.groups[iGroup].lyrics
		local numNotes = self.groups[iGroup].numNotes
		local noteText = numNotes .. " " .. SV:T("note")
		local numLinkedRef = #self.groups[iGroup].groupsRef
		local linkedGroup = self.groups[iGroup].linked
		local linkedText = ""
		
		if numLinkedRef > 0 then
			-- linkedText = " : " .. numLinkedRef .. " " .. SV:T("Link")
			linkedText = ""
		else
			linkedText = " : " .. SV:T("not linked")
		end
		if numNotes > 1 then
			noteText = numNotes .. " " .. SV:T("notes")
		end
		if numNotes == 0 then
			noteText = SV:T("no notes")
		end
		if #lyrics > 0 then
			lyrics = " " .. "(" .. lyrics .. ")"
		end
		
		result = result .. SV:T("Group: ") .. groupName .. linkedText .. "\r"
		.. noteText .. lyrics
		.. "\r"

		-- Get group reference data
		if #self.groups[iGroup].groupsRef > 0 then
			for iGroupRef = 1, numLinkedRef do
				local groupRef = self.groups[iGroup].groupsRef[iGroupRef]
				local track = groupRef:getParent()
				local measure = self.timeAxis:getMeasureAt(groupRef:getOnset()) + 1
				local pitch = groupRef:getPitchOffset()
				
				result = result .. SV:T(">") .. " "
				result = result .. SV:T("In Track") .. " " .. "(" .. track:getIndexInParent() .. ")" .. " " .. track:getName() .. "\r"
				result = result .. "  "
				result = result .. SV:T("measure") .. " " .. measure .. " / " .. SV:T("pitch") .. " " .. pitch.. "\r"
			end
		end
		result = result .. "\r"
	end	
	
	return result
end

-- Get groups list for combo box
function NotesObject:getGroupsListForComboBox()
	local result = false
	self.groupListComboBox = {}

	for iGroup = 1, #self.groups do
		local groupName = self.groups[iGroup].group:getName()
		local lyrics = self.groups[iGroup].lyrics
		local numNotes = self.groups[iGroup].numNotes
		local noteText = numNotes .. " " .. SV:T("note")
		local numLinkedRef = #self.groups[iGroup].groupsRef
		local linkedGroup = self.groups[iGroup].linked
		local linkedText = ""
		
		if numLinkedRef > 0 then
			linkedText = " : " .. numLinkedRef .. " " .. SV:T("Link")
		end
		if numNotes > 1 then
			noteText = numNotes .. " " .. SV:T("notes")
		end
		if numNotes == 0 then
			noteText = "(" .. SV:T("no notes") .. ")"
		end
		if #lyrics > 0 then
			lyrics = " " .. "(" .. lyrics .. ")"
		end
		
		-- groupItem = groupName .. linkedText .. noteText .. lyrics
		groupItem = '"' .. groupName .. '"' .. ": " .. noteText .. lyrics .. " "

		-- Get group reference data
		if #self.groups[iGroup].groupsRef > 0 then
			for iGroupRef = 1, numLinkedRef do
				local groupRef = self.groups[iGroup].groupsRef[iGroupRef]
				local track = groupRef:getParent()
				local measure = self.timeAxis:getMeasureAt(groupRef:getOnset()) + 1
				local pitch = groupRef:getPitchOffset()
				
				groupItem = groupItem .. track:getName() .. " "
				-- groupItem = groupItem .. " (" .. SV:T("meas") .. " " .. measure .. " / " .. SV:T("pitch") .. " " .. pitch .. ") "
				groupItem = groupItem .. " (" .. SV:T("meas") .. " " .. measure .. ") "
			end
		end
		result = true
		
		table.insert(self.groupsListChoice, groupItem)
	end	
	
	return result
end

-- Create user input form
function NotesObject:getForm()

	local form = {
		title = SV:T(SCRIPT_TITLE),
		message = SV:T("Select a group to copy!"),
		buttons = "OkCancel",
		widgets = {
			{
				name = "infos", type = "TextArea", 
				label = SV:T("Tracks"),
				default = self.numTracks .. " " .. SV:T("Tracks") .. ", " .. self.numGroups .. " " .. SV:T("Groups notes"),
				height = 30
			},
			{	name = "groupChoice", type = "ComboBox", label = SV:T("Select a group:"),
				choices = self.groupsListChoice, default = 0
			},
			{	name = "action", type = "ComboBox", label = SV:T("Action (copy/delete):"),
				choices = {
					SV:T("Copy a linked group"), 
					SV:T("Copy a group unlinked"), 
					SV:T("Delete a group"),
					SV:T("Delete all un referenced groups")
					}, default = 0
			},
			{
				name = "separator", type = "TextArea", label = "", height = 0
			}
		}
	}
	return SV:showCustomDialog(form)
end

-- Delete all unreferenced groups
function NotesObject:unReferencedGroupDelete()
	local iDeletedGroups = 0
	for iGroup = 1, #self.groups do
		local notesGroup = self.groups[iGroup].group
		
		if not self.groups[iGroup].linked then
			self.project:removeNoteGroup(notesGroup:getIndexInParent())
			iDeletedGroups = iDeletedGroups + 1
		end
	end
	self:show(SV:T("Group deleted: ") .. iDeletedGroups)
end

-- delete a group of notes
function NotesObject:groupDelete(groupChoice)
	local notesGroup = self.groups[groupChoice].group
	local groupName = notesGroup:getName()
	self.project:removeNoteGroup(notesGroup:getIndexInParent())
	self:show(SV:T("Group deleted: ") .. groupName)
end

-- Add new group reference
function NotesObject:addNewGroupRef(groupChoice, linked)
	local newStartPosition = self.timeAxis:getBlickFromSeconds(self.playBackCurrentSeconds)
	local notesGroup = self.groups[groupChoice].group
	
	if not linked then
		notesGroup = notesGroup:clone()
		-- Add note groups to project
		self.project:addNoteGroup(notesGroup)
	end
	
	local newGrouptRef = SV:create("NoteGroupReference", notesGroup)
	-- Adjust time offset
	newGrouptRef:setTimeOffset(newStartPosition)
	-- Add a new group reference
	self.activeCurrentTrack:addGroupReference(newGrouptRef)
end

-- Start process
function NotesObject:start()
	
	-- local groupList = self:getGroupsList()
	-- self:show(groupList)
	self.deleteGroup = false
	self.deleteAllUnReferencedGroups = false
	
	local groupList = self:getGroupsListForComboBox()
	local userInput = self:getForm()
		
	if userInput.status then
		if userInput.answers.groupChoice ~= nil then
			self.groupChoice  = userInput.answers.groupChoice + 1
			local action = userInput.answers.action
			self.linkedGroup = (action == 0)
			self.deleteGroup = (action == 2)
			self.deleteAllUnReferencedGroups = (action == 3)
			
			-- Delete all un referenced groups
			if self.deleteAllUnReferencedGroups then
				self:unReferencedGroupDelete()
			else
				-- Delete one group selected
				if self.deleteGroup then
					self:groupDelete(self.groupChoice)
				else
					-- Copy group to current track and playback position (linked or unlinked)
					self:addNewGroupRef(self.groupChoice, self.linkedGroup)
				end
			end
		end
	end
end

-- End of process
function NotesObject:endProcess()
	-- End of script
	SV:finish()
end

function main()

	local notesObject = NotesObject:new()
	-- Because of group main: NumGroups = 1
	if #notesObject.groups < 1 then
		notesObject:show(SV:T("No groups in this project!"))
	else
		notesObject:start()
	end
	notesObject:endProcess()
	
end