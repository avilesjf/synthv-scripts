local SCRIPT_TITLE = 'Group Harmony V1.6'

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

New version 1.6 to help with language translation

2024 - JF AVILES
--]]


function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Groups",
		author = "JFAVILES",
		versionNumber = 6,
		minEditorVersion = 65540
	}
end

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Major", "Major"},
			{"Track H", "Track H"},
			{"default", "default"},
			{"1 note", "1 note"},
			{"2 notes", "2 notes"},
			{"3 notes", "3 notes"},
			{"Octaves", "Octaves"},
			{"Fixed", "Fixed"},
			{"Build your own", "Build your own"},
			{"Natural Minor", "Natural Minor"},
			{"Melodic Minor", "Melodic Minor"},
			{"Harmonic Minor", "Harmonic Minor"},
			{"Ionian", "Ionian"},
			{"Dorian", "Dorian"},
			{"Phrygian", "Phrygian"},
			{"Locrian", "Locrian"},
			{"Lydian", "Lydian"},
			{"Mixolydian", "Mixolydian"},
			{"Aeolian", "Aeolian"},
			{"Blues Major", "Blues Major"},
			{"Blues Minor", "Blues Minor"},
			{"Japanese", "Japanese"},
			{"Chinese", "Chinese"},
			{"Chinese 2", "Chinese 2"},
			{"Indian", "Indian"},
			{"Hungarian major", "Hungarian major"},
			{"groups", "groups"},
			{"group", "group"},
			{"Degrees", "Degrees"},
			{"I           II           III    IV          V          VI       VII      +I", "I           II           III    IV          V          VI       VII      +I"},
			{"Major C", "Major C"},
			{"1          2            3      4          5           6          7       8", "1          2            3      4          5           6          7       8"},
			{"Key", "Key"},
			{"C  Db  D   Eb   E      F  Gb  G  Ab  A  Bb   B      C", "C  Db  D   Eb   E      F  Gb  G  Ab  A  Bb   B      C"},
			{"Select a key scale", "Select a key scale"},
			{"Key scale type", "Key scale type"},
			{"Harmony type", "Harmony type"},
			{"Transpose mode: ", "Transpose mode: "},
			{"Input notes (+3, +5, +7 etc..):", "Input notes (+3, +5, +7 etc..):"},
			{"Key scale type selected: ", "Key scale type selected: "},
			{"Key scale selected: ", "Key scale selected: "},
			{"Use current track as a source voice for new tracks", "Use current track as a source voice for new tracks"},
			{"Please note that new random pitch shift only works", "Please note that new random pitch shift only works"},
			{"if the selected notes are in manual mode!", "if the selected notes are in manual mode!"},
			{"Lower output level for new harmony groups", "Lower output level for new harmony groups"},
			{"Max random pitch offset (default time shift +-20 ms)", "Max random pitch offset (default time shift +-20 ms)"},
			{"Random pitch deviation tuning (default +-10%)", "Random pitch deviation tuning (default +-10%)"},
			{"New track", "New track"},
			{"Select destination track:", "Select destination track:"},
			{"Create track and duplicate transposed group of notes", "Create track and duplicate transposed group of notes"},
			{"Groups selected: ", "Groups selected: "},
			{"Scale degrees model", "Scale degrees model"},
			{"Please select groups first on Arrangement view!", "Please select groups first on Arrangement view!"},
			{"Keys found major (minor): ", "Keys found major (minor): "},
			{"No common scale key found!", "No common scale key found!"},
			{"Relative minor keys: ", "Relative minor keys: "},
			{"Track: ", "Track: "},
			{"Nothing to do!", "Nothing to do!"},
			{"Error: No scale key found!", "Error: No scale key found!"},
			{"Error: Position into scale error!", "Error: Position into scale error!"},
			{"Groups", "Groups"},
			{"Group:", "Group:"},
			{"No group selected!", "No group selected!"},
			{"Group or track: ", "Group or track: "},
			{"notes count:", "notes count:"},
			{"key:", "key:"},
			{"YES", "YES"},
			{"pitch: ", "pitch: "},
			{"NOT", "NOT"},
		},
	}
end

-- Define a class  "NotesObject"
NotesObject = {
	project = nil,
	keyNames = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"},
	currentKeyNames = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"},
	keysInScale = {},
	relativeKeys = {{"C","Am"},{"Db","Bbm"},{"D","Bm"},{"Eb","Cm"},{"E","C#m"},{"F","Dm"},
				{"Gb","Ebm"},{"G","Em"},{"Ab","Fm"},{"A", "F#m"},{"Bb","Gm"},{"B", "G#m"}},
	transposition = {},
	transpositionRefLabel = 1,
	transpositionRefPosition = 2,
	transpositionRefData = 3,
	isOnlyOneKeyFound = false,
	posKeyInScaleForm = 0,
    allScales = {},
	SEP_KEYS = "/",
	keyScaleChoice = {},
	relativeMinorScalekeysChoice = {},
	relativeMinorScalekeys = "",
	keyScaleFound = "",
	keyScaleTypeFound  = 1, -- for Major
	keyScaleTypeTitleFound  = "",
	keyScaleTypeValuesFound = {0,2,4,5,7,9,11,12},
	harmonyChoice = 0,
	trackNameHarmony = "",
	isTrackClone = false,
	currentTrack = nil,
	newTrackRef = nil,
	randomSeedActive = false,
	randomSeedValue = 42,
	pitchDeviation = 0,
	tracks = {},
	trackListChoice = {},
	DEBUG = false,
	logs = ""
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local NotesObject = {}
    setmetatable(NotesObject, self)
    self.__index = self
	
    NotesObject.project = SV:getProject()
	
	NotesObject.keyScaleTypeTitleFound  = SV:T("Major")
	NotesObject.trackNameHarmony = SV:T("Track H")
	
	NotesObject.transposition = { 
		-- Specify your own default {SV:T("default"), 1, {"+2,+5", "-2,-5", "+2,+5,+7", "-2,-5,-7"}},
		{SV:T("1 note"),  8, {"+7", "+6", "+5", "+4", "+3", "+2", "+1", "0", "-3", "-5", "-7"}},
		{SV:T("2 notes"), 2, {"+1,+3", "+2,+5", "+2,+4", "+3,+5", "+3,+6", "-2,-5", "-3,-5"}},
		{SV:T("3 notes"), 1, {"+2,+5,+7", "+1,+3,+5", "+2,+3,+5", "-2,-5,-7"}},
		{SV:T("Octaves"), 4, {"+3,+5,+7", "+2,+7", "-7"; "-7,+7", "-3,-5,+7"}},
		{SV:T("Fixed"),  1, {"Fixed"}},
		{SV:T("Build your own"), 1, {"+0"}}
	}
	
	NotesObject.allScales = {
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
		}
    return NotesObject
end

-- Display message box
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Get host infos
function NotesObject:getHostInfos()
	local hostinfo = SV:getHostInfo()
	local osType = hostinfo.osType  -- "macOS", "Linux", "Unknown", "Windows"
	local osName = hostinfo.osName
	local hostName = hostinfo.hostName
	local languageCode = hostinfo.languageCode
	local hostVersion = hostinfo.hostVersion
	return osType, osName, hostName, languageCode, hostVersion
end

-- Add internal logs
function NotesObject:logsAdd(new)
	if self.DEBUG then self.logs = self.logs .. new end
end

-- Clear internal logs
function NotesObject:logsClear()
	if self.DEBUG then self.logs = "" end
end

-- Display logs
function NotesObject:logsShow()
	if self.DEBUG then 
		self:show(self.logs)
	end
end
	
-- Create a new track
function NotesObject:createTrack()
	local newTrack = SV:create("Track")
	self.project:addTrack(newTrack)
	-- local newTrackIndex = self.project:addTrack(newTrack)
	-- newTrack = self.project:getTrack(newTrackIndex)
	return newTrack
end

-- Clone track from track reference
function NotesObject:cloneTrack()
	local newTrack = self.newTrackRef:clone()
	self.project:addTrack(newTrack)
	return newTrack
end

-- Get harmony list
function NotesObject:getHarmonyList()
	local resultList = {}
	for iList = 1, #self.transposition do
		table.insert(resultList, self.transposition[iList][self.transpositionRefLabel])
	end
	return resultList
end

--- Get track list
function NotesObject:getTracksList()
	local list = {}
	local formatCount = "%3d"
	local iTracks = self.project:getNumTracks()
	
	for iTrack = 1, iTracks do
		local track = self.project:getTrack(iTrack)
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
end

-- Get scales title
function NotesObject:getScalesTitle()
	local scales = {}
	for iScale = 1, #self.allScales do
		table.insert(scales, 
			self.allScales[iScale][1]
		)
		
	end
	return scales
end

-- Get scale from title
function NotesObject:getScaleFromTitle(scaleSearch)
	local scale = {}
	for iScale = 1, #self.allScales do
		if scaleSearch == self.allScales[iScale][1] then
			scale = self.allScales[iScale]
		end
	end
	return scale
end

-- Create user input form
function NotesObject:getForm(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
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
		
		local harmonyList = self:getHarmonyList()
		
		if self.isOnlyOneKeyFound then
			defaultKeyPos = self.posKeyInScaleForm
		end

		scaleChoice = {
			name = "scaleKeyChoice", type = "ComboBox", label = SV:T("Select a key scale"),
			choices = self.keyScaleChoice, default = defaultKeyPos
		}
		
		scaleKeyType = {
			name = "scaleKeyType", type = "ComboBox", label = SV:T("Key scale type"),
			choices = self:getScalesTitle(), default = 0
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
							choices = transposition, default = posTranposition - 1}
		end
		
		scaleKeyType = {
			name = "scaleKeyType", type = "TextArea", 
			label = SV:T("Key scale type selected: ") .. self.keyScaleTypeTitleFound, 
			height = 0
		}
		
		scaleChoice = {
			name = "scaleKeySelected", type = "TextArea", 
			label = SV:T("Key scale selected: ") .. self.keyScaleFound, 
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
		if self.harmonyChoice == 1 then
			self.tracks = self:getTracksList()
			self.trackListChoice = self.tracks
			table.insert(self.trackListChoice, SV:T("New track")) -- default choice
			
			trackListCombo = {name = "trackChoice", type = "ComboBox", label = SV:T("Select destination track:"),
							choices = self.trackListChoice, default = #self.trackListChoice - 1}
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
end

-- get scale Key Found in choice format
function NotesObject:getKeyScaleChoice(keyScaleFound)
	local choice = {}
	if string.find(keyScaleFound, self.SEP_KEYS) == nil then
		table.insert(choice, keyScaleFound)
	else
		choice = self:split(keyScaleFound, self.SEP_KEYS)
	end
	return choice
end

-- get relative minor scale Keys
function NotesObject:getRelativeMinorScaleKeys(keyScaleFound)
	local keys = self:getKeyScaleChoice(keyScaleFound)
	local relativeMinor = {}
	for iKey = 1, #keys do
		table.insert(relativeMinor, self:getKeyMajToMinor(keys[iKey]))
	end
	return relativeMinor
end

-- Start to transpose notes
function NotesObject:start()
	local maxLengthResult = 30
	local groupsSelected = SV:getArrangement():getSelection():getSelectedGroups()
	local osType, osName, hostName, languageCode, hostVersion = self:getHostInfos()	
	self:logsClear()
	
	self:logsAdd("osType: " .. osType .. ", hostName: " .. hostName  .. "\r")
	self:logsAdd("osName: " .. osName .. ", hostVersion: " .. hostVersion 
		.. ", languageCode: " .. languageCode  .. "\r")
	
	-- Check groups selected
	if #groupsSelected == 0 then
		self:show(SV:T("Please select groups first on Arrangement view!"))
	else		
		self.currentTrack = SV:getMainEditor():getCurrentTrack()
		-- Group selected
		local keyScaleFound = self:getScale(groupsSelected)
		-- Track notes to check
		local keyScaleFoundTrack = self:getScaleTrack(groupsSelected)
		local keyFoundDisplay = SV:T("Keys found major (minor): ") .. keyScaleFound
		
		self.isOnlyOneKeyFound = false
		self.posKeyInScaleForm = 0
		if string.find(keyScaleFound, self.SEP_KEYS)== nil then
			self.isOnlyOneKeyFound = true
			keyScaleFoundMajor = self:split(keyScaleFound, "(")[1]
			self.posKeyInScaleForm = self:getKeyPosInKeynames(self.keyNames, keyScaleFoundMajor) -1
		end
		self.keyScaleChoice = {}

		self.keyScaleChoice = self.keyNames
		self.relativeMinorkeyScaleChoice = {}
		if keyScaleFound == "" then
			keyFoundDisplay = SV:T("No common scale key found!")
		else
			-- self.keyScaleChoice = self:getKeyScaleChoice(keyScaleFound)
			self.relativeMinorScaleKeysChoice = self:getRelativeMinorScaleKeys(keyScaleFound)
			self.relativeMinorScalekeys = SV:T("Relative minor keys: ") 
				.. table.concat(self.relativeMinorScaleKeysChoice, "/")
			
			if string.len(keyScaleFoundTrack) > 0 then
				if keyScaleFound ~= keyScaleFoundTrack then
					keyFoundDisplay = keyScaleFound .. "\r" .. SV:T("Track: ") .. keyScaleFoundTrack
				end
			end
		end
		local isFirst = true
		local userInput = self:callForms(isFirst, keyScaleFound, keyFoundDisplay, 
												keyScaleFoundTrack, groupsSelected)
	end
end

-- Call dialog forms
function NotesObject:callForms(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected)
	local userInput = nil
	local transposition = nil
	local transpositionLabel = ""
	
	if isFirst then
		-- Selection of action 1 note, 2 notes etc..
		userInput = self:getForm(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
						groupsSelected, transposition, transpositionLabel)
		
		if userInput.status then
			-- call itself to display next dialog box for Harmony selection
			self.keyScaleFound = self:getkeyScaleChoiceFromPos(userInput.answers.scaleKeyChoice)
			self.keyScaleTypeFound  		= userInput.answers.scaleKeyType + 1
			self.keyScaleTypeTitleFound  	= self.allScales[self.keyScaleTypeFound][1]
			self.keyScaleTypeValuesFound	= self.allScales[self.keyScaleTypeFound][2]		
			self.harmonyChoice 				= userInput.answers.harmonyChoice + 1
			
			isFirst = false
			self:callForms(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, groupsSelected)
		end
	else
		local formId = self.harmonyChoice
		-- harmony selection
		transposition = self.transposition[formId][self.transpositionRefData]
		local defaultPosTransposition = self.transposition[formId][self.transpositionRefPosition]
		transpositionLabel = self.transposition[formId][self.transpositionRefLabel]
					
		userInput = self:getForm(isFirst, keyScaleFound, keyFoundDisplay, keyScaleFoundTrack, 
						groupsSelected, transposition, transpositionLabel, defaultPosTransposition)
		
		if userInput.status then			
			self.isTrackClone = userInput.answers.isTrackClone
			self.pitchDeviation = userInput.answers.newPitchDeviation
			-- Duplicate note groups & create tracks
			local numGroups = self:duplicateNotes(groupsSelected, userInput.answers)
		end		
	end
	
	return userInput
end

-- Duplicate and transpose notes
function NotesObject:duplicateNotes(groupsSelected, userInputAnswer)
	local pitchPosInput = userInputAnswer.pitch
	local pitchInputText = userInputAnswer.pitchText
	local newTimeGap = math.floor(userInputAnswer.newTimeGap)
	local newLoudness = userInputAnswer.loudnessHarmony
	local pitchTarget = ""
	local pitchTargets = {}
	local trackChoice = 0
	
	if pitchInputText ~= nil then			
		if string.len(pitchInputText) > 0 then
			pitchTarget = self:trim(pitchInputText)
		else
			self:show(SV:T("Nothing to do!"))
			return -1
		end
	else 
		pitchTarget = self:trim(self:getPitchActionFromPos(pitchPosInput, self.harmonyChoice))
	end
	
	local isFixed = (pitchTarget == "Fixed")
	local numGroups = 0
	
	pitchTargets = self:split(pitchTarget, ",")
	
	if #pitchTargets > 1 then
		isMultipleTracks = true -- force for "build your own"
	else 
		if userInputAnswer.trackChoice ~= nil then
			trackChoice = userInputAnswer.trackChoice + 1
		end
	end
	
	local posKeyInScale = self:getKeyPosInKeynames(self.keyNames, self.keyScaleFound) -1
	
	self.currentKeyNames = self:copyTable(self.keyNames)
	
	-- Rotate table content, start note to new key
	self:shiftTable(self.currentKeyNames, posKeyInScale)
	self.keysInScale = self:getKeysInScale(self.currentKeyNames, self.keyScaleFound)
	
	if string.len(self.keyScaleFound) == 0 then
		self:show(SV:T("Error: No scale key found!"))
		return -1
	end
	if posKeyInScale < 0 then
		self:show(SV:T("Error: Position into scale error!"))
		return posKeyInScale
	end
	local formatCount = "%3d"
	local iTracks = self.project:getNumTracks()
	
	if self.isTrackClone then
		self.newTrackRef = self:cloneTrackReference()
	end

	-- Only one track to add
	if not isMultipleTracks then
		local track = nil
		local newGroupRefs = self:groupLoop(groupsSelected, isFixed, pitchTarget, 
														posKeyInScale, newTimeGap, newLoudness)
		-- New track
		if #self.trackListChoice == trackChoice or trackChoice == 0 then
			if self.isTrackClone then
				track = self:cloneTrack()
			else
				track = self:createTrack()
			end
			local trackNumber = iTracks + 1
			track:setName(self.trackNameHarmony .. trackNumber .. " (" .. pitchTarget .. ")")
		else
			track = self.project:getTrack(trackChoice)
		end
		
		for iGroupRef = 1, #newGroupRefs do
			track:addGroupReference(newGroupRefs[iGroupRef])
			numGroups = numGroups + 1
		end
	else
		-- add multiple tracks
		for iTrack = 1, #pitchTargets do
			local track = nil
			
			pitchTarget = self:trim(pitchTargets[iTrack])
			isFixed = (pitchTarget == "Fixed")
			local newGroupRefs = self:groupLoop(groupsSelected, isFixed, pitchTarget, 
															posKeyInScale, newTimeGap, newLoudness)
			if self.isTrackClone then
				track = self:cloneTrack()
			else
				track = self:createTrack()
			end
			local trackNumber = iTrack + 1
			track:setName(self.trackNameHarmony .. trackNumber .. " (" .. pitchTarget .. ")")
			
			for iGroupRef = 1, #newGroupRefs do
				track:addGroupReference(newGroupRefs[iGroupRef])
				numGroups = numGroups + 1
			end
		end
	end
	
	if self.isTrackClone then
		self:deleteClonedTrack()
	end

	self:logsShow()
	return numGroups
end

-- Clone track to keep current track voice
function NotesObject:cloneTrackReference()
	local newTrack = self.currentTrack:clone()		
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
	self.project:addTrack(newTrack)

	return newTrack
end

-- Delete track reference
function NotesObject:deleteClonedTrack()
	local result = false
	if self.newTrackRef ~= nil then
		local index = self.newTrackRef:getIndexInParent()
		self.project:removeTrack(index)
		result = true
	end
	return result
end

-- Loop into groups to duplicate & transpose notes
function NotesObject:groupLoop(groupsSelected, isFixed, pitchTarget, posKeyInScale, newTimeGap, newLoudness)
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
					local notePitch = self:getNewPitch(isFixed, firstNotePitch, 
						note:getPitch(), tonumber(pitchTarget), posKeyInScale)
					note:setPitch(notePitch)
					
					-- Add time gap
					-- local noteTimeGap = note:getOnset() + (SV.QUARTER * newTimeGap / 100)
					-- note:setOnset(noteTimeGap)
					local attributes = note:getAttributes()
					local newRandomGap = self:getNewTimeGap(newTimeGap)
					attributes.tNoteOffset = newRandomGap / 1000
					note:setAttributes(attributes)
				end			
				self.project:addNoteGroup(newNoteGroup)
				
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
				self:updatePitchParameters(newNoteGroup, firstNote, lastNote)
				
				table.insert(newGroupRefs, newGrouptRef)
			end
		end
	end
	
	return newGroupRefs
end

-- Update pitch time deviation
function NotesObject:getNewTimeGap(timeGap)
	if self.randomSeedActive then
		math.randomseed(self.randomSeedValue)
	end
	local newTimeGap = math.random(-timeGap, timeGap)
	return newTimeGap
end

-- Update pitch deviation
function NotesObject:getNewPitchDeviation(pitch)
	if self.randomSeedActive then
		math.randomseed(self.randomSeedValue)
	end
	
	if math.floor(pitch) == 0 then
		newPitch = self:randomGaussian(-1, 1)
	else
		-- -10%
		local newPitchStart = math.floor(math.abs(pitch) * (1 - (1 * self.pitchDeviation / 100)))
		-- +10%
		local newPitchEnd = math.floor(math.abs(pitch) * (1 + (1 * self.pitchDeviation / 100)))
		
		if pitch < 0 then
			newPitch = math.random(-1 * newPitchEnd, -1 * newPitchStart)
			--newPitch = self:randomGaussian(-1 * newPitchEnd, -1 * newPitchStart)
		else
			newPitch = math.random(newPitchStart, newPitchEnd)
			--newPitch = self:randomGaussian(newPitchStart, newPitchEnd)
		end
	end
	
	return newPitch
end

-- Random gaussian
function NotesObject:randomGaussian(mean, stddev)
	local u, v, s;
	
	repeat
		u = math.random() * 2 - 1
		v = math.random() * 2 - 1
		s = u * u + v * v
	until (s <= 1 and s ~= 0)
	
	s = math.sqrt(-2 * math.log(s) / s)
	return mean + stddev * u * s
end

-- Update pitch deviation
function NotesObject:updatePitchParameters(notesGroup, firstNote, lastNote)
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
					
					local pitchVariation = self:getNewPitchDeviation(allPoint[iPoint][iPosPoint])
					-- Update value point
					local newValue = pitchVariation
					paramsGroup:remove(currentPoint)
					paramsGroup:add(currentPoint, newValue)						
				end
			end
		end
		paramsGroup:simplify(timeBegin, timeEnd, 0.01)
	end
end

-- trim string
function NotesObject:trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end


-- Scale tools
--- Pitch note is in scale
function NotesObject:isInScale(pitch, scale)
	local usekey = {0, 2, 4, 5, 7, 9, 11}
	local inScale = false
	for key = 1, #usekey do
		if pitch % 12 == (usekey[key] + scale) % 12 then
			inScale = true
			break
		end
	end
	return inScale
end

--- Key note is in scale
function NotesObject:isKeyInScale(keyPos)
	local usekey = {0, 2, 4, 5, 7, 9, 11}
	local inScale = false
	for key = 1, #usekey do
		if usekey[key] == keyPos then
			inScale = true
			break
		end
	end
	return inScale
end

--- GetScale in current track
function NotesObject:getScaleTrack(groupsSelected)
	return self:getScale(groupsSelected,  "track")
end

--- GetScale
function NotesObject:getScale(groupsSelected, paramTrack)
	local groupOrTrackNotes = "None"
	local scaleFound = ""
	local notes = {}
	local sep = ""
	local trackinfos = ""
	
	if paramTrack == "track" then
		-- Use current track
		groupOrTrackNotes = "Track"
		-- Loop through groups in track
		local numGroups = self.currentTrack:getNumGroups()
		local refGroupTrack = nil
		trackinfos = SV:T("Groups") .. " (" .. numGroups .. ")"
		for grp = 1, numGroups do
			refGroupTrack = self.currentTrack:getGroupReference(grp)
			self:addNotes(notes, refGroupTrack)
			-- self:logsAdd(SV:T("Group:") .. " " .. refGroupTrack:getTarget():getName() .. ": " .. refGroupTrack:getTarget():getNumNotes() .. "\r")
		end
	else
		-- Groups selected
		if #groupsSelected > 0 then
			groupOrTrackNotes = SV:T("Groups") .. " (" .. #groupsSelected .. ")"
			for _, group in pairs(groupsSelected) do
				self:addNotes(notes, group)
			end
		else
			self:show(SV:T("No group selected!"))
		end
	end
	self:logsAdd(SV:T("Group or track: ") .. groupOrTrackNotes .. ", " ..SV:T("notes count:") .. #notes .. " " .. trackinfos)
	
	-- loop each scales
	for key = 1, #self.keyNames do
		local isInScale = false
		local posKeyInScale = key - 1
		
		-- Loop on pitch notes
		isInScale = self:loopNotes(notes, posKeyInScale, self.keyNames, key)
		if isInScale then
			-- scale found
			scaleFound = scaleFound .. sep .. self.keyNames[key] 
				.. "(" .. self:getKeyMajToMinor(self.keyNames[key]) .. ")"
			self:logsAdd(SV:T("key:") .. self.keyNames[key] .. " " .. SV:T("YES") .. "\r")
			sep = self.SEP_KEYS
			--break
		end
	end		
	-- self:logsShow()
	return scaleFound
end

-- Append notes from group
function NotesObject:addNotes(notes, refGroup)
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
end

-- Get new pitch in key scale
function NotesObject:getNewPitch(isFixed, firstNotePitch, notePitch, pitchTarget, posKeyInScale)
	if isFixed then 
		-- Fix all notes from the first note found
		notePitch = firstNotePitch
	else
		notePitch = self:getNextKeyInScale(self.keyScaleFound, notePitch, pitchTarget)
	end
	return notePitch
end

-- Get next valid key in scale
function NotesObject:getNextKeyInScale(keyScaleFound, notePitch, pitchTarget)		
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
	
	local noteKey = self:getKeyFromPitch(notePitch)
	local posKeyInScaleKey = self:getKeyPosInKeynames(self.keysInScale, noteKey)
	local posTarget = ((posKeyInScaleKey + pitchTarget - 1) % 7) + 1
	local nextKey = self.keysInScale[posTarget]
	
	local gapDegree = self:getShiftDegrees(pitchTarget, posKeyInScaleKey)	
	local notePitchNew = notePitch + gapDegree + octave
	
	self:logsAdd("" .. notePitch .. " / " .. notePitchNew .. ", gap: " .. gapDegree
		.. ", posKey: " .. posKeyInScaleKey .. ", pitch/pos: " .. pitchTarget	.. " / " .. posTarget
		.. ", Key: " .. noteKey .. " / " .. nextKey	.. "\r"
	)
	
	return notePitchNew
end

-- Get shifted degrees
function NotesObject:getShiftDegrees(pitchTarget, posKeyInScaleKey)
	local shift = 0
	if pitchTarget > 0 then
		for key = 1, pitchTarget do
			
			-- Add all gaps to get shifting note
			local dec = (posKeyInScaleKey + key - 2) % 7 + 1
			-- {0,2,4,5,7,9,11,12} => {2, 2, 1, 2, 2, 2, 1}
			--                        {2, 1, 2, 2, 1, 2, 2} "Natural Minor" 
			local keyScaleTypeGaps = self:getKeyScaleTypeToGap(self.keyScaleTypeValuesFound)
			shift = shift + keyScaleTypeGaps[dec]
		end
	end
	return shift
end

-- Get key scale type to gap values
function NotesObject:getKeyScaleTypeToGap(keyScaleTypeValuesFound)
	-- {0,2,4,5,7,9,11,12} => {2, 2, 1, 2, 2, 2, 1}
	local keyScaleGaps = {}
		for iKey = 1, #keyScaleTypeValuesFound -1 do
			table.insert(keyScaleGaps, keyScaleTypeValuesFound[iKey + 1] - keyScaleTypeValuesFound[iKey])
		end
	return keyScaleGaps
end

-- Get key pitch
function NotesObject:getKeyFromPitch(notePitch)
	local pitchPos = notePitch % 12
	return self.keyNames[pitchPos + 1]
end

-- loop for each notes
function NotesObject:loopNotes(notes, posKeyInScale, keyNames, key)
	local isInScale = false
	-- loop all notes
	for note = 1, #notes do
		local notePitch = notes[note]
		if notePitch ~= nil then
			isInScale = self:isInScale(notePitch, posKeyInScale)
			if not isInScale then
				-- self:logsAdd(SV:T("pitch: ") 
				-- .. self.keyNames[(notePitch % 12) + 1] 
				-- .. ", " .. SV:T("key:") .. " " 
				-- ..  self.keyNames[key] .. " " .. SV:T("NOT"))
				break
			end
		end
	end
	return isInScale
end

-- Get key position in Keynames
function NotesObject:getKeyPosInKeynames(keyNames, keyfound)
	local posKeyInScale = -1
	-- loop each scales
	for key = 1, #keyNames do
		if keyfound == keyNames[key] then
			posKeyInScale = key
			break
		end
	end
	return posKeyInScale
end

-- Get key scale found from position self.keyScaleChoice
function NotesObject:getkeyScaleChoiceFromPos(scaleKeyPosInput)
	local keyScaleFound = ""
	for iPos = 1, #self.keyScaleChoice do
		if scaleKeyPosInput == iPos -1 then
			keyScaleFound = self.keyScaleChoice[iPos]
		end
	end
	return keyScaleFound
end

-- Get keys in scale
function NotesObject:getKeysInScale(currentKeyNames, keyScaleFound)
	local keysInScale = {}
	for key = 1, #currentKeyNames do
		if self:isKeyInScale(key-1) then
			table.insert(keysInScale, currentKeyNames[key])
		end
	end
	return keysInScale
end

-- Key tools
-- Get Key from minor to major
function NotesObject:getKeyMinToMaj(key)
	local arrKeys = self.relativeKeys
	
	for iMaj, kMin in pairs(arrKeys) do
		if key == kMin[2] then
			keyResult = kMin[1]
		end
	end	
	return keyResult
end

-- Get Key from major to minor
function NotesObject:getKeyMajToMinor(key)
	local arrKeys = self.relativeKeys
	
	for iMaj, kMin in pairs(arrKeys) do
		if key == kMin[1] then
			keyResult = kMin[2]
		end
	end	
	return keyResult
end

-- Get pitch action from position
function NotesObject:getPitchActionFromPos(pos, harmonyChoice)
	return self.transposition[harmonyChoice][self.transpositionRefData][pos + 1]
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

-- Rotate table content
function NotesObject:shiftTable(tInput, num)
	for iPos = 1, math.abs ( num ) do
		if num < 0 then
			table.insert ( tInput, 1, table.remove ( tInput ) )
		else
			table.insert ( tInput, table.remove ( tInput, 1 ) )
		end
	end
end

-- duplicate table
function NotesObject:copyTable(tInput)
	local tOutput = {}
	for k, v in pairs(tInput) do
		table.insert(tOutput, k, v)
	end
	return tOutput
end

function main()
	local NotesObject = NotesObject:new()
	NotesObject:start()
	
	SV:finish()
end