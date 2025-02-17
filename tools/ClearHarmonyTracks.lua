local SCRIPT_TITLE = 'Clear harmony tracks V1.0'

--[[

lua file name: ClearHarmonyTracks.lua

Delete all tracks with the name begin with "Track H"
to use during GroupHarmony script attempts

2024 - JF AVILES
--]]

function getTranslations(langCode)
	return getArrayLanguageStrings()[langCode]
end

function getArrayLanguageStrings()
	return {
		["en-us"] = {
			{"Track H", "Track H"},
			{"Delete tracks with name begin with", "Delete tracks with name begin with"},
			{"found:", "found:"},
			{"Use 'CTRL-Z' to recover your deleted tracks", "Use 'CTRL-Z' to recover your deleted tracks"},
			{"No harmony tracks to delete!", "No harmony tracks to delete!"},
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

-- Define a class  "NotesObject"
InternalData = {
	SEP_KEYS = "/",
	trackNameHarmony = SV:T("Track H"),
	tracks = {},
	DEBUG = false,
	logs = {
		logs = "",
		add = function(self, new) 
				if InternalData.DEBUG then self.logs = self.logs .. new end
			end,
		clear = function(self) 
					if InternalData.DEBUG then self.logs = "" end
				end,
		showLogs = function(self) 
					if InternalData.DEBUG then 
						commonTools.show(self.logs)
					end
				end
	}
}

-- Common tools
commonTools = {
	-- Display message box: commonTools.show()
	show = function(message)
		SV:showMessageBox(SV:T(SCRIPT_TITLE), message)
	end,
	
	-- Create user input form
	getForm = function()
			
		local form = {
			title = SV:T(SCRIPT_TITLE),
			message = SV:T("Delete tracks with name begin with") .. " '" 
					.. InternalData.trackNameHarmony .. "' (" .. SV:T("found:") .. " " .. #InternalData.tracksToDelete .. ")",
			buttons = "OkCancel",
			widgets = {
				{
					name = "infos", type = "TextArea", label = SV:T("Use 'CTRL-Z' to recover your deleted tracks"), height = 0
				},
				{
					name = "separator", type = "TextArea", label = "", height = 0
				}
			}
		}
		return SV:showCustomDialog(form)
	end,

	-- Start to transpose notes
	start = function()
		local project = SV:getProject()
		local tracksToDelete = 0
		InternalData.logs:clear()
		
		InternalData.tracksToDelete = commonTools.getTracksToDelete(project)
		
		-- Check tracks to delete
		if #InternalData.tracksToDelete == 0 then
			commonTools.show(SV:T("No harmony tracks to delete!"))
		else		
			local userInput = commonTools.getForm()
			
			if userInput.status then
				commonTools.deleteTracks(project)
			end
		end
	end,
	
	-- Delete tracks
	deleteTracks = function(project)
		local result = false
		local iTracks = project:getNumTracks()
		
		-- Delete Tracks
		for iTrack = 1, #InternalData.tracksToDelete do
			local trackToDelete = InternalData.tracksToDelete[iTrack]
			local index = trackToDelete:getIndexInParent()
			if string.find(trackToDelete:getName(), InternalData.trackNameHarmony) ~= nil then
				project:removeTrack(index)
				result = true
			end
		end
		return result
	end,
	
	-- Get tracks to delete
	getTracksToDelete = function(project)
		local result = false
		local numTracks = project:getNumTracks()
		local tracksToDelete = {}
		for iTrack = 1, numTracks do
			local track = project:getTrack(iTrack)
			if string.find(track:getName(), InternalData.trackNameHarmony) ~= nil then
				table.insert(tracksToDelete, track)
			end
		end
		return tracksToDelete
	end,
}

function main()
	commonTools.start()
	SV:finish()
end