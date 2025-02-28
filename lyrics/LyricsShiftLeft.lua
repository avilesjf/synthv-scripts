local SCRIPT_TITLE = 'Lyrics shift all text to previous left notes V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: LyricsShiftLeft.lua

Lyrics shift all text to previous left notes

Warning!
Lyrics on previous left note will be lost!

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"newLyrics: ", "newLyrics: "},
			{"No notes found to shift!", "No notes found to shift!"},
			{"No note selected!", "No note selected!"},
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
	editor = nil,
	selection = nil,
	selectedNotes = {},
	hasSelectedNotes = false,
	lastNote = nil,
	indexParent = 0,
	notesGroupRef = nil,
	notesGroup = nil,
	newStartLyrics = "-"
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    notesObject.project = SV:getProject()
	notesObject.editor = SV:getMainEditor()
	notesObject.selection = notesObject.editor:getSelection()
	notesObject.selectedNotes = notesObject.selection:getSelectedNotes()
	notesObject.hasSelectedNotes = notesObject.selection:hasSelectedNotes()
	
	if notesObject.hasSelectedNotes then
		notesObject.lastNote = notesObject.selectedNotes[#notesObject.selectedNotes]
		notesObject.notesGroup = notesObject.lastNote:getParent()
		notesObject.indexParent = notesObject.lastNote:getIndexInParent()
	end
	
    return notesObject
end

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Trim string
function NotesObject:trim(s)
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Find all next notes
function NotesObject:nextNotes()
	local nextNotes = {}
	local numNotes = self.notesGroup:getNumNotes()
	
	for iNote = 1, numNotes do
		local note = self.notesGroup:getNote(iNote)
		if note:getIndexInParent() >= self.indexParent - 1 then
			table.insert(nextNotes, note)
		end
	end
	return nextNotes
end

-- Shift lyrics to next notes
function NotesObject:shiftLyrics(nextNotes)
	local result = ""
	
	for iNote = 1, #nextNotes do
		if iNote == #nextNotes then
			-- Set the new lyrics for the last shifted note
			nextNotes[iNote]:setLyrics(self.newStartLyrics)
		else
			nextNotes[iNote]:setLyrics(nextNotes[iNote + 1]:getLyrics())
		end
		result = result .. nextNotes[iNote]:getLyrics() .. " "
	end
	
	return self:trim(result)
end

-- Start project notes processing
function NotesObject:start()
	
	-- Find all next notes
	local nextNotes = self:nextNotes()
	
	if #nextNotes > 0 then
		-- Shift lyrics to next notes
		local newLyrics = self:shiftLyrics(nextNotes)
		-- self:show(SV:T("newLyrics: ") .. newLyrics)
	else
		self:show(SV:T("No notes found to shift!"))
	end
end

-- Main processing task	
function main()	
	local notesObject = NotesObject:new()
	if notesObject.hasSelectedNotes then
		notesObject:start()
	else
		notesObject:show(SV:T("No note selected!"))
	end
	
	-- End of script
	SV:finish()
end
