local SCRIPT_TITLE = 'Groups name update All V1.0'

--[[

lua file name: GroupsNameUpdateAll.lua

Update group name with lyrics for each group of notes of the project

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Tracks count:", "Tracks count:"},
			{"Groups count:", "Groups count:"},
			{"Groups with no lyrics count:", "Groups with no lyrics count:"},
			{"Groups with no lyrics:", "Groups with no lyrics:"},
			{"Groups updated count:", "Groups updated count:"},
			{"No group updated!", "No group updated!"},
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

-- Rename all groups name (if new lyrics only)
function RenameGroups()
	local maxLengthResult = 30
	local project = SV:getProject()
	local timeAxis = project:getTimeAxis()
	local trackCount = project:getNumTracks()
	local groupsInTracksCount = 0
	local updatedGroupsCount = 0
	local updatedGroupsNames = ""
	local noLyricsFoundInGroupsCount = 0
	local noLyricsFoundInGroupsNames = ""
	local sep = ""
	
	for i = 1, trackCount do
		local track = project:getTrack(i)
		local trackName = track:getName()
		local groupsCount = track:getNumGroups()
		groupsInTracksCount = groupsInTracksCount + groupsCount
		
		for j = 1, groupsCount do
		  local ref = track:getGroupReference(j)
		  local noteGroup = ref:getTarget()
		  local groupName = noteGroup:getName()
		  
		  local resultLyrics = renameOneGroup(timeAxis, maxLengthResult, noteGroup)
		  
		  -- No lyrics found!
		  if groupName ~= "main" then
			  if string.len(resultLyrics) == 0 then 
				noLyricsFoundInGroupsCount = noLyricsFoundInGroupsCount + 1
				noLyricsFoundInGroupsNames = noLyricsFoundInGroupsNames .. sep .. groupName
				sep = "\r"
			  end
			  
			  if string.len(resultLyrics) > 0 and groupName ~= resultLyrics then
				updatedGroupsCount = updatedGroupsCount + 1 
				updatedGroupsNames = updatedGroupsNames .. trackName .. " = " .. groupName .. " ==> " .. resultLyrics .. "\r"
			  end
		  end
		end
	end
    
	-- Message result		
	local resultMessage = SV:T("Tracks count:") .. string.format(" %01d", trackCount)  .. "\r"
		.. SV:T("Groups count:") .. string.format(" %01d", groupsInTracksCount) .. "\r"
		
	if noLyricsFoundInGroupsCount > 0 then
		resultMessage = resultMessage .. "\r".. SV:T("Groups with no lyrics count:") .. string.format(" %01d", noLyricsFoundInGroupsCount) 
			.. "\r".. SV:T("Groups with no lyrics:") .. noLyricsFoundInGroupsNames
	end
	
	if updatedGroupsCount > 0 then
		resultMessage = resultMessage .. "\r".. SV:T("Groups updated count:") .. string.format(" %01d", updatedGroupsCount) .. "\r"
		resultMessage = resultMessage .. updatedGroupsNames .. "\r"
	else 
		resultMessage = resultMessage .. "\r".. SV:T("No group updated!") .. "\r"
	end
	
	SV:showMessageBox(SV:T(SCRIPT_TITLE), resultMessage)
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

	RenameGroups()
	SV:finish()

end