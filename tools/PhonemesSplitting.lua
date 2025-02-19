local SCRIPT_TITLE = 'Phonemes Splitting V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: PhonemesSplitting.lua

Split notes into existing phonemes

!!! For testing purpose only !!!

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"note attributes:\r", "note attributes:\r"},
			{"No notes selected!", "No notes selected!"},
			{"notes:\r", "notes:\r"},
			{"k:\r", "k:\r"},
			{"Notes count: ", "Notes count: "},
			{"note added!", "note added!"},
		},
	}
end

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Tools",
		author = "JFAVILES",
		versionNumber = 1,
		minEditorVersion = 65540
	}
end

DEBUG = false

-- trim string
function trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Split string into array separated by space
function splitSpace(argstr)
  local args = {}
  for v in string.gmatch(argstr, "%S+") do
    table.insert(args, v)
  end
  return args
end

-- Get note attributes
function getNoteAttributes(note)
	local noteAttr = note:getAttributes()
	local result = ""
	if noteAttr ~= nil then
		if noteAttr.tF0Offset ~= nil then
			result = result .. 
			"tF0Offset: " .. string.format("%02f", noteAttr.tF0Offset) .. "\r"
		end
		if noteAttr.tF0Left ~= nil then
			result = result .. 
			"tF0Left: " .. string.format("%02f", noteAttr.tF0Left) .. "\r"
		end
		if noteAttr.tF0Right ~= nil then
			result = result .. 
			"tF0Right: " .. string.format("%02f", noteAttr.tF0Right) .. "\r"
		end
		if noteAttr.dF0Left ~= nil then
			result = result .. 
			"dF0Left: " .. string.format("%02f", noteAttr.dF0Left) .. "\r"
		end
		if noteAttr.dF0Right ~= nil then
			result = result .. 
			"dF0Right: " .. string.format("%02f", noteAttr.dF0Right) .. "\r"
		end
		if noteAttr.tF0VbrStart ~= nil then
			result = result .. 
			"tF0VbrStart: " .. string.format("%02f", noteAttr.tF0VbrStart) .. "\r"
		end
		if noteAttr.tF0VbrLeft ~= nil then
			result = result .. 
			"tF0VbrLeft: " .. string.format("%02f", noteAttr.tF0VbrLeft) .. "\r"
		end
		if noteAttr.tF0VbrRight ~= nil then
			result = result .. 
			"tF0VbrRight: " .. string.format("%02f", noteAttr.tF0VbrRight) .. "\r"
		end
		if noteAttr.dF0Vbr ~= nil then
			result = result .. 
			"dF0Vbr: " .. string.format("%02f", noteAttr.dF0Vbr) .. "\r"
		end
		if noteAttr.pF0Vbr ~= nil then
			result = result .. 
			"pF0Vbr: " .. string.format("%02f", noteAttr.pF0Vbr) .. "\r"
		end
		if noteAttr.fF0Vbr ~= nil then
			result = result .. 
			"fF0Vbr: " .. string.format("%02f", noteAttr.fF0Vbr) .. "\r"
		end
		if noteAttr.tNoteOffset ~= nil then
			result = result .. 
			"tNoteOffset: " .. string.format("%02f", noteAttr.tNoteOffset) .. "\r"
		end
		if noteAttr.exprGroup ~= nil then
			result = result .. 
			"exprGroup: " .. noteAttr.exprGroup .. "\r"
		end
		if noteAttr.dur ~= nil and #noteAttr.dur > 0 then
			result = result .. " - dur (" .. tostring(#noteAttr.dur).. "):"
			local sep = " ["
			for iArray = 1, #noteAttr.dur do
				result = result .. 
				sep .. string.format("%3.2f", noteAttr.dur[iArray])
				sep = ", "
			end
			result = result .. "]" .. "\r"
		end
		if noteAttr.alt ~= nil and #noteAttr.alt > 0 then
			result = result .. " - alt (" .. tostring(#noteAttr.alt).. "):"
			local sep = " ["
			for iArray = 1, #noteAttr.alt do
				result = result .. 
				sep .. string.format("%3.2f", noteAttr.alt[iArray])
				sep = ", "
			end
			result = result .. "]"
		end
		if noteAttr.strength ~= nil and #noteAttr.strength > 0 then
			result = result .. " - strength (" .. tostring(#noteAttr.strength).. "):"
			local sep = " ["
			for iArray = 1, #noteAttr.strength do
				result = result .. 
				sep .. string.format("%3.2f", noteAttr.strength[iArray])
				sep = ", "
			end
			result = result .. "]" .. "\r"
		end
		result = result ..  "\r"
	end
	return result
end

-- Get attributes in string
function getSimpleAttributes(attrib)
	local attribStr = ""
	for k,v in pairs(attrib) do
		if type(v) == "table" then
			attribStr = attribStr .. k .. ":"
			for j,w in pairs(v) do
				attribStr = attribStr .. j .. ": " .. tostring(w) .. ","
			end
			attribStr = attribStr  .. "\r"
		else
			attribStr = attribStr .. k .. ": " .. tostring(v) .. "\r"
		end
	end
	return attribStr
end

-- Split lyrics into phonemes
function splitPhonemes()
	local timeAxis = SV:getProject():getTimeAxis()
	local editor = SV:getMainEditor()
	local track = editor:getCurrentTrack()
	local groupsCount = track:getNumGroups()
	local secondDecay = tonumber(secondDecayInput)
	local selection = editor:getSelection()
	local selectedNotes = selection:getSelectedNotes()
	local selectedNotesCount = 0
	
	if #selectedNotes == 0 then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
		return false
	end
	local currentGroupRef = editor:getCurrentGroup()
	local groupNotesMain = currentGroupRef:getTarget()
	local groupPhonemes = SV:getPhonemesForGroup(currentGroupRef)
	local phonemes = {}
	local notesToAdd = {}
	
	for iNote = 1, #selectedNotes do
		local originalNote = selectedNotes[iNote]		
		
		if originalNote ~= nil then
			local previousNote = nil
			local previousNotesDuration = nil
			local attribStr = getNoteAttributes(originalNote) 
			-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("attributes:") .. "\r" .. attribStr)
			-- local attribStr = getSimpleAttributes(attrib)
			-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("attributes:") .. "\r" .. attribStr)
			
			local noteIndex = originalNote:getIndexInParent()
			phonemes[iNote] = groupPhonemes[noteIndex]
			if phonemes[iNote] ~= nil then
				local notePhonemes = phonemes[iNote]
				local notePhonemesArray = splitSpace(notePhonemes)
				
				selectedNotesCount = selectedNotesCount + 1
				local noteAttr = originalNote:getAttributes()
				local lyrics = originalNote:getLyrics()
				local noteUserPhonemes = originalNote:getPhonemes()
				if lyrics == nil then lyrics = "" end
				
				local noteUserPhonemesArray = splitSpace(noteUserPhonemes)
				
				for iNewNote = 1, #notePhonemesArray do
					local note = originalNote:clone()
					
					-- First note
					if iNewNote == 1 then
						note:setOnset(originalNote:getOnset())
						note:setLyrics(originalNote:getLyrics())
						note:setDuration((originalNote:getDuration() / #notePhonemesArray) * 0.3 )
					else
						-- next notes
						note:setOnset(previousNote:getOnset() + previousNote:getDuration())
						note:setLyrics("." .. notePhonemesArray[iNewNote])
						note:setDuration((originalNote:getDuration() / #notePhonemesArray) * 1.5 )
						
						-- last note complete the original note duration
						if iNewNote == #notePhonemesArray then
							if (originalNote:getDuration() - previousNotesDuration) > 0 then
								note:setDuration(originalNote:getDuration() - previousNotesDuration)
							end
						end
						-- note:setDuration((originalNote:getDuration() / #notePhonemesArray) * noteAttr.dur[iNewNote])
						--note:setLyrics(notePhonemesArray[iNewNote])
					end
					
					note:setPitch(originalNote:getPitch())
					note:setPhonemes(notePhonemesArray[iNewNote])
					
					local newNoteAttribute = {}
					--newNoteAttribute.dur = noteAttr.dur[iNewNote]
					--newNoteAttribute.strength = {0.2}
					
					--newNoteAttribute.dur = noteAttr.dur[iNewNote]
					--note:setAttributes(newNoteAttribute)
					table.insert(notesToAdd, note)
					--groupNotesMain:addNote(note)
					
					previousNote = note
					if previousNotesDuration == nil then
						previousNotesDuration = previousNote:getDuration()
					else
						previousNotesDuration = previousNotesDuration + previousNote:getDuration()
					end
				end
				--originalNote:setPitch(originalNote:getPitch()-2)
			end	
		end		
	end
	
	if #notesToAdd > 0 then
		for iNote = 1, #selectedNotes do
			groupNotesMain:removeNote(selectedNotes[iNote]:getIndexInParent())
		end
		for iNote = 1, #notesToAdd do			
			groupNotesMain:addNote(notesToAdd[iNote])
			
		end
	end

	if selectedNotesCount > 0 then
		-- SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Notes count: ") .. tostring(selectedNotesCount))
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("note added!"))
	else
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No notes selected!"))
	end
	return true
end

function main()
	
	splitPhonemes()

	SV:finish()
end