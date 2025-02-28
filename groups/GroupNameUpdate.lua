local SCRIPT_TITLE = 'Group name update V1.0'

--[[

lua file name: GroupNameUpdate.lua

Update one selected group name with the updated lyrics inside.

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"No group selected found!", "No group selected found!"},
			{"Goup active is:", "Goup active is:"},
			{"Nothing to do!", "Nothing to do!"},
			{"Please select one group!", "Please select one group!"},
			{"Group name already updated (nothing to do!):", "Group name already updated (nothing to do!):"},
			{"Group renamed from:", "Group renamed from:"},
			{"Group renamed to:", "Group renamed to:"},
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

-- Limit string max length
function limitStringLength(resultLyrics, maxLengthResult)
	-- Limit string max length
	if string.len(resultLyrics) > maxLengthResult then
		local posStringChar = string.find(resultLyrics," ", maxLengthResult - 10)
		if posStringChar == nil then posStringChar = maxLengthResult end
		resultLyrics = string.sub(resultLyrics, 1, posStringChar)
	end
	return resultLyrics
end

-- Check lyrics "a" less than .1s for special effect
function isLyricsEffect(timeAxis, note)
	local result = false
	local notelength = timeAxis:getSecondsFromBlick(note:getDuration())
	-- ie: 0.0635
	if notelength < 0.1 then
		result = true
	end
	return result
end

-- Is lyrics is a text accepted
function isTextAccepted(timeAxis, note)
	local result = false
	local lyrics = note:getLyrics()
	
	-- Filter char '+' & '++' & '-' & 'br' & ' & .cl & .pau & .sil
	if lyrics ~= "+" and lyrics ~= "++" and lyrics ~= "-" and lyrics ~= "br" and lyrics ~= "'" 
		and lyrics ~= ".cl" and lyrics ~= ".pau" and lyrics ~= ".sil"  then
		result = true
	end
	
	-- Specific for personal vocal effect
	if lyrics == "a" and isLyricsEffect(timeAxis, note) then
		result = false
	end

	return result
end

-- Start check current group
function RenameGroup()
	local maxLengthResult = 30
	local editor = SV:getMainEditor()
	local ref = editor:getCurrentGroup()
	local project = SV:getProject()
	local timeAxis = project:getTimeAxis()

	if ref == nil then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No group selected found!"))
	else		
		local noteGroup = ref:getTarget()
		local groupName = noteGroup:getName()
		if groupName == "main" then
			local resultMessage = SV:T("Goup active is:") .. " \"" .. groupName .. "\"" .. "\r"
			 .. SV:T("Nothing to do!")  .. "\r"
			 .. SV:T("Please select one group!")
			SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage)
		else
			local resultLyrics = renameOneGroup(timeAxis, maxLengthResult, noteGroup)

			-- Result infos
			if string.len(resultLyrics) > 0 then
				local resultMessage = SV:T("Group name already updated (nothing to do!):") .. "\r" .. resultLyrics .. "\r"
				-- Message result
				if groupName ~= resultLyrics then
					resultMessage = SV:T("Group renamed from:") .. " " .. groupName .. "\r" 
						.. "to" .. "\r" 
						.. SV:T("Group renamed to:") .. " " .. resultLyrics .. "\r"
				end
				SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage)
			end
		end
	end
end

-- Rename one group
function renameOneGroup(timeAxis, maxLengthResult, noteGroup)
	local resultLyrics = ""
	local groupName = noteGroup:getName()
	local notesCount = noteGroup:getNumNotes()

	if notesCount > 0 then
		local lyricsLine = ""
		local sep = ""

		for i = 1, notesCount do
			local infos = ""
			local note = noteGroup:getNote(i)
			
			if note ~= nil then
				local lyrics = note:getLyrics()			
				if string.len(lyrics) > 0 then
				
					-- Filter char '+' & '-' & 'br' & ' & .cl & .pau & .sil
					if isTextAccepted(timeAxis, note) then
						-- Replace following note char '-'
						if lyrics == "-" then lyrics = ".." end 
						-- Add lyrics for each note
						lyricsLine = lyricsLine .. sep .. lyrics
						sep = " "
					end
				end
			end
		end

		-- Add lyrics
		resultLyrics = limitStringLength(lyricsLine, maxLengthResult)
		-- Update if new lyrics only
		if string.len(resultLyrics)> 0 and
			noteGroup:getName() ~= resultLyrics then
			noteGroup:setName(resultLyrics)
		end
	end

	return resultLyrics
end


function main()

  RenameGroup()
  SV:finish()
end