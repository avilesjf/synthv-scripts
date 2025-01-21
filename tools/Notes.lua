local SCRIPT_TITLE = 'Notes for project V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: Notes.lua

Store & display internal project notes

Remark:
Store notes inside the project (into an non visible group):
Set variable isInternalGroup = true

Store notes in external file:
To disable it:
Set variable isFileStored = false 

Warning!
Nothing is done (stored) if both variables:
isFileStored & isInternalGroup => false
But set to true for both variable is possible:
=> saved to external file & inside the project (hidden group).

2024 - JF AVILES
--]]

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
	noteTag = "ProjectNotes:",
	projectFileName = "",
	notesFileName = "",
	numTracks = 0,
	notesGroupRef = nil,
	notesGroup = nil,
	noteInfo = "",
	isInternalGroup = false, -- Save to hidden group inside .svp project
	isFileStored = true -- Save to external .txt file same folder than the .svp project
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
	notesObject.numTracks = notesObject.project:getNumTracks()
	notesObject.projectFileName = notesObject.project:getFileName()
	notesObject.notesFileName = notesObject:getNotesFilePath(notesObject.projectFileName)
	
    return notesObject
end

-- Get notes file path
function NotesObject:getNotesFilePath(projectFileName)
	local notesFileName = projectFileName
	-- Update filename extension
	notesFileName = notesFileName:gsub("%.svp",".txt")
	return notesFileName
end

-- Save notes to text file
function NotesObject:saveNotesToTextFile(notes)
	local fo, errMessage = io.open(self.notesFileName, "w")
	if fo then
	  fo:write(notes)
	  fo:close()
	else
	  self.show(SV:T("Unable to save notes:") .. "\r" .. errMessage)
	end
end

-- Read notes from text file
function NotesObject:readNotesFromTextFile()
	local notes = ""
	local fhandle = io.open(self.notesFileName, 'r')
	
	if fhandle ~= nil then
		-- Read file
		notes = fhandle:read("*a")
		io.close(fhandle)
	end
	return notes
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

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Create group with notes
function NotesObject:createGroup()
	-- Create new group 
	local noteGroup = SV:create("NoteGroup")
	self.project:addNoteGroup(noteGroup)
	
	local newGrouptRef = SV:create("NoteGroupReference", noteGroup)
	
	return newGrouptRef, noteGroup
end

-- Set new group name with notes
function NotesObject:setNewGroupName(noteGroup, notes)
	noteGroup:setName(self.noteTag .. "\r" .. notes)
end

-- Get group with project notes
function NotesObject:getNotesFromGroup()
	local groupRefFound = nil
	local groupFound = nil
	
	for iNoteGroup = 1, self.project:getNumNoteGroupsInLibrary() do
		local group = self.project:getNoteGroup(iNoteGroup)
		if group ~= nil then
			local groupRef = group:getParent()
			if groupRef ~= nil then
				local groupName = group:getName()
				local pos = string.find(groupName, self.noteTag)
				
				if pos ~= nil then 
					groupRefFound = groupRef
					groupFound = group
					break
				end
			end
		end
	end
	return groupRefFound, groupFound
end

-- Get notes content
function NotesObject:getNotesContent(notes)
	local notesContent = notes
	local pos = string.find(notesContent, self.noteTag)
	if pos ~= nil then
		notesContent = string.sub(notesContent, pos + string.len(self.noteTag) + 1)
	end
	return notesContent
end

-- Trim string
function NotesObject:trim(s)
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
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

-- Show custom dialog box
function NotesObject:showForm(title, notes)
	local form = {
		title = SV:T(SCRIPT_TITLE),
		message = title,
		buttons = "OkCancel",
		widgets = {
			{
				name = "notes", type = "TextArea", label = SV:T("Project notes:"),
				height = 400,
				default = notes
			},
			{
				name = "separator", type = "TextArea", label = "", height = 0
			}
		}
	}
	self.dialogTitle = title
	self.onResponse = function(response) self:dialogResponse(response) end
	return SV:showCustomDialog(form)
end

-- Start project notes processing
function NotesObject:start()
	local title = SV:T("Project notes! Click OK button to save notes!")
	
	if self.isFileStored then
		self.noteInfo = self:readNotesFromTextFile()
	end
	
	if self.isInternalGroup then
		local groupRefFound, groupFound = self:getNotesFromGroup()
		
		if groupFound == nil then
			self.notesGroupRef, self.notesGroup = self:createGroup()
			self:setNewGroupName(self.notesGroup, self.noteInfo)
		else		
			self.noteInfo = self:getNotesContent(groupFound:getName())
			self.notesGroup = groupFound
			self.notesGroupRef = groupRefFound
		end
	end
	
	local userInput = self:showForm(title, self.noteInfo)		
	if userInput.status then
		self.noteInfo = userInput.answers.notes
		if self.isInternalGroup then
			self:setNewGroupName(self.notesGroup, self.noteInfo)
		end
		
		if self.isFileStored then
			self:saveNotesToTextFile(self.noteInfo)
		end
	end
end

-- Main processing task	
function main()	
	local notesObject = NotesObject:new()
	if string.len(notesObject.notesFileName)>0 then
		notesObject:start()
	else
		notesObject:show(SV:T("Unable to store notes in an unnamed .svp project!"))
	end
	
	-- End of script
	SV:finish()
end
