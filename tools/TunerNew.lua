SCRIPT_TITLE = "Tuning individual notes microtonality V1.2"
--[[

Synthesizer V Studio Pro Script
 
lua file name: TunerNew.lua

This script will update pitchDelta for microtonality
for each individual key for note
Adding first and last automation point to keep clean previous and next notes.

Initial (js) source code is from Dannyu NDos

2025 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Tuner", "Tuner"},
			{"Separated characters (/ or `) not found!", "Separated characters (/ or `) not found!"},
			{"Error in separated characters!", "Error in separated characters!"},
			{"Select notes before execution of this script.", "Select notes before execution of this script."},
			{"Enter just interval ratios.", "Enter just interval ratios."},
		},
	}
end

function getClientInfo()
    return {
        name = "TunerNew",
        category = "Dannyu NDos",
        author = "Dannyu NDos",
        versionNumber = 2,
        minEditorVersion = 67840
    }
end

local sepCharQuote = "`"
local sepCharSlash = "/"
local defaultTunningChoice = 1 -- addTunning(1 to n) => 1 = 22edo pajara[12] LLsLLLLLsLLL
local isPrintActive = false -- Debug to console terminal

-- Add tunning data
function addTunning()
	local tuningArray = {}
	table.insert(tuningArray, "0`22 2`22 4`22 5`22 7`22 9`22 11`22 13`22 15`22 16`22 18`22 20`22")		-- 22edo pajara[12] LLsLLLLLsLLL
	table.insert(tuningArray, "0`12 1`12 2`12 3`12 4`12 5`12 6`12 7`12 8`12 9`12 10`12 11`12")			-- 12edo
	table.insert(tuningArray, "0`19 1`19 3`19 4`19 6`19 8`19 9`19 11`19 12`19 14`19 15`19 17`19")		-- 19edo meantone[12] sLsLLsLsLsLL
	table.insert(tuningArray, "0`31 2`31 5`31 8`31 10`31 13`31 15`31 18`31 20`31 23`31 25`31 28`31")	-- 31edo meantone[12] sLsLLsLsLsLL
	table.insert(tuningArray, "1/1 17/16 9/8 19/16 5/4 4/3 17/12 3/2 19/12 5/3 16/9 17/9")				-- 19-limit just intonation
	return tuningArray
end

-- Split string by sep char
function split(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
	  table.insert(result, each)
   end
   return result
end

-- lua round
function round(n)
  return math.floor((math.floor(n * 2) + 1) / 2)
end

-- String to pitch
function strToPitch(answerValues, sepChar)
	local result = 0
	local numAndDenom = split(answerValues, sepChar)

	if (2 == #numAndDenom) then
		local num = tonumber(numAndDenom[1])
		local denom = tonumber(numAndDenom[2])
		-- "`"
		if sepChar == sepCharQuote then
			if (0 < denom) then
				result = 1200 / denom * num
				if isPrintActive then SV:print("denom:", denom, "num:", num, "result:", result) end
			end
		end
		-- "/"
		if sepChar == sepCharSlash then
			if (0 < num and 0 < denom) then
				result = 1200 * math.log(num / denom) / math.log(2)
				-- result = 1200 * math.log(num / denom)
			end
        end
    end
	return result
end

-- Get separated char
function getSepChar(splitChar)
	local sepChar = ""
	if string.find(splitChar, sepCharSlash) ~= nil then
		sepChar = sepCharSlash
	end
	if string.find(splitChar, sepCharQuote)  ~= nil then
		sepChar = sepCharQuote
	end
	return sepChar
end

function main()
	local error = false
	local errorMessage = ""
	local tuningArray = {}
    local noteGroup = SV:getMainEditor():getCurrentGroup():getTarget()
    local selectedNotes = SV:getMainEditor():getSelection():getSelectedNotes()
    if #selectedNotes == 0 then
        SV:showMessageBox(SV:T("Tuner"), SV:T("Select notes before execution of this script."))
        SV:finish()
        return
    end
	tuningArray = addTunning() -- Add tunning data
	local currentTunning = tuningArray[defaultTunningChoice]  -- 22edo pajara[12] LLsLLLLLsLLL
	local intervals = split(currentTunning, " ")
	
    local form = {
        title = SV:T("Tuner"),
        message = SV:T("Enter just interval ratios."),
        buttons = "OkCancel",
        widgets = {
            { name = "0",  type = "TextBox", label = "C",	default = intervals[1] },
            { name = "1",  type = "TextBox", label = "D♭",	default = intervals[2] },
            { name = "2",  type = "TextBox", label = "D",	default = intervals[3] },
            { name = "3",  type = "TextBox", label = "E♭",	default = intervals[4] },
            { name = "4",  type = "TextBox", label = "E",	default = intervals[5] },
            { name = "5",  type = "TextBox", label = "F",	default = intervals[6] },
            { name = "6",  type = "TextBox", label = "G♭",	default = intervals[7] },
            { name = "7",  type = "TextBox", label = "G",	default = intervals[8] },
            { name = "8",  type = "TextBox", label = "A♭",	default = intervals[9] },
            { name = "9",  type = "TextBox", label = "A",	default = intervals[10] },
            { name = "10", type = "TextBox", label = "B♭",	default = intervals[11] },
            { name = "11", type = "TextBox", label = "B",	default = intervals[12] }
        }
    }
    local result = SV:showCustomDialog(form)
	
    if result.status then
        local automation = noteGroup:getParameter("pitchDelta")
		if isPrintActive then SV:print("START") end
        for i = 1, #selectedNotes do
            local note = selectedNotes[i]
            local pitch = round(note:getPitch())
            local pitchMod = pitch % 12
			
			local answerValues = result.answers[tostring(pitchMod)]
			local sepChar = getSepChar(answerValues)
			if isPrintActive then SV:print("answerValues:", answerValues, "sepChar:" , sepChar) end
			if #sepChar == 0 then
				errorMessage = SV:T("Separated characters (/ or `) not found!")
				if isPrintActive then SV:print("errorMessage:", errorMessage) end
				error = true
				break
			else
				local pitchValue = strToPitch(answerValues, sepChar)
				local newPitch = pitchValue - 100 * pitchMod
				if isPrintActive then SV:print("pitchValue:", pitchValue, "newPitch:", newPitch, "pitchMod:", pitchMod) end
				if newPitch ~= nil then
					automation:remove(note:getOnset(), note:getEnd())
					automation:add(note:getOnset(), newPitch)
					automation:add(note:getEnd() - 1, newPitch)
				end
			end
        end
		
		if error then
			SV:showMessageBox(SV:T("Tuner"), SV:T("Error in separated characters!"))
		else
			-- Add first and last automation to keep clean previous and next notes
			local firstSelectedNotes = selectedNotes[1]
			local lastSelectedNotes = selectedNotes[#selectedNotes]
			automation:add(firstSelectedNotes:getOnset() - 10, 0)
			automation:add(lastSelectedNotes:getEnd() + 1, 0)
		end
    end
    SV:finish()
end

