local SCRIPT_TITLE = 'Clone track with unlinked groups V1.0'

--[[

lua file name: CloneTrackWithGroupsUnlinked.lua

Clone a track and all groups inside.
Unlink all existings groups from original track.
Reproduce existing linked group inside the new track.

2025 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"NEW ", "NEW "},
			{"No groups in this track: ", "No groups in this track: "},
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
	hostinfo = nil,
	osType = "",
	osName = "",
	hostName = "",
	languageCode = "", 
	hostVersion = "",
	hostVersionNumber = 0,
	activeCurrentTrack = nil,
	groupsSelected = nil,
	iTrackNumGroups = 0,
	newTrack = nil,
	groupsLinks = {},
	groupsLinksFound = {},
	traceLog = ""
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
	notesObject.activeCurrentTrack = SV:getMainEditor():getCurrentTrack()
	notesObject.iTrackNumGroups = notesObject.activeCurrentTrack:getNumGroups()
	notesObject.groupsSelected = SV:getArrangement():getSelection():getSelectedGroups()
	
	notesObject.hostinfo = SV:getHostInfo()
	notesObject.osType = notesObject.hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	notesObject.osName = notesObject.hostinfo.osName
	notesObject.hostName = notesObject.hostinfo.hostName
	notesObject.languageCode = notesObject.hostinfo.languageCode
	notesObject.hostVersion = notesObject.hostinfo.hostVersion
	notesObject.hostVersionNumber = notesObject.hostinfo.hostVersionNumber
	
    return notesObject
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Clone track to keep current track voice
function NotesObject:cloneTrackReference()
	local newTrack = self.activeCurrentTrack:clone()		
	local iGroups = newTrack:getNumGroups()
	
	if iGroups > 1 then
		-- Delete groups
		while iGroups > 1 do
			local groupRef = newTrack:getGroupReference(iGroups)
			local index = groupRef:getIndexInParent()
			if groupRef ~= nil and not groupRef:isMain() then
				newTrack:removeGroupReference(index)
				iGroups = newTrack:getNumGroups()
			end
		end
	end
	
	self.project:addTrack(newTrack)

	return newTrack
end

-- Get linked groups
function NotesObject:isGroupExists(notesGroup)
	local groupFound = nil
	if #self.groupsLinks > 0 then
		
		for iGroup = 1, #self.groupsLinks do
			if self.groupsLinks[iGroup].notesGroup:getUUID() == notesGroup:getUUID() then
				result = true
				groupFound = self.groupsLinks[iGroup]
				break
			end
		end
	end
	return groupFound
end

-- Duplicate a track and groups unlined
function NotesObject:duplicateTrack()
	self.iLinkedGroups = 0
	self.newTrack = self:cloneTrackReference()
	self.newTrack:setName(SV:T("NEW ") .. self.activeCurrentTrack:getName())
	
	for iGroup = 1, self.iTrackNumGroups do
		local groupRef = self.activeCurrentTrack:getGroupReference(iGroup)
		
		if not groupRef:isMain() then
			local newNotesGroup = nil
			local groupRefTimeoffset = groupRef:getTimeOffset()
			local notesGroup = groupRef:getTarget()
			
			-- If notesGroup already inserted
			local groupFound = self:isGroupExists(notesGroup)
			
			if groupFound == nil then
				newNotesGroup = notesGroup:clone()
				table.insert(self.groupsLinks, {notesGroup = notesGroup, newNotesGroup = newNotesGroup})

				-- Add note groups to project
				self.project:addNoteGroup(newNotesGroup)
			else
				newNotesGroup = groupFound.newNotesGroup -- Get previous created notes group
			end
			
			-- Add group reference to new track
			local newGrouptRef = SV:create("NoteGroupReference", newNotesGroup)
			-- Adjust time offset
			newGrouptRef:setTimeOffset(groupRefTimeoffset)
			-- Add a new group reference
			self.newTrack:addGroupReference(newGrouptRef)
		end
	end
	-- SV:setHostClipboard(self.traceLog)
end

-- End of process
function NotesObject:endProcess()
	-- End of script
	SV:finish()
end

function main()

	local notesObject = NotesObject:new()
	-- Because of group main: NumGroups = 1
	if notesObject.iTrackNumGroups <= 1 then
		notesObject:show(SV:T("No groups in this track: ") .. notesObject.activeCurrentTrack:getName())
	else
		notesObject:duplicateTrack()
	end
	notesObject:endProcess()
	
end