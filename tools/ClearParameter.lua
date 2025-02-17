local SCRIPT_TITLE = 'Clear parameters V1.0'

--[[

lua file name: ClearParameters.lua

Copy and transpose a selected group on a new track
Initial source code from "vocatart" author

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"No group selected found!", "No group selected found!"},
			{"Parameters cleared!", "Parameters cleared!"},
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
  
function main()
	local editor = SV:getMainEditor()
	local refGroup = editor:getCurrentGroup()

	if refGroup == nil then
		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("No group selected found!"))
	else
		local mainGroup = refGroup:getTarget()

		local pitch = mainGroup:getParameter("PitchDelta")
		local vibrato = mainGroup:getParameter("vibratoEnv")
		local loudness = mainGroup:getParameter("loudness")
		local tension = mainGroup:getParameter("tension")
		local breath = mainGroup:getParameter("breathiness")
		local voicing = mainGroup:getParameter("voicing")
		local gender = mainGroup:getParameter("gender")
		-- tone shift, rap info, sound intensity missing

		pitch:removeAll()
		vibrato:removeAll()
		loudness:removeAll()
		tension:removeAll()
		breath:removeAll()
		voicing:removeAll()
		gender:removeAll()

		SV:showMessageBox(SV:T(SCRIPT_TITLE), SV:T("Parameters cleared!"))
	end
	SV:finish()
end
