local SCRIPT_TITLE = 'Group Harmony V1.0'

--[[

lua file name: GroupHarmony.lua

Copy selected groups to a new track and transpose all notes
or update them directly with the transposed notes

1/	Transpose all notes in current key scale 0..+1 ..+6 (C, D to B)
2/	Display current key scale found in selected group(s) (and current track if different).
3/	A comboBox to choose the desire key scale (if multiple key scale is found for group notes).

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
InternalData = {
	keyNames = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"},
	currentKeyNames = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"},
	keysInScale = {},
	relativeKeys = {{"C","Am"},{"Db","Bbm"},{"D","Bm"},{"Eb","Cm"},{"E","C#m"},{"F","Dm"},
				{"Gb","Ebm"},{"G","Em"},{"Ab","Fm"},{"A", "F#m"},{"Bb","Gm"},{"B", "G#m"}},
	transposition = {"+6", "+5", "+4", "+3", "+2", "+1", "0", "Fixed"},
	tonalScale = {2, 2, 1, 2, 2, 2, 1},
	SEP_KEYS = "/",
	keyScaleChoice = {},
	keyScaleFound = "",
	DEBUG = false,
	logs = {
		logs = "",
		add = function(self, new) 
				if InternalData.DEBUG then self.logs = self.logs .. new end
			end,
		clear = function(self) 
					if InternalData.DEBUG then self.logs = "" end
				end,
		showLogs = function(self) 
					if InternalData.DEBUG then 
						SV:showMessageBox(SV:T(SCRIPT_TITLE), self.logs)
					end
				end
	}
}

-- Common tools
commonTools = {
	-- Create a new track
	createTrack = function(project)
		local currenTrack = SV:getMainEditor():getCurrentTrack()
		local newTrack = SV:create("Track")
		newTrackIndex = project:addTrack(newTrack)
		newTrack = project:getTrack(newTrackIndex)
		return newTrack
	end,
	
	-- Create user input form
	getForm = function(keyScaleFound, keyScaleFoundTrack, numGroupsSelected)
		local keyFoundDisplay = SV:T("Scale key found: ") .. keyScaleFound
		InternalData.keyScaleChoice = {}
		
		if keyScaleFound == "" then
			keyFoundDisplay = SV:T("No common scale key found!")
			InternalData.keyScaleChoice = InternalData.keyNames
		else
			InternalData.keyScaleChoice = commonTools.getKeyScaleChoice(keyScaleFound)
			
			if string.len(keyScaleFoundTrack) > 0 then
				if keyScaleFound ~= keyScaleFoundTrack then
					keyFoundDisplay = keyScaleFound .. SV:T(", on track: ") .. keyScaleFoundTrack
				end
			end
		end
		
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message = SV:T("Create track and duplicate transposed group of notes") .. "\r" .. SV:T("Groups selected: ") .. numGroupsSelected,
			buttons = "OkCancel",
			widgets = {
				{
					name = "scaleKey", type = "TextArea", label = keyFoundDisplay, height = 0
				},
				{
					name = "scaleKeyChoice", type = "ComboBox", label = SV:T("Key scale"),
					choices = InternalData.keyScaleChoice, default = #InternalData.keyScaleChoice -1
				},
				{
					name = "pitch", type = "ComboBox", label = SV:T("Pitch transpose"),
					choices = InternalData.transposition, default = #InternalData.transposition -2
				},
				{
					name = "", type = "TextArea", label = "", height = 0
				},
				{
				  name = "createNewTrack", type = "CheckBox", text =  SV:T("Create a new track (Uncheck to update notes!)"), default = true
				}
			}
		}
		return SV:showCustomDialog(form)
	end,
	
	-- get scale Key Found in choice format
	getKeyScaleChoice = function(keyScaleFound)
		local choice = {}
		if string.find(keyScaleFound, InternalData.SEP_KEYS) == nil then
			table.insert(choice, keyScaleFound)
		else
			choice = keyTools.split(keyScaleFound, InternalData.SEP_KEYS)
		end
		return choice
	end,
	
	-- Start to transpose notes
	start = function()
		local maxLengthResult = 30
		local groupsSelected = SV:getArrangement():getSelection():getSelectedGroups()
		InternalData.logs:clear()

		-- Check groups selected
		if #groupsSelected == 0 then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Please select groups first on Arrangement view!"))
		else		
			-- Group selected
			local keyScaleFound = scaleTools.getScale(groupsSelected)
			-- Track notes to check
			local keyScaleFoundTrack = scaleTools.getScaleTrack(groupsSelected)
			
			local userInput = commonTools.getForm(keyScaleFound, keyScaleFoundTrack, #groupsSelected)
			
			if userInput.status then
				local numGroups = commonTools.duplicateNotes(groupsSelected, userInput.answers)
			end
		end
	end,
	
	-- Duplicate and transpose notes
	duplicateNotes = function(groupsSelected, userInputData)

		local project = SV:getProject()
		local pitchPosInput = userInputData.pitch
		local isNewTrackMode = userInputData.createNewTrack
		local pitchTarget = keyTools.getPitchActionFromPos(pitchPosInput)
		local isFixed = (pitchTarget == "Fixed")
		local numGroups = 0 
		InternalData.keyScaleFound = scaleTools.getkeyScaleChoiceFromPos(userInputData.scaleKeyChoice)
		local posKeyInScale = scaleTools.getKeyPosInKeynames(InternalData.keyNames, InternalData.keyScaleFound) -1
		
		InternalData.currentKeyNames = keyTools.copyTable(InternalData.keyNames)
		keyTools.shiftTable(InternalData.currentKeyNames, posKeyInScale)
		InternalData.keysInScale = scaleTools.getKeysInScale(InternalData.currentKeyNames, InternalData.keyScaleFound)
		
		if string.len(InternalData.keyScaleFound) == 0 then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Error: No scale key found!"))
			return -1
		end
		if posKeyInScale < 0 then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Error: Position into scale error!"))
			return posKeyInScale
		end
		
		for _, refGroup in pairs(groupsSelected) do
			local groupName = refGroup:getTarget():getName()
			
			-- Ignore main group, only selected groups
			if groupName ~= "main" then
				local noteGroup = refGroup:getTarget()			
				local groupRefTimeoffset = refGroup:getTimeOffset()
				
				-- Duplicate transposed notes into a new track to create
				if isNewTrackMode then
					-- Clone source group
					local newNoteGroup = noteGroup:clone()
					local selectedNotes = newNoteGroup:getNumNotes()
					
					if selectedNotes >= 0 then
						-- Tranpose notes
						local firstNotePitch = newNoteGroup:getNote(1):getPitch()
						for iNote = 1, selectedNotes do
							local note = newNoteGroup:getNote(iNote)			
							local notePitch = scaleTools.getNewPitch(isFixed, firstNotePitch, note:getPitch(), tonumber(pitchTarget), posKeyInScale)
							note:setPitch(notePitch)
						end			
						project:addNoteGroup(newNoteGroup)
						
						-- Add group reference to project new track
						local newGrouptRef = SV:create("NoteGroupReference", newNoteGroup)
						-- Adjust time offset
						newGrouptRef:setTimeOffset(groupRefTimeoffset)
						
						local newTrack = commonTools.createTrack(project)
						newTrack:setName(SV:T("Track ") .. pitchTarget)					
						newTrack:addGroupReference(newGrouptRef)
						numGroups = numGroups + 1
					end
				else
					-- Update notes in selected groups
					local selectedNotes = noteGroup:getNumNotes()
					if selectedNotes >= 0 then
						-- Tranpose notes
						local firstNotePitch = noteGroup:getNote(1):getPitch()
						for iNote = 1, selectedNotes do
							local note = noteGroup:getNote(iNote)			
							local notePitch = scaleTools.getNewPitch(isFixed, firstNotePitch, note:getPitch(), tonumber(pitchTarget), posKeyInScale)
							note:setPitch(notePitch)
						end			
						
						numGroups = numGroups + 1
					end					
				end
			end
		end
		InternalData.logs:showLogs()
		return numGroups
	end
}

-- Scale tools
scaleTools = {
	--- Pitch note is in scale
	isInScale = function(pitch, scale)
		local usekey = {0, 2, 4, 5, 7, 9, 11}
		local inScale = false
		for key = 1, #usekey do
			if pitch % 12 == (usekey[key] + scale) % 12 then
				inScale = true
				break
			end
		end
		return inScale
	end,
	
	--- Key note is in scale
	isKeyInScale = function(keyPos)
		local usekey = {0, 2, 4, 5, 7, 9, 11}
		local inScale = false
		for key = 1, #usekey do
			if usekey[key] == keyPos then
				inScale = true
				break
			end
		end
		return inScale
	end,

	--- GetScale in current track
	getScaleTrack = function(groupsSelected)
		return scaleTools.getScale(groupsSelected,  "track")
	end,
	
	--- GetScale
	getScale = function(groupsSelected, paramTrack)
		local groupOrTrackNotes = "None"
		local scaleFound = ""
		local notes = {}
		local sep = ""
		local trackinfos = ""
		
		if paramTrack == "track" then
			-- Use current track
			groupOrTrackNotes = "Track"
			local currentTrack = SV:getMainEditor():getCurrentTrack()
			-- Loop through groups in track
			local numGroups = currentTrack:getNumGroups()
			local refGroupTrack
			trackinfos = SV:T("Groups (") .. numGroups .. ")"
			for grp = 1, numGroups do
				refGroupTrack = currentTrack:getGroupReference(grp)
				scaleTools.addNotes(notes, refGroupTrack)
				-- InternalData.logs:add(SV:T("Group: ") .. refGroupTrack:getTarget():getName() .. ": " .. refGroupTrack:getTarget():getNumNotes() .. "\r")
			end
		else
			-- Groups selected
			if #groupsSelected > 0 then
				groupOrTrackNotes = SV:T("Groups (") .. #groupsSelected .. ")"
				for _, group in pairs(groupsSelected) do
					scaleTools.addNotes(notes, group)
				end
			else
				SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No group selected!"))
			end
		end
		InternalData.logs:add(SV:T("Group or track: ") .. groupOrTrackNotes .. SV:T(", notes count:") .. #notes .. " " .. trackinfos)
		
		-- loop each scales
		for key = 1, #InternalData.keyNames do
			local isInScale = false
			local posKeyInScale = key - 1
			
			-- Loop on pitch notes
			isInScale = scaleTools.loopNotes(notes, posKeyInScale, InternalData.keyNames, key)
			if isInScale then
				-- scale found
				scaleFound = scaleFound .. sep .. InternalData.keyNames[key]
				InternalData.logs:add(SV:T("key: ") .. InternalData.keyNames[key] .. " " .. SV:T("YES") .. "\r")
				sep = InternalData.SEP_KEYS
				--break
			end
		end		
		-- InternalData.logs:showLogs()
		return scaleFound
	end,
	
	-- Append notes from group
	addNotes = function(notes, refGroup)
		-- Check group type
		if not refGroup:isInstrumental() then
			local notesGroup = refGroup:getTarget()
			-- Store group notes
			for note = 1, notesGroup:getNumNotes() do
				local pitchNote = notesGroup:getNote(note):getPitch()
				if pitchNote ~= nil then
					table.insert(notes, pitchNote)
				end
			end
		end
	end,
	
	-- Get new pitch in key scale
	getNewPitch = function(isFixed, firstNotePitch, notePitch, pitchTarget, posKeyInScale)
		if isFixed then 
			-- Fix all notes from the first note found
			notePitch = firstNotePitch
		else
			notePitch = scaleTools.getNextKeyInScale(InternalData.keyScaleFound, notePitch, pitchTarget)
		end
		return notePitch
	end,
	
	-- Get next valid key in scale
	getNextKeyInScale = function(keyScaleFound, notePitch, pitchTarget)		
		
		if pitchTarget > #InternalData.keysInScale then
			SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Pitch value is too much for the key: ") .. keyScaleFound)
		end
		
		local noteKey = scaleTools.getKeyFromPitch(notePitch)
		local posKeyInScaleKey = scaleTools.getKeyPosInKeynames(InternalData.keysInScale, noteKey)
		local posTarget = ((posKeyInScaleKey + pitchTarget - 1) % 7) + 1		
		local nextKey = InternalData.keysInScale[posTarget]
		--local posNextKeyInScaleKey = scaleTools.getKeyPosInKeynames(InternalData.keysInScale, nextKey)
		
		local gapDegree = scaleTools.getShiftDegrees(pitchTarget, posKeyInScaleKey)	
		local notePitchNew = notePitch + gapDegree
		
		InternalData.logs:add("" .. notePitch .. " / " .. notePitchNew .. ", gap: " .. gapDegree
		.. ", posKey: " .. posKeyInScaleKey .. ", pitch/pos: " .. pitchTarget	.. " / " .. posTarget
		.. ", Key: " .. noteKey .. " / " .. nextKey	.. "\r"
		)
		
		return notePitchNew
	end,
	
	-- Get shifted degrees
	getShiftDegrees = function(pitchTarget, posKeyInScaleKey)
		local shift = 0
		if pitchTarget > 0 then
			for key = 1, pitchTarget do
				-- add all gaps to get shifting note
				local dec = (posKeyInScaleKey + key - 2) % 7 + 1
				shift = shift + InternalData.tonalScale[dec]
			end
		end
		return shift
	end,
	
	-- Get key pitch
	getKeyFromPitch = function(notePitch)
		local pitchPos = notePitch % 12
		return InternalData.keyNames[pitchPos + 1]
	end,
	
	-- loop for each notes
	loopNotes = function(notes, posKeyInScale, keyNames, key)
		local isInScale = false
		-- loop all notes
		for note = 1, #notes do
			local notePitch = notes[note]
			if notePitch ~= nil then
				isInScale = scaleTools.isInScale(notePitch, posKeyInScale)
				if not isInScale then
					-- InternalData.logs:add(SV:T("pitch: ") .. InternalData.keyNames[(notePitch % 12) + 1] .. SV:T(", key: ") ..  InternalData.keyNames[key] .. " " .. SV:T("NOT"))
					break
				end
			end
		end
		return isInScale
	end,
	
	-- Get key position in Keynames
	getKeyPosInKeynames = function(keyNames, keyfound)
		local posKeyInScale = -1
		-- loop each scales
		for key = 1, #keyNames do
			if keyfound == keyNames[key] then
				posKeyInScale = key
				break
			end
		end
		return posKeyInScale
	end,
	
	-- Get key scale found from position InternalData.keyScaleChoice
	getkeyScaleChoiceFromPos = function(scaleKeyPosInput)
		local keyScaleFound = ""
		for iPos = 1, #InternalData.keyScaleChoice do
			if scaleKeyPosInput == iPos -1 then
				keyScaleFound = InternalData.keyScaleChoice[iPos]
			end
		end
		return keyScaleFound
	end,
	
	-- Get keys in scale
	getKeysInScale = function(currentKeyNames, keyScaleFound)
		local keysInScale = {}
		for key = 1, #currentKeyNames do
			if scaleTools.isKeyInScale(key-1) then
				table.insert(keysInScale, currentKeyNames[key])
			end
		end
		return keysInScale
	end
	
}

-- Key tools
keyTools = {

	-- Get Key from minor to major
	getKeyMinToMaj = function(key)
		local arrKeys = InternalData.relativeKeys
		
		for iMaj, kMin in pairs(arrKeys) do
			if key == kMin[2] then
				keyResult = kMin[1]
			end
		end	
		return keyResult
	end,

	-- Get Key from major to minor
	getKeyMajToMinor = function(key)
		local arrKeys = InternalData.relativeKeys
		
		for iMaj, kMin in pairs(arrKeys) do
			if key == kMin[1] then
				keyResult = kMin[2]
			end
		end	
		return keyResult
	end,

	-- Get pitch action from position
	getPitchActionFromPos = function(pos)
		return InternalData.transposition[pos + 1]
	end,
	
	-- Split string by sep char
	split = function(str, sep)
		local result = {}
		local regex = ("([^%s]+)"):format(sep)
		for each in str:gmatch(regex) do
			table.insert(result, each)
		end
		return result
	end,
	
	-- Rotate table content
	shiftTable = function(tInput, num)
		for iPos = 1, math.abs ( num ) do
			if num < 0 then
				table.insert ( tInput, 1, table.remove ( tInput ) )
			else
				table.insert ( tInput, table.remove ( tInput, 1 ) )
			end
		end
	end,
	
	-- duplicate table
	copyTable = function(tInput)
		local tOutput = {}
		for k, v in pairs(tInput) do
			table.insert(tOutput, k, v)
		end
		return tOutput
	end
	
}

function main()
	commonTools.start()
	SV:finish()
end