local SCRIPT_TITLE = 'Clear the clipboard content V1.0'

--[[

Synthesizer V Studio Pro Script
 
lua file name: ClearClipboard.lua

Clear the clipboard to clean his content

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Clipboard is cleared!", "Clipboard is cleared!"},
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

-- Main processing task	
function main()
	
	SV:setHostClipboard("")
	SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Clipboard is cleared!"))
	SV:finish()
end
