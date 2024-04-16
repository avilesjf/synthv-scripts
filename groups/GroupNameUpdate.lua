local SCRIPT_TITLE = 'Group name update V1.0'

--[[

lua file name: GroupNameUpdate.lua

Update one selected group name with the updated lyrics inside.

2024 - JF AVILES
--]]

function getClientInfo()
	return {
		name = SV:T(SCRIPT_TITLE),
		category = "_JFA_Lyrics",
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

-- Start check current group
function RenameGroup()
	local maxLengthResult = 30
	local editor = SV:getMainEditor()
	local ref = editor:getCurrentGroup()

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
			local resultLyrics = renameOneGroup(maxLengthResult, noteGroup)

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
function renameOneGroup(maxLengthResult, noteGroup)
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
				
				  -- Filter char '+' & '-'
				  if lyrics ~= "+" then 
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
		if noteGroup:getName() ~= resultLyrics then noteGroup:setName(resultLyrics)	end
	end

	return resultLyrics
end


function main()

  RenameGroup()
  SV:finish()
end