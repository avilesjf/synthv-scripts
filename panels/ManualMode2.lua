local SCRIPT_TITLE = 'Manual Pitch Mode 2'
--[[
Synthesizer V Studio Pro Script
 
lua file name: ManualMode2.lua
Update: 1 - Js to lua & Minor updates
		4 - Add button apply
		5 - Adding Progressive Vibrato

See below for "Default values"

"Vibrato Fade-In/-Out" control: Value from 0% to 100%
0% = vibrato at full amplitude,	100% = vibrato gradually increases throughout the vibrato duration
		
2025 - Dreamtonics (updated by JF AVILES)
--]]

function getClientInfo()
  return {
    name = SCRIPT_TITLE,
    -- category = "Utilities",
    author = "Dreamtonics",
    versionNumber = 5,
    minEditorVersion = 131329,
    type = "SidePanelSection"
  }
end

function getTranslations(langCode)
  if langCode == "ja-jp" then
    return {
      {"Manual Pitch Mode", "マニュアルピッチモード"},
      {"Manual Mode", "マニュアルモード"},
      {"Transition Offset", "ピッチ遷移オフセット"},
      {"Transition Width", "ピッチ遷移の長さ"},
      {"Vibrato Start Position", "ビブラート開始位置"},
      {"Vibrato Frequency", "ビブラート周波数"},
      {"Vibrato Depth", "ビブラート深度"},
      {"Vibrato Fade-In", "ビブラートフェードイン"},
      {"Vibrato Fade-Out", "ビブラートフェードアウト"},
      {"Invert Vibrato Direction", "ビブラートの向きを逆相にする"},
      {"beats", "拍"},
      {"%", "%"},
      {"Hz", "Hz"},
      {"cents", "セント"},
      {"No notes selected", "ノートが選択されていません"},
      {"Applied to", "適用済み: "},
      {"note(s)", "個のノート"},
      {" selected", "を選択中"},
      {"enabled", "オン"},
      {"disabled", "オフ"},
      {" enabled (mixed)", " 個のノートがオン"}
    }
  elseif langCode == "zh-cn" then
    return {
      {"Manual Pitch Mode", "手动音高模式"},
      {"Manual Mode", "手动模式"},
      {"Transition Offset", "音高过渡偏移"},
      {"Transition Width", "音高过渡时长"},
      {"Vibrato Start Position", "颤音开始位置"},
      {"Vibrato Frequency", "颤音频率"},
      {"Vibrato Depth", "颤音幅度"},
      {"Vibrato Fade-In", "颤音渐强"},
      {"Vibrato Fade-Out", "颤音渐弱"},
      {"Invert Vibrato Direction", "反转颤音相位"},
      {"beats", "拍"},
      {"%", "%"},
      {"Hz", "Hz"},
      {"cents", "音分"},
      {"No notes selected", "未选择音符"},
      {"Applied to", "已应用于"},
      {"note(s)", "个音符"},
      {" selected", "已选择"},
      {"enabled", "已启用"},
      {"disabled", "已禁用"},
      {" enabled (mixed)", " 个音符已启用"}
    }
  elseif langCode == "zh-tw" then
    return {
      {"Manual Pitch Mode", "手動音高模式"},
      {"Manual Mode", "手動模式"},
      {"Transition Offset", "音高過渡偏移"},
      {"Transition Width", "音高過渡時長"},
      {"Vibrato Start Position", "顫音開始位置"},
      {"Vibrato Frequency", "顫音頻率"},
      {"Vibrato Depth", "顫音幅度"},
      {"Vibrato Fade-In", "顫音漸強"},
      {"Vibrato Fade-Out", "顫音漸弱"},
      {"Invert Vibrato Direction", "反轉顫音相位"},
      {"beats", "拍"},
      {"%", "%"},
      {"Hz", "Hz"},
      {"cents", "音分"},
      {"No notes selected", "未選擇音符"},
      {"Applied to", "已應用於"},
      {"note(s)", "個音符"},
      {" selected", "已選擇"},
      {"enabled", "已啟用"},
      {"disabled", "已停用"},
      {" enabled (mixed)", " 個音符已啟用"}
    }
  end
  return {}
end

-- Default values
local pitchTransitionOffsetDefaultValue = 0.0
local pitchTransitionWidthDefaultValue = 0.05
local vibratoStartTimeDefaultValue = 15
local vibratoFrequencyDefaultValue = 5.0
local vibratoDepthDefaultValue = 50
local vibratoFadeInDefaultValue = 0
local vibratoFadeOutDefaultValue = 0 -- 75
local invertVibratoDirectionDefaultValue = false

controls = {
  pitchTransitionOffset = {
    value = SV:create("WidgetValue"),
    defaultValue = pitchTransitionOffsetDefaultValue,
    paramKey = "mm_PTO"
  },
  pitchTransitionWidth = {
    value = SV:create("WidgetValue"),
    defaultValue = pitchTransitionWidthDefaultValue,
    paramKey = "mm_PW"
  },
  vibratoStartTime = {
    value = SV:create("WidgetValue"),
    defaultValue = vibratoStartTimeDefaultValue,
    paramKey = "mm_VS"
  },
  vibratoFrequency = {
    value = SV:create("WidgetValue"),
    defaultValue = vibratoFrequencyDefaultValue,
    paramKey = "mm_VF"
  },
  vibratoDepth = {
    value = SV:create("WidgetValue"),
    defaultValue = vibratoDepthDefaultValue,
    paramKey = "mm_VD"
  },
  vibratoFadeIn = {
    value = SV:create("WidgetValue"),
    defaultValue = vibratoFadeInDefaultValue,
    paramKey = "mm_VFI"
  },
  vibratoFadeOut = {
    value = SV:create("WidgetValue"),
    defaultValue = vibratoFadeOutDefaultValue,
    paramKey = "mm_VFO"
  },
  invertVibratoDirection = {
    value = SV:create("WidgetValue"),
    defaultValue = invertVibratoDirectionDefaultValue,
    paramKey = "mm_IVD"
  }
}
resetButtonValue = SV:create("WidgetValue")
applyButtonValue = SV:create("WidgetValue")
statusTextValue = SV:create("WidgetValue")

-- Initialize widget values
for key, control in pairs(controls) do
  control.value:setValue(control.defaultValue)
end

statusTextValue:setValue(SV:T("No notes selected"))
statusTextValue:setEnabled(false)

PITCH_CONTROL_KEYS = {
  manualModeFlag = "mm_Flag"
}

function loadNoteParameters(note)
  local ret = { enabled = false }
  for key, control in pairs(controls) do
    local noteValue = note:getScriptData(control.paramKey)
    if noteValue ~= nil then
      ret[key] = noteValue
      ret.enabled = true
    else
      ret[key] = control.defaultValue
    end
  end
  return ret
end

function saveNoteParameters(note, params)
  for key, control in pairs(controls) do
    note:setScriptData(control.paramKey, params[key])
  end
end

function resetNoteParameters(note)
  for key, control in pairs(controls) do
    note:removeScriptData(control.paramKey)
  end
end

function updateWidgetValues(params)
  for key, control in pairs(controls) do
    control.value:setValue(params[key])
  end
end

function loadNoteParametersFromWidgetValues()
  local ret = {}
  for key, control in pairs(controls) do
    ret[key] = control.value:getValue()
  end
  return ret
end

function findPreviousNote(currentNote, group)
  local currentIndex = currentNote:getIndexInParent()
  if currentIndex > 1 then
    return group:getNote(currentIndex - 1)
  end
  return nil
end

function findNextNote(currentNote, group)
  local currentIndex = currentNote:getIndexInParent()
  if currentIndex < group:getNumNotes() - 1 then
    return group:getNote(currentIndex + 1)
  end
  return nil
end

function isManualModeEnabled(note)
  local params = loadNoteParameters(note)
  return params.enabled
end

function clearPitchControlsInRange(group, startPos, endPos)
  local pitchControlsToRemove = {}
  
  for i = 1, group:getNumPitchControls() do
    local pitchControl = group:getPitchControl(i)
    local controlStart, controlEnd
    if pitchControl:getScriptData(PITCH_CONTROL_KEYS.manualModeFlag) ~= true then
      goto continue
    end
    
    if pitchControl.type == "PitchControlCurve" then
      local points = pitchControl:getPoints()
      if points and #points > 0 then
        local curvePos = pitchControl:getPosition()
        controlStart = curvePos + points[1][1]
        controlEnd = curvePos + points[#points][1]
      else
        controlStart = pitchControl:getPosition()
        controlEnd = controlStart
      end
    else
      controlStart = pitchControl:getPosition()
      controlEnd = controlStart
    end
    
    if not (controlEnd < startPos or controlStart > endPos) then
      table.insert(pitchControlsToRemove, i)
    end
    ::continue::
  end
  
  for i = #pitchControlsToRemove, 1, -1 do
    group:removePitchControl(pitchControlsToRemove[i])
  end
end

function addPitchControlsToNote(note, groupRef, rangeStart, rangeEnd, addNegativePitchTransition)
  local params = loadNoteParameters(note)
  local group = groupRef:getTarget()
  -- Get note timing information
  local noteOnset = note:getOnset() -- in blicks
  local noteDuration = note:getDuration() -- in blicks
  local noteEnd = noteOnset + noteDuration
  local vibratoStartPosition = noteOnset + (noteDuration * params.vibratoStartTime / 100.0)
  local basePitch = note:getPitch()
  local transitionBlicks = params.pitchTransitionOffset * SV.QUARTER
  local transitionPoint = noteOnset + transitionBlicks
  local transitionWidth = params.pitchTransitionWidth * SV.QUARTER
  transitionPoint = math.max(transitionPoint, rangeStart + transitionWidth)
  transitionPoint = math.min(transitionPoint, rangeEnd - transitionWidth)
  -- Apply pitch transition offset
  if addNegativePitchTransition or params.pitchTransitionOffset > 0 then
    -- Create a pitch control point to shift transition timing
    local previousNote = findPreviousNote(note, group)
    local transitionPitches = {basePitch, basePitch, basePitch}
    if previousNote and previousNote:getEnd() == noteOnset then
      transitionPitches[1] = previousNote:getPitch()
      transitionPitches[2] = (previousNote:getPitch() + basePitch) / 2
    end
    
    local relativePositions = {-1, 0, 1}
    for i = 1, 3 do
      local transitionPitchPoint = SV:create("PitchControlPoint")
      transitionPitchPoint:setPosition(transitionPoint + relativePositions[i] * transitionWidth)
      transitionPitchPoint:setPitch(transitionPitches[i])
      transitionPitchPoint:setScriptData(PITCH_CONTROL_KEYS.manualModeFlag, true)
      group:addPitchControl(transitionPitchPoint)
    end
  end
  
  -- Create flat section before vibrato starts
  if vibratoStartPosition > transitionPoint + transitionWidth + SV.QUARTER / 8 then
    local flatCurve = SV:create("PitchControlCurve")
    flatCurve:setPosition(transitionPoint + transitionWidth)
    flatCurve:setPitch(basePitch) -- Absolute MIDI pitch
    flatCurve:setScriptData(PITCH_CONTROL_KEYS.manualModeFlag, true)
    
    local flatPoints = {
      {SV.QUARTER / 16, 0},
      {vibratoStartPosition - transitionPoint - transitionWidth - SV.QUARTER / 16, 0}
    }
    flatCurve:setPoints(flatPoints)
    
    group:addPitchControl(flatCurve)
  end
  
  -- Generate vibrato points with progressive fade-in and fade-out
  if params.vibratoDepth > 0 and params.vibratoFrequency > 0 and params.vibratoStartTime < 100 then
    -- Calculate vibrato period in seconds
    local project = SV:getProject()
    local timeAxis = project:getTimeAxis()
    local periodSeconds = 1.0 / params.vibratoFrequency
    local noteStartSeconds = timeAxis:getSecondsFromBlick(noteOnset + groupRef:getTimeOffset())
    local periodBlicks = timeAxis:getBlickFromSeconds(noteStartSeconds + periodSeconds) 
                       - timeAxis:getBlickFromSeconds(noteStartSeconds)
    
    -- Calculate fade-in and fade-out duration in blicks
    local vibratoDuration = noteEnd - vibratoStartPosition
    local fadeInDuration = vibratoDuration * params.vibratoFadeIn / 100.0
    local fadeOutDuration = vibratoDuration * params.vibratoFadeOut / 100.0
    
    -- Generate vibrato points from start position to note end
    local currentPosition = vibratoStartPosition
    local halfCycleCount = 0
    
    while currentPosition < noteEnd do
      -- Skip the first point to make transition smoother
      if halfCycleCount > 0 and currentPosition >= rangeStart and currentPosition <= rangeEnd then
        -- Calculate fade-in multiplier (0.0 to 1.0)
        local fadeMultiplier = 1.0
        local timeIntoVibrato = currentPosition - vibratoStartPosition
        
        -- Apply fade-in
        if fadeInDuration > 0 and timeIntoVibrato < fadeInDuration then
          fadeMultiplier = timeIntoVibrato / fadeInDuration
        end
        
        -- Apply fade-out
        if fadeOutDuration > 0 then
          local timeUntilEnd = noteEnd - currentPosition
          if timeUntilEnd < fadeOutDuration then
            local fadeOutMultiplier = timeUntilEnd / fadeOutDuration
            fadeMultiplier = math.min(fadeMultiplier, fadeOutMultiplier)
          end
        end
        
        local amplitude = (halfCycleCount % 2 == 0) and -1 or 1
        if params.invertVibratoDirection then
          amplitude = -amplitude
        end
        local pitchOffset = params.vibratoDepth * amplitude * fadeMultiplier / 100.0
        local vibratoPoint = SV:create("PitchControlPoint")
        vibratoPoint:setPosition(currentPosition)
        vibratoPoint:setPitch(basePitch + pitchOffset)
        vibratoPoint:setScriptData(PITCH_CONTROL_KEYS.manualModeFlag, true)
        group:addPitchControl(vibratoPoint)
      end
      currentPosition = currentPosition + periodBlicks / 2
      halfCycleCount = halfCycleCount + 1
    end
  end
end

function applyManualModeToPitchCurves(note, groupRef, isReset)
  local group = groupRef:getTarget()
  -- Set expression to Rigid (-1, -1)
  note:setAttributes({
    expValueX = isReset and 0 or -1,
    expValueY = isReset and 0 or -1
  })
  local modificationRangeStart = note:getOnset() - SV.QUARTER / 4
  local modificationRangeEnd = note:getEnd()
  local previousNote = findPreviousNote(note, group)
  if previousNote then
    if previousNote:getEnd() == note:getOnset() then
      modificationRangeStart = previousNote:getOnset()
    else
      modificationRangeStart = math.max(modificationRangeStart, previousNote:getEnd())
    end
  end
  -- Clip the range end to the next note's transition point
  local nextNote = findNextNote(note, group)
  if nextNote then
    local nextNoteParams = loadNoteParameters(nextNote)
    local nextNoteTransitionBlicks = (nextNoteParams.pitchTransitionOffset - nextNoteParams.pitchTransitionWidth) * SV.QUARTER
    local nextNoteTransitionPoint = nextNote:getOnset() + nextNoteTransitionBlicks
    modificationRangeEnd = math.min(modificationRangeEnd, nextNoteTransitionPoint - 1)
  end
  
  clearPitchControlsInRange(group, modificationRangeStart, modificationRangeEnd)
  if isReset then
    return
  end
  addPitchControlsToNote(note, groupRef, modificationRangeStart, modificationRangeEnd, true)
  if previousNote and previousNote:getEnd() == note:getOnset() then
    local prevNoteParams = loadNoteParameters(previousNote)
    local params = loadNoteParameters(note)
    local noteTransitionBlicks = (params.pitchTransitionOffset - params.pitchTransitionWidth) * SV.QUARTER
    local noteTransitionPoint = note:getOnset() + noteTransitionBlicks
    -- If the previous note is not in manual mode, do not create new points before the transition.
    if not prevNoteParams.enabled then
      modificationRangeStart = math.min(note:getOnset(), noteTransitionPoint)
    end
    modificationRangeEnd = math.min(modificationRangeEnd, noteTransitionPoint - 1)
    addPitchControlsToNote(previousNote, groupRef, modificationRangeStart, modificationRangeEnd, false)
  end
end

function applyToSelectedNotes(isReset)
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = selection:getSelectedNotes()
  
  if #selectedNotes == 0 then
    statusTextValue:setValue(SV:T("No notes selected"))
    return
  end
  
  local currentGroup = editor:getCurrentGroup()
  local newParamsToSet = loadNoteParametersFromWidgetValues()
  SV:getProject():newUndoRecord()
  
  -- First update the note parameters
  for i = 1, #selectedNotes do
    local note = selectedNotes[i]
    if isReset then
      resetNoteParameters(note)
    else
      saveNoteParameters(note, newParamsToSet)
    end
  end
  -- Then actually generate the pitch controls
  for i = 1, #selectedNotes do
    local note = selectedNotes[i]
    applyManualModeToPitchCurves(note, currentGroup, isReset)
  end
  
  -- Restore selection (removePitchControl clears it)
  for i = 1, #selectedNotes do
    selection:selectNote(selectedNotes[i])
  end
  
  -- Update status
  statusTextValue:setValue(SV:T("Applied to") .. " " .. #selectedNotes .. " " .. SV:T("note(s)"))
end

function onSelectionChanged()
  local selection = SV:getMainEditor():getSelection()
  local selectedNotes = selection:getSelectedNotes()
  
  if #selectedNotes > 0 then
    -- Load parameters from the first selected note
    local params = loadNoteParameters(selectedNotes[1])
    updateWidgetValues(params)
    
    -- Check manual mode status for all selected notes
    local enabledCount = 0
    local mixedStatus = false
    local firstNoteEnabled = isManualModeEnabled(selectedNotes[1])
    
    for i = 1, #selectedNotes do
      if isManualModeEnabled(selectedNotes[i]) then
        enabledCount = enabledCount + 1
      end
      if i > 1 and isManualModeEnabled(selectedNotes[i]) ~= firstNoteEnabled then
        mixedStatus = true
      end
    end
    
    -- Build status message
    local statusMsg = #selectedNotes .. " " .. SV:T("note(s)") .. SV:T(" selected") .. "\n"
    if mixedStatus then
      statusMsg = statusMsg .. SV:T("Manual Mode") .. ": " .. enabledCount .. "/" .. #selectedNotes .. " " .. SV:T("enabled (mixed)")
    elseif enabledCount == #selectedNotes then
      statusMsg = statusMsg .. SV:T("Manual Mode") .. ": " .. SV:T("enabled")
    else
      statusMsg = statusMsg .. SV:T("Manual Mode") .. ": " .. SV:T("disabled")
    end
    
    statusTextValue:setValue(statusMsg)
  else
    statusTextValue:setValue(SV:T("No notes selected"))
  end
  for key, control in pairs(controls) do
    control.value:setEnabled(#selectedNotes > 0)
  end
  resetButtonValue:setEnabled(#selectedNotes > 0)
  applyButtonValue:setEnabled(#selectedNotes > 0)
end

-- Register selection callback to load parameters when selection changes
SV:getMainEditor():getSelection():registerSelectionCallback(function(selectionType, isSelected)
  if selectionType == "note" then
    onSelectionChanged()
  end
end)

SV:getMainEditor():getSelection():registerClearCallback(function(selectionType)
  if selectionType == "notes" then
    onSelectionChanged()
  end
end)

for key, control in pairs(controls) do
  control.value:setValueChangeCallback(function()
    applyToSelectedNotes()
  end)
end

resetButtonValue:setValueChangeCallback(function()
  applyToSelectedNotes(true)
end)

applyButtonValue:setValueChangeCallback(function()
  applyToSelectedNotes(false)
end)

function getSidePanelSectionState()
  local section = {
    title = SV:T(SCRIPT_TITLE),
    rows = {
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Transition Offset"),
            format = "%1.2f " .. SV:T("beats"),
            minValue = -0.25,
            maxValue = 0.25,
            interval = 0.01,
            value = controls.pitchTransitionOffset.value,
            width = 0.5
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Transition Width"),
            format = "%1.2f " .. SV:T("beats"),
            minValue = 0.01,
            maxValue = 0.15,
            interval = 0.01,
            value = controls.pitchTransitionWidth.value,
            width = 0.5
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Vibrato Start Position"),
            format = "%2.0f %%", 
            minValue = 0,
            maxValue = 100,
            interval = 5,
            value = controls.vibratoStartTime.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Vibrato Frequency"),
            format = "%1.1f Hz",
            minValue = 3.0,
            maxValue = 8.0,
            interval = 0.1,
            value = controls.vibratoFrequency.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Vibrato Depth"),
            format = "%3.0f " .. SV:T("cents"),
            minValue = 0,
            maxValue = 300,
            interval = 5,
            value = controls.vibratoDepth.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Vibrato Fade-In"),
            format = "%2.0f %%",
            minValue = 0,
            maxValue = 100,
            interval = 5,
            value = controls.vibratoFadeIn.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Slider",
            text = SV:T("Vibrato Fade-Out"),
            format = "%2.0f %%",
            minValue = 0,
            maxValue = 100,
            interval = 5,
            value = controls.vibratoFadeOut.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "CheckBox",
            text = SV:T("Invert Vibrato Direction"),
            value = controls.invertVibratoDirection.value,
            width = 1.0
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Button",
            text = SV:T("Reset"),
            width = 1.0,
            value = resetButtonValue
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "Button",
            text = SV:T("Apply"),
            width = 1.0,
            value = applyButtonValue
          }
        }
      },
      {
        type = "Container",
        columns = {
          {
            type = "TextArea",
            value = statusTextValue,
            height = 60,
            width = 1.0,
            readOnly = true
          }
        }
      }
    }
  }
  
  return section
end