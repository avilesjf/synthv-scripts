local SCRIPT_TITLE = 'Group Harmony V1.1'

--[[

lua file name: GroupHarmony.lua

Copy selected groups to a new track and transpose all included notes
Add only one track or multiple tracks depending on user selection.

1/	Transpose all notes in current key scale 0..+1 ..+7 (C, D to B)
2/	Display current key scale found in selected group(s) (and current track if different).
3/	A comboBox to choose the desire key scale (if multiple key scale is found for group notes).
4/	A comboBox to choose harmony model.

Degrees I     II     III  IV      V       VI       VII   +I
Major C 1      2      3    4      5        6         7    8
		0     +1     +2   +3     +4       +5        +6   +7
		C  Db  D  Eb  E    F  Gb  G   Ab   A   Bb    B    C
		1  2   3  4   5    6  7   8   9   10   11   12

2024 - JF AVILES
--]]


function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 2,
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
	transposition = { 
		{"1 note", 5, {"+7", "+6", "+5", "+4", "+3", "+2", "+1", "0", "Fixed", "-3", "-5", "-7"}},
		{"2 notes", 2, {"+3,+6", "+3,+5", "+2,+4", "+1,+3", "-3,-5"}},
		{"3 notes", 1, {"+2,+3,+5", "+1,+3,+5"}},
		{"Octaves", 1, {"+3,+5,+7", "+2,+7", "-7"; "-7,+7", "-3,-5,+7"}}
	},
	transpositionRefLabel = 1,
	transpositionRefPosition = 2,
	transpositionRefData = 3,
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
	
	-- Get harmony list
	getHarmonyList = function()
		local resultList = {}
		for iList = 1, #InternalData.transposition do
			table.insert(resultList, InternalData.transposition[iList][InternalData.transpositionRefLabel])
		end
		return resultList
	end,
	
	-- Create user input form
	getForm = function(formId, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
						groupSelected, transposition, transpositionLabel,  posTranposition)
		local comboChoice = {}
		local harmonySelected = ""
		local scaleChoice = {}
		local scaleInfo1 = SV:T("Degrees")   .. "     " .. SV:T("I           II           III    IV          V          VI       VII      +I")
		local scaleInfo2 = SV:T("Major C")   .. "      " .. SV:T("1          2            3      4          5           6          7       8")
		local scaleInfo3 = SV:T("Position")  .. "     " .. SV:T("0        +1         +2    +3       +4        +5        +6    +7")
		local scaleInfo4 = SV:T("Key")       .. "              " .. SV:T("C  Db  D   Eb   E      F  Gb  G  Ab  A  Bb   B      C")
		local scaleInfo5 = SV:T("Half tone") .. "   " .. SV:T("1   2    3     4     5      6   7    8    9   10  11  12   13")
			
		if formId == 0 then
			local harmonyList = commonTools.getHarmonyList()
			comboChoice = {
					  name = "harmonyChoice", type = "ComboBox", label = SV:T("Harmony type"), 
					  choices = harmonyList, default = 0
					}
					
			scaleChoice = {
						name = "scaleKeyChoice", type = "ComboBox", label = SV:T("Key scale"),
						choices = InternalData.keyScaleChoice, default = #InternalData.keyScaleChoice -1
					}
		else
			harmonySelected = SV:T("Transpose mode: ") .. transpositionLabel
			comboChoice = {name = "pitch", type = "ComboBox", label = harmonySelected,
				choices = transposition, default = #transposition - posTranposition}
				
			scaleChoice = {
					name = "scaleKeySelected", type = "TextArea", 
					label = SV:T("Key scale selected: ") .. InternalData.keyScaleFound, 
					height = 0
				}
		end
		
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message = SV:T("Create track and duplicate transposed group of notes") .. "\r" .. SV:T("Groups selected: ") .. #groupSelected,
			buttons = "OkCancel",
			widgets = {
				{
					name = "scaleInfos1", type = "TextArea", label = SV:T("Scale degrees model"),
					height = 90, default = scaleInfo1 .. "\r" .. scaleInfo2 
					.. "\r" .. scaleInfo3 .. "\r" .. scaleInfo4 .. "\r" .. scaleInfo5
				},
				{
					name = "scaleKey", type = "TextArea", 
					label = keyFoundDisplay, 
					height = 0
				},
				scaleChoice,
				comboChoice,
				{
					name = "separator", type = "TextArea", label = "", height = 0
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
			
			local userInput = commonTools.callForms(keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected, 0)
			--if userInput.status then				
			--end
		end
	end,
	
	-- Call dialog forms
	callForms = function(keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected, formId)
		local userInput = nil
		local transposition = nil
		local transpositionLabel = ""
		if formId == 0 then
			-- Selection of action 1 note, 2 notes etc..
			userInput = commonTools.getForm(formId, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
							groupsSelected, transposition, transpositionLabel, 0)
			
			if userInput.status then
				-- call itself to display next dialog box for Harmony selection
				InternalData.keyScaleFound = scaleTools.getkeyScaleChoiceFromPos(userInput.answers.scaleKeyChoice)
				commonTools.callForms(keyScaleFound, keyFoundDisplay, keyScaleFoundTrack,
									groupsSelected, userInput.answers.harmonyChoice + 1)
			end
		else 
			-- harmony selection
			transposition = InternalData.transposition[formId][InternalData.transpositionRefData]
			local defaultPosTransposition = InternalData.transposition[formId][InternalData.transpositionRefPosition]
			transpositionLabel = InternalData.transposition[formId][InternalData.transpositionRefLabel]
			
			userInput = commonTools.getForm(formId, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
							groupsSelected, transposition, transpositionLabel, defaultPosTransposition)
			
			if userInput.status then
				
				-- Duplicate note groups & create tracks
				local numGroups = commonTools.duplicateNotes(groupsSelected, userInput.answers, formId)
			end		
		end
		
		return userInput
	end,
	
	-- Duplicate and transpose notes
	duplicateNotes = function(groupsSelected, userInputAnswer, formId)

		local project = SV:getProject()
		local pitchPosInput = userInputAnswer.pitch
		local pitchTarget = keyTools.getPitchActionFromPos(pitchPosInput, formId)
		
		local isFixed = (pitchTarget == "Fixed")
		local isMultiple = false
		local numGroups = 0
		
		if string.find(pitchTarget, ",") ~= nil then
			isMultiple = true
			pitchTargets = keyTools.split(pitchTarget, ",")
		end
		
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
		
		-- Only one track to add
		if not isMultiple then
			local newGrouptRefs = commonTools.groupLoop(project, groupsSelected, isMultiple, 
														isFixed, pitchTarget, posKeyInScale)
			local newTrack = commonTools.createTrack(project)
			newTrack:setName(SV:T("Track ") .. pitchTarget)
			for iGroupRef = 1, #newGrouptRefs do
				newTrack:addGroupReference(newGrouptRefs[iGroupRef])
				numGroups = numGroups + 1
			end
		else
			-- add multiple tracks
			for iTrack = 1, #pitchTargets do
			
				pitchTarget = pitchTargets[iTrack]
				local newGrouptRefs = commonTools.groupLoop(project, groupsSelected, isMultiple, 
															isFixed, pitchTarget, posKeyInScale)
				local newTrack = commonTools.createTrack(project)
				newTrack:setName(SV:T("Track ") .. pitchTarget)
				for iGroupRef = 1, #newGrouptRefs do
					newTrack:addGroupReference(newGrouptRefs[iGroupRef])
					numGroups = numGroups + 1
				end
			end
		end

		InternalData.logs:showLogs()
		return numGroups
	end,
	
	-- Loop into groups to duplicate & transpose notes
	groupLoop = function(project, groupsSelected, isMultiple, isFixed, pitchTarget, posKeyInScale, newGrouptRefs)
		local newGrouptRefs = {}
		for _, refGroup in pairs(groupsSelected) do
			local groupName = refGroup:getTarget():getName()
			
			-- Ignore main group, only selected groups
			if groupName ~= "main" then
				local noteGroup = refGroup:getTarget()			
				local groupRefTimeoffset = refGroup:getTimeOffset()

				-- Clone source group
				local newNoteGroup = noteGroup:clone()
				local selectedNotes = newNoteGroup:getNumNotes()
				
				if selectedNotes >= 0 then
				
					-- Duplicate transposed notes into a new track to create
					-- Tranpose notes
					local firstNotePitch = newNoteGroup:getNote(1):getPitch()
					for iNote = 1, selectedNotes do
						local note = newNoteGroup:getNote(iNote)			
						local notePitch = scaleTools.getNewPitch(isFixed, firstNotePitch, 
							note:getPitch(), tonumber(pitchTarget), posKeyInScale)
						note:setPitch(notePitch)
					end			
					project:addNoteGroup(newNoteGroup)
					
					-- Add group reference to project new track
					local newGrouptRef = SV:create("NoteGroupReference", newNoteGroup)
					-- Adjust time offset
					newGrouptRef:setTimeOffset(groupRefTimeoffset)
					table.insert(newGrouptRefs, newGrouptRef)
				end
			end
		end
		
		return newGrouptRefs
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
		local octave = 0
		
		-- Octave -1
		if pitchTarget < 0 then
			pitchTarget = 7 + pitchTarget
			octave = -12
		end
		--C  Db D  Eb E    F  Gb  G   Ab  A   Bb   B    C
		--1  2  3  4  5    6  7   8   9  10   11   12
		--0  1  2  3  4    5  6   7   8   9   10   11  
 		--1     2     3    4      5       6         7   8 Major Key C
		
		local noteKey = scaleTools.getKeyFromPitch(notePitch)
		local posKeyInScaleKey = scaleTools.getKeyPosInKeynames(InternalData.keysInScale, noteKey)
		local posTarget = ((posKeyInScaleKey + pitchTarget - 1) % 7) + 1
		local nextKey = InternalData.keysInScale[posTarget]
		
		local gapDegree = scaleTools.getShiftDegrees(pitchTarget, posKeyInScaleKey)	
		local notePitchNew = notePitch + gapDegree + octave
		
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
	getPitchActionFromPos = function(pos, formId)
		return InternalData.transposition[formId][InternalData.transpositionRefData][pos + 1]
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