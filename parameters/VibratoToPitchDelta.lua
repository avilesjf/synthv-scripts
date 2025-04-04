local SCRIPT_TITLE = 'Vibrato to pitch delta V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: VibratoToPitchDelta.lua

This script will recreate a vibrato envelope with pitch delta parameters

Set shortcut to ALT + V

2025 - JF AVILES
--]]

-- Generated by JFA TranslateScripts.lua
function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

-- Generated by JFA TranslateScripts.lua
function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Start/End note (%): ", "Start/End note (%): "},
			{"Vibrato depth: ", "Vibrato depth: "},
			{"ERROR! Tempo not found!", "ERROR! Tempo not found!"},
			{"Override vibrato depth", "Override vibrato depth"},
			{"Choose a model", "Choose a model"},
			{"Vibrato modulation", "Vibrato modulation"},
			{"Do not forget to reset Vibrato Modulation to 0", "Do not forget to reset Vibrato Modulation to 0"},
			{"in the Notes Panel!", "in the Notes Panel!"},
		},
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Parameters",
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
	direction = 1, -- Upper
	newGap = 0.1,
	PARAMETER_REFERENCE = "pitchDelta",
	defaultValue = 1,
	currentGroupRef = nil,
	currentGroupNotes = nil,
	paramsGroup = nil,
	currentTrack = nil,
	endTrackPosition = 0,
	selection = nil,
	selectedNotes = nil,
	newPoints = {},
	blicksPerSeconds = -1,
	quarterBlicks = -1,
	currentBPM = 120,
	coefModulation = 100,
	modelChoice = {},
	modelChoiceList = {},
	timeGapSeconds = 0.01	-- Gap in milliseconds 1 millisecond = 1411200 blicks
}

-- Constructor method for the NotesObject class
function NotesObject:new()
    local notesObject = {}
    setmetatable(notesObject, self)
    self.__index = self
	
    self.project = SV:getProject()
    self.timeAxis = self.project:getTimeAxis()
    self.editor =  SV:getMainEditor()
	self.selection = self.editor:getSelection()
	self.newPoints = self.selection:getSelectedPoints(self.PARAMETER_REFERENCE)
	self.selectedContent = self.selection:hasSelectedContent()
	self.selectedNotes = self.editor:getSelection():getSelectedNotes()
	self.currentGroupRef = self.editor:getCurrentGroup()
	self.currentGroupNotes = self.currentGroupRef:getTarget()
	if self.currentGroupNotes ~= nil then
		self.paramsGroup = self.currentGroupNotes:getParameter(self.PARAMETER_REFERENCE)
	end
	self.currentTrack = self.editor:getCurrentTrack()
	self.endTrackPosition = self.currentTrack:getGroupReference(self.currentTrack:getNumGroups()):getEnd()
	self.timeGapBlicks = self.timeAxis:getBlickFromSeconds(self.timeGapSeconds)
	
	self.modelChoice = self:setVibratoModel() -- Add vibrato model choice
	self.modelChoiceList = self:getVibratoModel()
	
    return self
end

-- Set vibrato model
function NotesObject:setVibratoModel()
	-- startNote, endNote in percentage
	-- vibratoDepth a coefficient of vibrato depth
	local modelChoice = {
		{startNote = 0,	 vibratoDepth = 0.8, endNote = 0},
		{startNote = 30, vibratoDepth = 1.1, endNote = 0},
		{startNote = 50, vibratoDepth = 0.8, endNote = 0},
	}	
	return modelChoice
end

-- Set vibrato model
function NotesObject:getVibratoModel()
	local modelChoiceList = {}

	for k, model in pairs(self.modelChoice) do
		local modelList = SV:T("Start/End note (%): ") 
			.. model.startNote .. " / " .. model.endNote
			.. ", " .. SV:T("Vibrato depth: ") .. model.vibratoDepth 
		table.insert(modelChoiceList, modelList)
	end
	return modelChoiceList
end

-- Show message dialog
function NotesObject:show(message)
	SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
end

-- Save into the clipboard
function NotesObject:saveToClipboard(message)
	SV:setHostClipboard(message)
end

-- Start check current group
function NotesObject:getObjectProperties(obj)
	local result = ""
	for k, v in pairs(obj) do
		if obj[k] ~= nil then
			result = result .. k .. "=" .. tostring(v) .. "\r"
		end
	end
	return result
end

-- Get first note in group
function NotesObject:getFirstNoteInGroup()
	local noteFound = nil
	local notesGroup = self.currentGroupRef:getTarget()
	if notesGroup:getNumNotes() > 1 then
		noteFound = notesGroup:getNote(1)
	end
	return noteFound
end

-- Get last note in group
function NotesObject:getLastNoteInGroup()
	local noteFound = nil
	local notesGroup = self.currentGroupRef:getTarget()
	if notesGroup:getNumNotes() > 1 then
		noteFound = notesGroup:getNote(notesGroup:getNumNotes())
	end
	return noteFound
end

-- Get First and Last note in group
function NotesObject:getFirstAndLastNoteInGroup()
	local firstNotePosition = -1
	local lastNotePosition = -1
	local firstNote = self:getFirstNoteInGroup()
	local lastNote = self:getLastNoteInGroup()
	if firstNote ~= nil then
		firstNotePosition = firstNote:getOnset()
	end
	if lastNote ~= nil then
		lastNotePosition = lastNote:getEnd()
	end
	return firstNotePosition, lastNotePosition
end

-- Get current note in position
function NotesObject:getCurrentNoteInPosition(point)
	local noteFound = nil
	local notesGroup = self.currentGroupRef:getTarget()
	
	for iNote = 1, notesGroup:getNumNotes() do
		local note = notesGroup:getNote(iNote)
		if note:getOnset() <= point and note:getEnd() >= point then
			noteFound = note
			break
		end
	end
	return noteFound
end

-- Get group range time
function NotesObject:getGroupRangeTime(firstNewPointPosition, lastNewPointPosition)
	local groupBegin = self.currentGroupRef:getOnset()
	local groupNewBegin = groupBegin
	local groupEnd = self.currentGroupRef:getOnset() + self.currentGroupRef:getDuration()
	local groupNewEnd = groupEnd
	if firstNewPointPosition < groupBegin then
		groupNewBegin = firstNewPointPosition - self.timeGapBlicks
	end
	if lastNewPointPosition > groupEnd then
		groupNewEnd = lastNewPointPosition + self.timeGapBlicks
	end
	return groupBegin, groupNewBegin, groupEnd, groupNewEnd
end

-- Add end points
function NotesObject:addEndPoint(lastNotePosition, lastNewPointPosition, groupEnd, groupNewEnd)
	local endPoints = self.paramsGroup:getPoints(lastNewPointPosition + 1, groupEnd)
	
	-- If no more points after last point updated
	if #endPoints == 0 then
		-- Add a new point to reset position from last point value
		if lastNotePosition > -1 and lastNewPointPosition < lastNotePosition then
			if self.paramsGroup:get(lastNotePosition) ~= self.defaultValue then
				self.paramsGroup:add(lastNotePosition, self.defaultValue)
			end
		else
			if lastNewPointPosition > lastNotePosition then
				if self.paramsGroup:get(lastNewPointPosition + self.timeGapBlicks) ~= self.defaultValue then
					self.paramsGroup:add(lastNewPointPosition + self.timeGapBlicks, self.defaultValue)
				end
			end
		end
		
		if lastNewPointPosition > groupEnd then
			if self.paramsGroup:get(lastNewPointPosition + self.timeGapBlicks) ~= self.defaultValue then
				self.paramsGroup:add(lastNewPointPosition + (self.timeGapBlicks * 2), self.defaultValue)
			end
		end
	end
end

-- Add begin points
function NotesObject:addBeginPoint(firstNotePosition, firstNewPointPosition, groupNewBegin, groupBegin)
	local firstPoints = self.paramsGroup:getPoints(0, groupNewBegin)

	-- If no points before first point updated
	if #firstPoints == 0 then			
		-- Add a new point to reset position from last point value
		if firstNotePosition > -1 and firstNewPointPosition > firstNotePosition then
			-- Fix new default value to start note
			if self.paramsGroup:get(firstNotePosition) ~= self.defaultValue then
				self.paramsGroup:add(firstNotePosition, self.defaultValue)
			end
		else
			if firstNewPointPosition < firstNotePosition then
				if self.paramsGroup:get(firstNewPointPosition - self.timeGapBlicks) ~= self.defaultValue then
					self.paramsGroup:add(firstNewPointPosition - self.timeGapBlicks, self.defaultValue)
				end
			end
		end
		
		if firstNewPointPosition < groupBegin then
			if self.paramsGroup:get(firstNewPointPosition - self.timeGapBlicks) ~= self.defaultValue then
				self.paramsGroup:add(firstNewPointPosition - (self.timeGapBlicks * 2), self.defaultValue)
			end
		end
	end
end

-- Shift selected points
function NotesObject:shiftSelectedPoints(points)
	local newPoints = {}
	local addedPoints = 0
	
	if points[1]> 0 then
		firstNewPointval = self.paramsGroup:get(points[1])
	end
	
	for _, p in pairs(points) do
		local val = self.paramsGroup:get(p)
		
		self.paramsGroup:remove(p)
		
		local newVal = val + (self.newGap * self.direction)
		self.paramsGroup:add(p, newVal)
		addedPoints = addedPoints + 1
		table.insert(newPoints, p)
	end
	
	if addedPoints > 0 then
		local firstNewPointPosition = newPoints[1]
		local firstNotePosition, lastNotePosition = self:getFirstAndLastNoteInGroup()
		local lastNewPointPosition = newPoints[#newPoints]
		local groupBegin, groupNewBegin, groupEnd, groupNewEnd = self:getGroupRangeTime(firstNewPointPosition, lastNewPointPosition)
		local notePosition = self:getCurrentNoteInPosition(firstNewPointPosition)
		if notePosition ~= nil then
			firstNotePosition = notePosition:getOnset()
			lastNotePosition = notePosition:getEnd()
		end
		self:addEndPoint(lastNotePosition, lastNewPointPosition, groupEnd, groupNewEnd)
		self:addBeginPoint(firstNotePosition, firstNewPointPosition, groupNewBegin, groupBegin)
	end
	
	return newPoints
end


-- Get current blicks per second & quarter 
function NotesObject:getCurrentBlicksPerSecond(positionBlicks)
	local blicks = -1
	local quarterBlicks = -1

	local bpm = self:getProjectTempo(positionBlicks)
	
	if bpm ~= nil then
		-- "120:" for 1s: blicks 1411200000 quarter 2
		-- "60: " for 1s: blicks 705600000 quarter 1
		blicks = SV:seconds2Blick(1, bpm) -- get blicks 1 second with bpm
		quarterBlicks = SV:blick2Quarter(blicks)
	end
	return blicks, quarterBlicks
end

-- Get current project tempo
function NotesObject:getProjectTempo(positionBlicks)
	local tempoActive = 120 -- default
	local tempoMarks = self.timeAxis:getAllTempoMarks()
	for iTempo = 1, #tempoMarks do
		local tempoMark = tempoMarks[iTempo]
		if tempoMark ~= nil and positionBlicks > tempoMark.position then
			tempoActive = tempoMark.bpm
		end
	end
	return math.floor(tempoActive)
end

-- Function to generate a vibrato effect
-- Parameters:
--   amplitude: oscillation amplitude (vibrato depth)
--   frequency: oscillation frequency in Hz
--   duration: total duration in seconds
--   sampleRate: number of samples per second
-- Returns: a table containing vibrato values over time
function NotesObject:generateVibrato(amplitude, frequency, duration, sampleRate)
    local samples = {}
    local totalSamples = math.floor(duration * sampleRate)
    
    -- For each sample
    for i = 1, totalSamples do
        local time = (i - 1) / sampleRate
        -- Sinusoidal oscillation formula for vibrato
        local value = amplitude * math.sin(2 * math.pi * frequency * time)
        samples[i] = {
            time = time,
            value = value
        }
    end
    
    return samples
end

-- Function that allows modifying the vibrato envelope with different parameters
-- Parameters:
--   amplitude: maximum oscillation amplitude
--   frequency: oscillation frequency in Hz
--   duration: total duration in seconds
--   sampleRate: number of samples per second
--   attackTime: attack time in seconds (gradual increase in amplitude)
--   releaseTime: release time in seconds (gradual decrease in amplitude)
--   frequencyModulation: optional table to modulate frequency over time
function NotesObject:generateAdvancedVibrato(amplitude, frequency, duration, sampleRate, attackTime, releaseTime, frequencyModulation)
    local samples = {}
    local totalSamples = math.floor(duration * sampleRate)
    
    -- For each sample
    for i = 1, totalSamples do
        local time = (i - 1) / sampleRate
        local currentAmplitude = amplitude
        
        -- Apply attack envelope
        if time < attackTime then
            currentAmplitude = amplitude * (time / attackTime)
        end
        
        -- Apply release envelope
        if time > (duration - releaseTime) then
            local releasePhase = (time - (duration - releaseTime)) / releaseTime
            currentAmplitude = amplitude * (1 - releasePhase)
        end
        
        -- Apply frequency modulation if provided
        local currentFrequency = frequency
        if frequencyModulation then
            local modulationIndex = math.floor(time / duration * #frequencyModulation) + 1
            if modulationIndex <= #frequencyModulation then
                currentFrequency = frequencyModulation[modulationIndex]
            end
        end
        
        -- Calculate vibrato value
        local value = currentAmplitude * math.sin(2 * math.pi * currentFrequency * time)
        
        samples[i] = {
            time = time,
            value = value
        }
    end
    
    return samples
end

-- Function to apply vibrato to a MIDI note
-- Parameters:
--   noteStartTime: note start time in ticks
--   noteDuration: note duration in ticks
--   ticksPerSecond: ticks to seconds conversion
--   vibratoDelay: delay before vibrato starts in seconds
--   vibratoParams: vibrato parameters (amplitude, frequency, etc.)
function NotesObject:applyVibratoToNote(noteStartTime, noteDuration, ticksPerSecond, vibratoDelay, vibratoParams)
    -- Convert ticks to seconds
    local startTimeSeconds = noteStartTime / ticksPerSecond
    local durationSeconds = noteDuration / ticksPerSecond
	-- self:show("startTimeSeconds: "  .. startTimeSeconds
		-- .. ", noteStartTime: " .. noteStartTime
		-- .. ", ticksPerSecond: " .. ticksPerSecond
		-- .. ", durationSeconds: " .. durationSeconds
		-- .. ", noteDuration: " .. noteDuration
		-- )
	-- if 1 == 0 then
		-- return {}
	-- end
    -- Adjust vibrato duration accounting for delay
    local vibratoDuration = durationSeconds - vibratoDelay
    if vibratoDuration <= 0 then
        return {} -- Note is too short to apply vibrato
    end
    
    -- Generate vibrato
    local vibratoPoints = self:generateAdvancedVibrato(
        vibratoParams.amplitude,
        vibratoParams.frequency,
        vibratoDuration,
        vibratoParams.sampleRate,
        vibratoParams.attackTime,
        vibratoParams.releaseTime,
        vibratoParams.frequencyModulation
    )
    
    -- Add delay to the time of each point
    local finalVibratoPoints = {}
    for i, point in ipairs(vibratoPoints) do
        table.insert(finalVibratoPoints, {
            time = startTimeSeconds + vibratoDelay + point.time,
            value = point.value
        })
    end
    
    return finalVibratoPoints
end

-- Export vibrato to control points for SynthesizerV or similar software
function NotesObject:exportVibratoToControlPoints(vibratoPoints, controlPointInterval)
    local controlPoints = {}
    
    -- Convert to control points at regular intervals
    local interval = controlPointInterval or 0.01 -- 10ms default
    local currentIndex = 1
    
    while currentIndex <= #vibratoPoints do
        local point = vibratoPoints[currentIndex]
        
        table.insert(controlPoints, {
            time = point.time,
            value = point.value
        })
        
        -- Find the next point at the specified interval
        local nextTime = point.time + interval
        while currentIndex < #vibratoPoints and vibratoPoints[currentIndex + 1].time < nextTime do
            currentIndex = currentIndex + 1
        end
        
        currentIndex = currentIndex + 1
    end
    
    return controlPoints
end

-- Example usage
function NotesObject:vibrato(ticksPerSecond, noteStartTick, noteDurationTicks, vibratoDelay)
    -- Vibrato parameters
    local vibratoParams = {
        amplitude = 0.5,       -- Half-tone (+/- 50 cents)
        frequency = 5.5,       -- 5.5 Hz (cycles per second)
        sampleRate = 100,      -- 100 samples per second
        attackTime = 0.2,      -- 200ms attack for 0.2
        releaseTime = 0.1,     -- 300ms release for 0.3
        frequencyModulation = {5.5, 5.7, 6.0, 6.2, 6.2, 6.2, 5.0} -- Frequency modulation
        -- frequencyModulation = {5.5, 5.7, 6.0, 6.0, 6.0, 5.7} -- Frequency modulation
    }
    
    -- Generate vibrato points
    local vibratoPoints = self:applyVibratoToNote(
        noteStartTick, 
        noteDurationTicks, 
        ticksPerSecond, 
        vibratoDelay, 
        vibratoParams
    )
    
    -- Convert to control points -- 0.01 = 10ms default
    local controlPoints = self:exportVibratoToControlPoints(vibratoPoints, 0.02)
    
    -- -- Control points
    -- result = result .. "Vibrato control points:"
    -- for i, point in ipairs(controlPoints) do
        -- result = result .. string.format("Time: %.2fs, Value: %.4f", point.time, point.value)
		-- .. "\r"
    -- end
    
    return controlPoints
end

-- Get vibrato model choice
function NotesObject:getModelChoice(model_choice)	
	local percentStartNote = self.modelChoice[model_choice].startNote
	local modulationDepth = self.modelChoice[model_choice].vibratoDepth
	local percentEndNote = self.modelChoice[model_choice].endNote
	
	return percentStartNote, modulationDepth, percentEndNote
end

-- Add vibrato to selected notes
function NotesObject:addVibratoToSelectedNotes(model_choice, override_depth)
	local percentStartNote, modulationDepth, percentEndNote = self:getModelChoice(model_choice)

	-- Loop all selected notes
	for k, note in pairs(self.selectedNotes) do
		local notePos = note:getOnset()
		local notePosEnd = note:getEnd()
		local noteDuration = note:getDuration()
		local paramPitchDelta = self.currentGroupNotes:getParameter(self.PARAMETER_REFERENCE)
		
		self.currentBPM = self:getProjectTempo(notePos)
		self.blicksPerSeconds, self.quarterBlicks = self:getCurrentBlicksPerSecond(notePos)
		
		if self.blicksPerSeconds == -1 then
			self:show(SV:T("ERROR! Tempo not found!"))
			break
		else
			-- Clear all previous pitchDelta parameters
			paramPitchDelta:remove(notePos, notePosEnd)
			
			local newModulationDepth = self.coefModulation * modulationDepth
			if override_depth > 0 then
				newModulationDepth = self.coefModulation * override_depth
			end
			local noteDurationSeconds = self.timeAxis:getSecondsFromBlick(noteDuration)
			local vibratoDelayInSeconds = noteDurationSeconds * percentStartNote / 100
			local notePosStart = 0 -- SV:seconds2Blick(0.02, self.currentBPM)
			if percentEndNote > 0 then
				local endNoteDurationSeconds = noteDurationSeconds * percentEndNote / 100
				local endNoteDuration = self.timeAxis:getBlickFromSeconds(endNoteDurationSeconds)
				noteDuration = noteDuration - endNoteDuration
			end
			
			-- Get vibrato points
			local points = self:vibrato(self.blicksPerSeconds, 
											notePosStart, noteDuration, vibratoDelayInSeconds)
			-- self:saveToClipboard(pointsString)
			self:addPointsToPitchDeltaParameter(notePos, points, newModulationDepth, paramPitchDelta)
		end
	end
end

-- Add points to pitch delta parameter
function NotesObject:addPointsToPitchDeltaParameter(notePos, points, modulationDepth, paramPitchDelta)
	-- Apply vibrato to pitchDelta parameters
	local newPos = notePos
	local isSimplify = false
	
	for k, point in pairs(points) do
		newPos = notePos + self.timeAxis:getBlickFromSeconds(point.time)
		paramPitchDelta:add(newPos, point.value * modulationDepth)
	end

	-- Add a last point to stop pitch modulation
	newPos = newPos + self.timeGapBlicks
	paramPitchDelta:add(newPos, 0)
	
	
	if isSimplify then 
		local threshold = 0.01 -- 0.002 default
		paramPitchDelta:simplify(notePos, newPos, threshold)
	end
end

-- Create user input form
function NotesObject:getForm()
	local comboChoice = {}
	local sliderLoudness = {}
	local overrideDepthDefaultValue = 0
	local overrideDepthMinValue = 0
	local overrideDepthMaxValue = 1.5
	local overrideDepthLevelInterval = 0.5
	
	sliderOverrideDepth = {
			name = "overrideDepth", type = "Slider",
			label = SV:T("Override vibrato depth"),
			format = "%1.1f Depth",
			minValue = overrideDepthMinValue, 
			maxValue = overrideDepthMaxValue, 
			interval = overrideDepthLevelInterval, 
			default = overrideDepthDefaultValue
		}

	if #self.modelChoiceList > 0 then
		comboChoice = {
			name = "modelChoice", type = "ComboBox", label = SV:T("Choose a model"), 
			choices = self.modelChoiceList, default = 0
		}
	end
	
	local form = {
		title = SV:T(SCRIPT_TITLE),
		message = SV:T("Vibrato modulation") .. "\r",
		buttons = "OkCancel",
		widgets = {
			{
				name = "modulationReset", type = "TextArea", 
				label = SV:T("Do not forget to reset Vibrato Modulation to 0") .. "\r"
					.. SV:T("in the Notes Panel!"), 
				height = 0
			},
			comboChoice,
			sliderOverrideDepth,
			{
				name = "separator", type = "TextArea", label = "", height = 0
			},
			
		}
	}
	return SV:showCustomDialog(form)
end

-- Start process
function NotesObject:start()
	local userInput = self:getForm()
	
	if userInput.status then
		if userInput.answers.modelChoice ~= nil then
			local model_choice = userInput.answers.modelChoice + 1 -- see self.modelChoice
			local overrideDepth = userInput.answers.overrideDepth + 1
			self:addVibratoToSelectedNotes(model_choice, overrideDepth)
		end
	end
end

-- Main process
function main()
	local notesObject = NotesObject:new()
	notesObject:start()
	
	SV:finish()
end