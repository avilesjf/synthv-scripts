local SCRIPT_TITLE = 'Group Harmony V1.5'

--[[

lua file name: GroupHarmony.lua

Copy selected groups to a new track and transpose all included notes
Add only one track or multiple tracks depending on user selection.

1/ Transpose all notes in current key scale 0..+1 ..+7 (C, D to B)
2/ Display current key scale found in selected group(s) (and current track if different)
3/ A comboBox to choose the desire key scale (if multiple key scale is found for group notes)
4/ A comboBox to choose harmony model
5/ A special case to input and build user model (input text: +3,+6,-4 etc.)
6/ Add scale key type (Major, Natural Minor, Melodic Minor etc..
7/ Adding a lower output level slider for new generated track loudness
8/ Adding a max random pitch offset to add a time gap
9/ Use current track to duplicate new track (template to keep voice set)
10/ Random pitch deviation to impact (in %) automation pitch

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
		category = "_JFA_Groups",
		author = "JFAVILES",
		versionNumber = 5,
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
		{SV:T("1 note"), 5, {"+7", "+6", "+5", "+4", "+3", "+2", "+1", "0", "Fixed", "-3", "-5", "-7"}},
		{SV:T("2 notes"), 2, {"+3,+6", "+3,+5", "+2,+4", "+1,+3", "-3,-5"}},
		{SV:T("3 notes"), 1, {"+2,+3,+5", "+1,+3,+5"}},
		{SV:T("Octaves"), 1, {"+3,+5,+7", "+2,+7", "-7"; "-7,+7", "-3,-5,+7"}},
		{SV:T("Build your own"), 1, {"+0"}}
	},
	transpositionRefLabel = 1,
	transpositionRefPosition = 2,
	transpositionRefData = 3,
	isOnlyOneKeyFound = false,
	posKeyInScaleForm = 0,
    allScales = {
			-- KeyScale type, Intervals, Gaps between degrees (for info only, not used)
			{SV:T("Major"),			{0,2,4,5,7,9,11,12}, {2, 2, 1, 2, 2, 2, 1}},
			{SV:T("Natural Minor"),	{0,2,3,5,7,8,10,12}, {2, 1, 2, 2, 1, 2, 2}},
			{SV:T("Melodic Minor"),	{0,2,3,5,7,9,11,12}, {2, 1, 2, 2, 2, 2, 1}},
			{SV:T("Harmonic Minor"),{0,2,3,5,7,8,11,12}, {2, 1, 2, 2, 1, 2, 1}},
			{SV:T("Ionian"),		{0,2,4,5,7,9,11,12}, {2, 2, 1, 2, 2, 2, 1}},
			{SV:T("Dorian"),		{0,2,3,5,7,9,10,12}, {2, 1, 2, 2, 2, 1, 2}},
			{SV:T("Phrygian"),		{0,1,3,5,7,8,10,12}, {1, 2, 2, 2, 1, 2, 2}},
			{SV:T("Locrian"),		{0,1,3,5,6,8,10,12}, {1, 2, 2, 1, 2, 2, 2}},
			{SV:T("Lydian"),		{0,2,4,6,7,9,11,12}, {2, 2, 2, 1, 2, 2, 1}},
			{SV:T("Mixolydian"),	{0,2,4,5,7,9,10,12}, {2, 2, 1, 2, 2, 1, 2}},
			{SV:T("Aeolian"),		{0,2,3,5,7,8,10,12}, {2, 1, 2, 2, 1, 2, 2}},
			{SV:T("Locrian"),		{0,1,3,5,6,8,10,12}, {1, 2, 2, 1, 2, 2, 2}},
			{SV:T("Blues Major"),	{0,2,3,4,7,9,12},	 {2, 1, 1, 3, 2, 3}},
			{SV:T("Blues Minor"),	{0,3,5,6,7,10,12},	 {3, 2, 1, 1, 3, 2}},
			{SV:T("Japanese"),		{0,1,5,7,8,12},		 {1, 4, 2, 1, 5}},
			{SV:T("Chinese"),		{0,2,4,7,9,12},		 {2, 4, 3, 2, 3}}, 
			{SV:T("Chinese 2"),		{0,4,6,7,11,12},	 {4, 2, 1, 5, 1}},
			{SV:T("Indian"),		{0,1,3,4,7,8,10,12}, {1, 2, 1, 3, 1, 2, 2}},
			{SV:T("Hungarian major"),{0,3,4,6,7,9,10,12}, {3, 1, 2, 1, 2, 1, 2}}
		},
	SEP_KEYS = "/",
	keyScaleChoice = {},
	relativeMinorScalekeysChoice = {},
	relativeMinorScalekeys = "",
	keyScaleFound = "",
	keyScaleTypeFound  	 = 1, -- for Major
	keyScaleTypeTitleFound  = SV:T("Major"),
	keyScaleTypeValuesFound = {0,2,4,5,7,9,11,12},
	harmonyChoice = 0,
	trackNameHarmony = SV:T("Track H"),
	isTrackClone = false,
	currentTrack = nil,
	newTrackRef = nil,
	randomSeedActive = false,
	randomSeedValue = 42,
	pitchDeviation = 0,
	tracks = {},
	trackListChoice = {},
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
						commonTools.show(self.logs)
					end
				end
	}
}

-- Common tools
commonTools = {
	-- Display message box: commonTools.show()
	show = function(message)
		SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
	end,
	
	-- Create a new track
	createTrack = function(project)
		local newTrack = SV:create("Track")
		project:addTrack(newTrack)
		-- local newTrackIndex = project:addTrack(newTrack)
		-- newTrack = project:getTrack(newTrackIndex)
		return newTrack
	end,

	-- Clone track from track reference
	cloneTrack = function(project)		
		local newTrack = InternalData.newTrackRef:clone()
		project:addTrack(newTrack)
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
	
	--- Get track list
	getTracksList = function()		
		local list = {}
		local project = SV:getProject()
		local formatCount = "%3d"
		local iTracks = project:getNumTracks()
		
		for iTrack = 1, iTracks do
			local track = project:getTrack(iTrack)
			local mainGroupRef = track:getGroupReference(1) -- main group
			local groupNotesMain = mainGroupRef:getTarget()
			local numGroups = track:getNumGroups() - 1
			local format = formatCount .. " " .. SV:T("groups")
			if numGroups < 2 then
				format = formatCount .. " " .. SV:T("group")
			end
			table.insert(list, track:getName() .. " (" .. string.format(format, numGroups) .. ")" )
		end
		return list
	end,

	-- Get scales title
	getScalesTitle = function()
		local scales = {}
		for iScale = 1, #InternalData.allScales do
			table.insert(scales, 
				InternalData.allScales[iScale][1]
			)
			
		end
		return scales
	end,
	
	-- Get scale from title
	getScaleFromTitle = function(scaleSearch)
		local scale = {}
		for iScale = 1, #InternalData.allScales do
			if scaleSearch == InternalData.allScales[iScale][1] then
				scale = InternalData.allScales[iScale]
			end
		end
		return scale
	end,
	
	-- Create user input form
	getForm = function(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
						groupSelected, transposition, transpositionLabel,  posTranposition)
		local comboChoice = {}
		local scaleKeyType = {}
		local harmonySelected = ""
		local scaleChoice = {}
		local scaleInfo1 = SV:T("Degrees")   .. "     " .. 	SV:T("I           II           III    IV          V          VI       VII      +I")
		local scaleInfo2 = SV:T("Major C")   .. "      " .. SV:T("1          2            3      4          5           6          7       8")
		local scaleInfo3 = SV:T("Key")       .. "              " .. SV:T("C  Db  D   Eb   E      F  Gb  G  Ab  A  Bb   B      C")
		local newTimeGap = 0
		local sliderTimeGap = ""
		local sliderLoudness = ""
		local timeGapDefaultValue = 20
		local timeGapMinValue =  0
		local timeGapMaxValue =  50
		local timeGapInterval =  1
		local outputLevelDefaultValue = 0
		local outputLevelMinValue = -10
		local outputLevelMaxValue = 2
		local outputLevelInterval = 1
		local pitchDeviationDefaultValue = 20
		local pitchDeviationMinValue = 0
		local pitchDeviationMaxValue = 100
		local pitchDeviationInterval = 5
		local trackListCombo = ""
		local defaultKeyPos = 0
		local trackClone = ""
		local pitchInfos = ""
		local pitchDeviation = ""
		
		if isFirst then
			
			local harmonyList = commonTools.getHarmonyList()
			
			if InternalData.isOnlyOneKeyFound then
				defaultKeyPos = InternalData.posKeyInScaleForm
			end

			scaleChoice = {
				name = "scaleKeyChoice", type = "ComboBox", label = SV:T("Select a key scale"),
				choices = InternalData.keyScaleChoice, default = defaultKeyPos
			}
			
			scaleKeyType = {
				name = "scaleKeyType", type = "ComboBox", label = SV:T("Key scale type"),
				choices = commonTools.getScalesTitle(), default = 0
			}
			
			comboChoice = {
				name = "harmonyChoice", type = "ComboBox", label = SV:T("Harmony type"), 
				choices = harmonyList, default = 0
			}
		else
			harmonySelected = SV:T("Transpose mode: ") .. transpositionLabel
			if transpositionLabel == "Build your own" then
				comboChoice = {
					name = "pitchText", type = "TextBox",
					label = SV:T("Input notes (+3, +5, +7 etc..):"),
					default = ""
				}

			else
				comboChoice = {name = "pitch", type = "ComboBox", label = harmonySelected,
								choices = transposition, default = #transposition - posTranposition}
			end
			
			scaleKeyType = {
				name = "scaleKeyType", type = "TextArea", 
				label = SV:T("Key scale type selected: ") .. InternalData.keyScaleTypeTitleFound, 
				height = 0
			}
			
			scaleChoice = {
				name = "scaleKeySelected", type = "TextArea", 
				label = SV:T("Key scale selected: ") .. InternalData.keyScaleFound, 
				height = 0
			}
			
			trackClone = {
				name = "isTrackClone",
				text = SV:T("Use current track as a source voice for new tracks"),
				type = "CheckBox",
				default = false
			}
			
			pitchInfos = {
				name = "infos", type = "TextArea", 
				label = SV:T("Please note that new random pitch shift only works") .. "\r" 
					.. SV:T("if the selected notes are in manual mode!"), 
				height = 0
			}

			sliderLoudness = {
				name = "loudnessHarmony", type = "Slider",
				label = SV:T("Lower output level for new harmony groups"),
				format = "%3.0f",
				minValue = outputLevelMinValue, 
				maxValue = outputLevelMaxValue, 
				interval = outputLevelInterval, 
				default = outputLevelDefaultValue
			}

			sliderTimeGap = {
				name = "newTimeGap", type = "Slider",
				label = SV:T("Max random pitch offset (default time shift +-20 ms)"),
				format = "%3.0f",
				minValue = timeGapMinValue, 
				maxValue = timeGapMaxValue, 
				interval = timeGapInterval, 
				default = timeGapDefaultValue
			}

			pitchDeviation = {
				name = "newPitchDeviation", type = "Slider",
				label = SV:T("Random pitch deviation tuning (default +-10%)"),
				format = "%3.0f",
				minValue = pitchDeviationMinValue, 
				maxValue = pitchDeviationMaxValue, 
				interval = pitchDeviationInterval, 
				default = pitchDeviationDefaultValue
			}
			
			-- is not multiple tracks
			if InternalData.harmonyChoice == 1 then
				InternalData.tracks = commonTools.getTracksList()
				InternalData.trackListChoice = InternalData.tracks
				table.insert(InternalData.trackListChoice, SV:T("New track")) -- default choice
				
				trackListCombo = {name = "trackChoice", type = "ComboBox", label = SV:T("Select destination track:"),
								choices = InternalData.trackListChoice, default = #InternalData.trackListChoice - 1}
			end
		end
		
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message = SV:T("Create track and duplicate transposed group of notes") .. "\r" .. SV:T("Groups selected: ") .. #groupSelected,
			buttons = "OkCancel",
			widgets = {
				{
					name = "scaleInfos1", type = "TextArea", label = SV:T("Scale degrees model"),
					height = 60, default = scaleInfo1 .. "\r" .. scaleInfo2 
					.. "\r" .. scaleInfo3
				},
				{
					name = "scaleKeys", type = "TextArea", 
					label = keyFoundDisplay, 
					height = 0
				},
				scaleChoice,
				scaleKeyType,
				trackListCombo,
				sliderLoudness,
				sliderTimeGap,
				comboChoice,
				trackClone,
				pitchInfos,
				pitchDeviation,
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
	
	-- get relative minor scale Keys
	getRelativeMinorScaleKeys = function(keyScaleFound)
		local keys = commonTools.getKeyScaleChoice(keyScaleFound)
		local relativeMinor = {}
		for iKey = 1, #keys do
			table.insert(relativeMinor, keyTools.getKeyMajToMinor(keys[iKey]))
		end
		return relativeMinor
	end,
	
	-- Start to transpose notes
	start = function()
		local maxLengthResult = 30
		local groupsSelected = SV:getArrangement():getSelection():getSelectedGroups()
		
		InternalData.logs:clear()

		-- Check groups selected
		if #groupsSelected == 0 then
			commonTools.show(SV:T("Please select groups first on Arrangement view!"))
		else		
			InternalData.currentTrack = SV:getMainEditor():getCurrentTrack()
			-- Group selected
			local keyScaleFound = scaleTools.getScale(groupsSelected)
			-- Track notes to check
			local keyScaleFoundTrack = scaleTools.getScaleTrack(groupsSelected)
			local keyFoundDisplay = SV:T("Keys found major (minor): ") .. keyScaleFound
			
			InternalData.isOnlyOneKeyFound = false
			InternalData.posKeyInScaleForm = 0
			if string.find(keyScaleFound, InternalData.SEP_KEYS)== nil then
				InternalData.isOnlyOneKeyFound = true
				keyScaleFoundMajor = keyTools.split(keyScaleFound, "(")[1]
				InternalData.posKeyInScaleForm = scaleTools.getKeyPosInKeynames(InternalData.keyNames, keyScaleFoundMajor) -1
			end
			InternalData.keyScaleChoice = {}

			InternalData.keyScaleChoice = InternalData.keyNames
			InternalData.relativeMinorkeyScaleChoice = {}
			if keyScaleFound == "" then
				keyFoundDisplay = SV:T("No common scale key found!")
			else
				-- InternalData.keyScaleChoice = commonTools.getKeyScaleChoice(keyScaleFound)
				InternalData.relativeMinorScaleKeysChoice = commonTools.getRelativeMinorScaleKeys(keyScaleFound)
				InternalData.relativeMinorScalekeys = SV:T("Relative minor keys: ") 
					.. table.concat(InternalData.relativeMinorScaleKeysChoice, "/")
				
				if string.len(keyScaleFoundTrack) > 0 then
					if keyScaleFound ~= keyScaleFoundTrack then
						keyFoundDisplay = keyScaleFound .. "\r" .. SV:T("Track: ") .. keyScaleFoundTrack
					end
				end
			end
			local isFirst = true
			local userInput = commonTools.callForms(isFirst, keyScaleFound, keyFoundDisplay, 
													keyScaleFoundTrack, groupsSelected)
		end
	end,
	
	-- Call dialog forms
	callForms = function(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected)
		local userInput = nil
		local transposition = nil
		local transpositionLabel = ""
		
		if isFirst then
			-- Selection of action 1 note, 2 notes etc..
			userInput = commonTools.getForm(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
							groupsSelected, transposition, transpositionLabel)
			
			if userInput.status then
				-- call itself to display next dialog box for Harmony selection
				InternalData.keyScaleFound = scaleTools.getkeyScaleChoiceFromPos(userInput.answers.scaleKeyChoice)
				InternalData.keyScaleTypeFound  		= userInput.answers.scaleKeyType + 1
				InternalData.keyScaleTypeTitleFound  	= InternalData.allScales[InternalData.keyScaleTypeFound][1]
				InternalData.keyScaleTypeValuesFound	= InternalData.allScales[InternalData.keyScaleTypeFound][2]		
				InternalData.harmonyChoice 				= userInput.answers.harmonyChoice + 1
				
				isFirst = false
				commonTools.callForms(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected)
			end
		else
			local formId = InternalData.harmonyChoice
			-- harmony selection
			transposition = InternalData.transposition[formId][InternalData.transpositionRefData]
			local defaultPosTransposition = InternalData.transposition[formId][InternalData.transpositionRefPosition]
			transpositionLabel = InternalData.transposition[formId][InternalData.transpositionRefLabel]
						
			userInput = commonTools.getForm(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
							groupsSelected, transposition, transpositionLabel, defaultPosTransposition)
			
			if userInput.status then			
				InternalData.isTrackClone = userInput.answers.isTrackClone
				InternalData.pitchDeviation = userInput.answers.newPitchDeviation
				-- Duplicate note groups & create tracks
				local numGroups = commonTools.duplicateNotes(groupsSelected, userInput.answers)
			end		
		end
		
		return userInput
	end,
	
	-- Duplicate and transpose notes
	duplicateNotes = function(groupsSelected, userInputAnswer)

		local project = SV:getProject()
		local pitchPosInput = userInputAnswer.pitch
		local pitchInputText = userInputAnswer.pitchText
		local newTimeGap = math.floor(userInputAnswer.newTimeGap)
		local newLoudness = userInputAnswer.loudnessHarmony
		local pitchTarget = ""
		local pitchTargets = {}
		local trackChoice = 0
		
		if pitchInputText ~= nil then			
			if string.len(pitchInputText) > 0 then
				pitchTarget = commonTools.trim(pitchInputText)
			else
				commonTools.show(SV:T("Nothing to do!"))
				return -1
			end
		else 
			pitchTarget = commonTools.trim(keyTools.getPitchActionFromPos(pitchPosInput, InternalData.harmonyChoice))
		end
		
		local isFixed = (pitchTarget == "Fixed")
		local numGroups = 0
		
		pitchTargets = keyTools.split(pitchTarget, ",")
		
		if #pitchTargets > 1 then
			isMultipleTracks = true -- force for "build your own"
		else 
			if userInputAnswer.trackChoice ~= nil then
				trackChoice = userInputAnswer.trackChoice + 1
			end
		end
		
		local posKeyInScale = scaleTools.getKeyPosInKeynames(InternalData.keyNames, InternalData.keyScaleFound) -1
		
		InternalData.currentKeyNames = keyTools.copyTable(InternalData.keyNames)
		
		-- Rotate table content, start note to new key
		keyTools.shiftTable(InternalData.currentKeyNames, posKeyInScale)
		InternalData.keysInScale = scaleTools.getKeysInScale(InternalData.currentKeyNames, InternalData.keyScaleFound)
		
		if string.len(InternalData.keyScaleFound) == 0 then
			commonTools.show(SV:T("Error: No scale key found!"))
			return -1
		end
		if posKeyInScale < 0 then
			commonTools.show(SV:T("Error: Position into scale error!"))
			return posKeyInScale
		end
		local formatCount = "%3d"
		local iTracks = project:getNumTracks()
		
		if InternalData.isTrackClone then
			InternalData.newTrackRef = commonTools.cloneTrackReference(project)
		end

		-- Only one track to add
		if not isMultipleTracks then
			local track = nil
			local newGroupRefs = commonTools.groupLoop(project, groupsSelected, isFixed, pitchTarget, 
															posKeyInScale, newTimeGap, newLoudness)
			-- New track
			if #InternalData.trackListChoice == trackChoice or trackChoice == 0 then
				if InternalData.isTrackClone then
					track = commonTools.cloneTrack(project)
				else
					track = commonTools.createTrack(project)
				end
				local trackNumber = iTracks + 1
				track:setName(InternalData.trackNameHarmony .. trackNumber .. " (" .. pitchTarget .. ")")
			else
				track = project:getTrack(trackChoice)
			end
			
			for iGroupRef = 1, #newGroupRefs do
				track:addGroupReference(newGroupRefs[iGroupRef])
				numGroups = numGroups + 1
			end
		else
			-- add multiple tracks
			for iTrack = 1, #pitchTargets do
				local track = nil
				
				pitchTarget = commonTools.trim(pitchTargets[iTrack])
				isFixed = (pitchTarget == "Fixed")
				local newGroupRefs = commonTools.groupLoop(project, groupsSelected, isFixed, pitchTarget, 
																posKeyInScale, newTimeGap, newLoudness)
				if InternalData.isTrackClone then
					track = commonTools.cloneTrack(project)
				else
					track = commonTools.createTrack(project)
				end
				local trackNumber = iTrack + 1
				track:setName(InternalData.trackNameHarmony .. trackNumber .. " (" .. pitchTarget .. ")")
				
				for iGroupRef = 1, #newGroupRefs do
					track:addGroupReference(newGroupRefs[iGroupRef])
					numGroups = numGroups + 1
				end
			end
		end
		
		if InternalData.isTrackClone then
			commonTools.deleteClonedTrack(project)
		end

		InternalData.logs:showLogs()
		return numGroups
	end,
	
	-- Clone track to keep current track voice
	cloneTrackReference = function(project)
		local newTrack = InternalData.currentTrack:clone()		
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
		
		newTrack:setName("Track voice ref")
		project:addTrack(newTrack)

		return newTrack
	end,

	-- Delete track reference
	deleteClonedTrack = function(project)
		local result = false
		if InternalData.newTrackRef ~= nil then
			local index = InternalData.newTrackRef:getIndexInParent()
			project:removeTrack(index)
			result = true
		end
		return result
	end,
	
	-- Loop into groups to duplicate & transpose notes
	groupLoop = function(project, groupsSelected, isFixed, pitchTarget, posKeyInScale, newTimeGap, newLoudness)
		local newGroupRefs = {}
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
					local firstNote = newNoteGroup:getNote(1)
					local lastNote = newNoteGroup:getNote(selectedNotes)
					local firstNotePitch = firstNote:getPitch()
					for iNote = 1, selectedNotes do
						local note = newNoteGroup:getNote(iNote)			
						local notePitch = scaleTools.getNewPitch(isFixed, firstNotePitch, 
							note:getPitch(), tonumber(pitchTarget), posKeyInScale)
						note:setPitch(notePitch)
						
						-- Add time gap
						-- local noteTimeGap = note:getOnset() + (SV.QUARTER * newTimeGap / 100)
						-- note:setOnset(noteTimeGap)
						local attributes = note:getAttributes()
						local newRandomGap = commonTools.getNewTimeGap(newTimeGap)
						attributes.tNoteOffset = newRandomGap / 1000
						note:setAttributes(attributes)
					end			
					project:addNoteGroup(newNoteGroup)
					
					-- Add group reference to project new track
					local newGrouptRef = SV:create("NoteGroupReference", newNoteGroup)
					-- Adjust time offset
					newGrouptRef:setTimeOffset(groupRefTimeoffset)
					
					-- Loudness lower
					local voiceAttributes = newGrouptRef:getVoice()
					if newLoudness ~= 0 then
						voiceAttributes.paramLoudness = newLoudness
						newGrouptRef:setVoice(voiceAttributes)
					end
					
					-- Update pitch deviation
					commonTools.updatePitchParameters(newNoteGroup, firstNote, lastNote)
					
					table.insert(newGroupRefs, newGrouptRef)
				end
			end
		end
		
		return newGroupRefs
	end,
	
	-- Update pitch time deviation
	getNewTimeGap = function(timeGap)
		if InternalData.randomSeedActive then
			math.randomseed(InternalData.randomSeedValue)
		end
		local newTimeGap = math.random(-timeGap, timeGap)
		return newTimeGap
	end,
	
	-- Update pitch deviation
	getNewPitchDeviation = function(pitch)
		if InternalData.randomSeedActive then
			math.randomseed(InternalData.randomSeedValue)
		end
		
		if math.floor(pitch) == 0 then
			newPitch = commonTools.randomGaussian(-1, 1)
		else
			-- -10%
			local newPitchStart = math.floor(math.abs(pitch) * (1 - (1 * InternalData.pitchDeviation / 100)))
			-- +10%
			local newPitchEnd = math.floor(math.abs(pitch) * (1 + (1 * InternalData.pitchDeviation / 100)))
			
			if pitch < 0 then
				newPitch = math.random(-1 * newPitchEnd, -1 * newPitchStart)
				--newPitch = commonTools.randomGaussian(-1 * newPitchEnd, -1 * newPitchStart)
			else
				newPitch = math.random(newPitchStart, newPitchEnd)
				--newPitch = commonTools.randomGaussian(newPitchStart, newPitchEnd)
			end
		end
		
		return newPitch
	end,
	
	-- Random gaussian
	randomGaussian = function(mean, stddev)
		local u, v, s;
		
		repeat
			u = math.random() * 2 - 1
			v = math.random() * 2 - 1
			s = u * u + v * v
		until (s <= 1 and s ~= 0)
		
		s = math.sqrt(-2 * math.log(s) / s)
		return mean + stddev * u * s
	end,
	
	-- Update pitch deviation
	updatePitchParameters = function(notesGroup, firstNote, lastNote)
		local paramsGroup = notesGroup:getParameter("pitchDelta")
		-- local paramPointsFound = {}
		local parametersFoundCount = 0
		-- local pointCount = 0
		local timeBegin = firstNote:getOnset()
		local timeEnd = lastNote:getOnset() + lastNote:getDuration()

		if paramsGroup ~= nil then
			local allPoint = paramsGroup:getAllPoints()
			-- pitchDelta=1:[1426381361, 6.7873301506042]|2:[1605705119, 161.53845214844]|3:[1624581303, 0.0]
			-- Loop all parameters points
			for iPoint = 1, #allPoint do
				local pts = allPoint[iPoint]
				local array = {}
				local dataStr = ""
				
				-- Loop each pair point
				for iPosPoint = 1, #pts do
					local currentPoint = allPoint[iPoint][1]
					
					-- Only time inside selected notes
					if currentPoint >= timeBegin  and currentPoint <= timeEnd  then
						dataStr = tostring(allPoint[iPoint][iPosPoint])
						array[iPosPoint] = allPoint[iPoint][iPosPoint]
						
						local pitchVariation = commonTools.getNewPitchDeviation(allPoint[iPoint][iPosPoint])
						-- Update value point
						local newValue = pitchVariation
						paramsGroup:remove(currentPoint)
						paramsGroup:add(currentPoint, newValue)						
					end
				end
			end
			paramsGroup:simplify(timeBegin, timeEnd, 0.01)
		end
	end,
	
	-- trim string
	trim = function(s)
	  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
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
			-- Loop through groups in track
			local numGroups = InternalData.currentTrack:getNumGroups()
			local refGroupTrack = nil
			trackinfos = SV:T("Groups (") .. numGroups .. ")"
			for grp = 1, numGroups do
				refGroupTrack = InternalData.currentTrack:getGroupReference(grp)
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
				commonTools.show(SV:T("No group selected!"))
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
					.. "(" .. keyTools.getKeyMajToMinor(InternalData.keyNames[key]) .. ")"
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
				
				-- Add all gaps to get shifting note
				local dec = (posKeyInScaleKey + key - 2) % 7 + 1
				-- {0,2,4,5,7,9,11,12} => {2, 2, 1, 2, 2, 2, 1}
				--                        {2, 1, 2, 2, 1, 2, 2} "Natural Minor" 
				local keyScaleTypeGaps = scaleTools.getKeyScaleTypeToGap(InternalData.keyScaleTypeValuesFound)
				shift = shift + keyScaleTypeGaps[dec]
			end
		end
		return shift
	end,
	
	-- Get key scale type to gap values
	getKeyScaleTypeToGap = function(keyScaleTypeValuesFound)
		-- {0,2,4,5,7,9,11,12} => {2, 2, 1, 2, 2, 2, 1}
		local keyScaleGaps = {}
			for iKey = 1, #keyScaleTypeValuesFound -1 do
				table.insert(keyScaleGaps, keyScaleTypeValuesFound[iKey + 1] - keyScaleTypeValuesFound[iKey])
			end
		return keyScaleGaps
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
	getPitchActionFromPos = function(pos, harmonyChoice)
		return InternalData.transposition[harmonyChoice][InternalData.transpositionRefData][pos + 1]
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