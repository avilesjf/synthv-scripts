SCRIPT_TITLE = "Tuning individual notes microtonality V1.1"
--[[

Synthesizer V Studio Pro Script
 
lua file name: TunerSL.lua

This script will update pitchDelta for microtonality
for each individual key for note

Initial (js) source code is from Dannyu NDos

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Tuner", "Tuner"},
			{"Slide for new values.", "Slide for new values."},
			{"Select notes before execution of this script.", "Select notes before execution of this script."},
		},
	}
end

function getClientInfo()
    return {
        name = "TunerSL",
        category = "Dannyu NDos",
        author = "Dannyu NDos",
        versionNumber = 1,
        minEditorVersion = 67840
    }
end

-- lua round
function round(n)
  return math.floor((math.floor(n*2) + 1)/2)
end

-- Get slider content
function getSlider(note, notesDefaultValue, indice)
	local fmt = "%1.0f"
	local minVal = -60
	local maxVal = 60
	local interVal = 1
	
	local slider = {
		name = indice,  
		type = "Slider", 
		label = note,
		format = fmt, 
		minValue = minVal, 
		maxValue = maxVal, 
		interval = interVal, 
		default = notesDefaultValue
	}
	return slider
end

-- Get all sliders
function getAllSliders(notes, notesValDefault)
	local sliders = {}
	
	for iNote = 1, #notes do
		table.insert(sliders, 
			getSlider(notes[iNote], 
						notesValDefault[iNote], 
						tostring(iNote - 1))
		)
	end
	return sliders
end

-- Get form dialog
function getForm(widgetsContent)
	local form = {
		title = SV:T("Tuner"),
		message = SV:T("Slide for new values."),
		buttons = "OkCancel",
		widgets = widgetsContent
	}
	return SV:showCustomDialog(form)
end

-- process pitchDelta
function processPitchDelta(resultForm, selectedNotes)
	local noteGroup = SV:getMainEditor():getCurrentGroup():getTarget()
	local automation = noteGroup:getParameter("pitchDelta")
	
	for i = 1, #selectedNotes do
		local note = selectedNotes[i]
		local pitch = round(note:getPitch())
		local pitchMod = pitch % 12
		
		-- local newPitch = strToPitch(result.answers[tostring(pitchMod)]) - 100 * pitchMod
		local newPitch = resultForm.answers[tostring(pitchMod)]
		if newPitch ~= nil then
			automation:remove(note:getOnset(), note:getEnd())
			automation:add(note:getOnset(), newPitch)
			automation:add(note:getEnd() - 1, newPitch)
		end
	end
	
	-- Add first and last automation
	local firstSelectedNotes = selectedNotes[1]
	local lastSelectedNotes = selectedNotes[#selectedNotes]
	automation:add(firstSelectedNotes:getOnset() -1, 0)
	automation:add(lastSelectedNotes:getEnd() + 1, 0)
end

-- Main process
function main()
	local notes = { "C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B" }
	local notesDefaultValue = { 0, 5, 4, -2, -13, -2, 3, 2, -4, -15, -4, 1}
    
    local selectedNotes = SV:getMainEditor():getSelection():getSelectedNotes()
    
	if #selectedNotes == 0 then
        SV:showMessageBox(SV:T("Tuner"), SV:T("Select notes before execution of this script."))
    else		
		local slContent = getAllSliders(notes, notesDefaultValue)		
		local resultForm = getForm(slContent)
		
		if resultForm.status then
			processPitchDelta(resultForm, selectedNotes)
		end
	end
	
    SV:finish()
end

