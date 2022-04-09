function getClientInfo()
    return {
        name = "Copy Notes and Parameters",
        category = "Editing",
        author = "RigoLigo",
        versionNumber = 1
    }
end

function main()
    if checkHasSelection() then
        useSelectionBounds:exec()
    else
        SV:showMessageBox("No selection", "You must select the notes to be copied.")
    end
end

function dbgInfo(v)
    local x = "String form: <<" .. tostring(v) .. ">>\n"..
              "Type: <<" .. type(v) .. ">>"
    SV:showMessageBox("Debug", x);
end

function checkHasSelection()
    return SV:getMainEditor():getSelection():hasSelectedContent()
end

function getPlayheadTimeBlick()
    return SV:getProject():getTimeAxis():getBlickFromSeconds(SV:getPlayback():getPlayhead())
end

function safeOp2(a, b, op)
    if a == nil then
        if b == nil then
            return 0
        else
            return b
        end
    elseif b == nil then
        return a
    else
        return op(a, b)
    end
end

useSelectionBounds = {
    exec = function()
        local sel = SV:getMainEditor():getSelection()
        selNotes = sel:getSelectedNotes()
        selGroups = sel:getSelectedGroups()
        
        -- Get begin and end time of the section safely
        local beginTime1 = (#selNotes ~= 0) and selNotes[1]:getOnset() or nil
        local beginTime2 = (#selGroups ~= 0)and selGroups[1]:getOnset()or nil
        beginTime = safeOp2(beginTime1, beginTime2, math.min)
        
        local endTime1 = (#selNotes ~= 0) and selNotes[#selNotes]:getEnd() or nil
        local endTime2 = (#selGroups ~= 0)and selGroups[#selGroups]:getEnd()or nil
        endTime = safeOp2(endTime1, endTime2, math.max)
        
        -- Store the group UUID
        fromGroup = SV:getMainEditor():getCurrentGroup():getTarget()
        groupId = fromGroup:getUUID()
        
        useSelectionBounds:beginWaitCopy()
    end,
    
    beginWaitCopy = function()
        local firstWaitForm = {
            title = "Begin copying",
            message = "Script will now wait for you to move your playhead and track selection to the desired destination.\n"..
                      "Select a timeout, and click OK to continue. Click Cancel to abort.\n\n"..
                      "Note: Timeout of 0 will activte copying immediately.",
            buttons = "OkCancel",
            widgets = {
                {
                    name = "timeout", type = "Slider", label = "Timeout",
                    format = "%.1f secs", minValue = 0, maxValue = 40, interval = 0.5, default = 10
                }
            }
        }
        
        local result = SV:showCustomDialog(firstWaitForm)
        if result.status == true then
            if result.answers.timeout == 0 then
                useSelectionBounds:doCopy()
            else
                SV:setTimeout(result.answers.timeout * 1000, useSelectionBounds.confirmCopy)
            end
        else
            SV:finish()
        end
    end,
    
    confirmCopy = function()
        local confirmForm = {
            title = "Confirm copying",
            message = "Are you now ready for copying? Click Yes to confirm copying.\n\n"..
                      "Otherwise, select a timeout, and click No to continue waiting.\n"..
                      "Click Cancel to abort.",
            buttons = "YesNoCancel",
            widgets = {
                {
                    name = "timeout", type = "Slider", label = "Timeout",
                    format = "%.1f secs", minValue = 3, maxValue = 40, interval = 0.5, default = 10
                }
            }
        }
        
        local result = SV:showCustomDialog(confirmForm)
        if result.status == "No" then
            SV:setTimeout(result.answers.timeout * 1000, useSelectionBounds.confirmCopy)
        elseif result.status == "Yes" then
            useSelectionBounds:doCopy();
        else
            SV:finish()
        end
    end,
    
    doCopy = function()
        local group = SV:getProject():getNoteGroup(groupId)
--         dbgInfo(group)
--         if group == nil then
--             SV:showMessageBox("Error", "Note group to copy from has been destroyed!")
--             return
--         end

        toGroup = SV:getMainEditor():getCurrentGroup():getTarget()
        destTime = getPlayheadTimeBlick()
        -- Remember to minus the current group onset
        timeOffset = destTime - beginTime - SV:getMainEditor():getCurrentGroup():getOnset()
        
        useSelectionBounds:copyNotes()
        useSelectionBounds:copyGroups()
        
        useSelectionBounds:copyParams()
        
        SV:finish()
    end,
    
    copyNotes = function()
        for _, i in pairs(selNotes) do
            local n = i:clone()
            n:setOnset(n:getOnset() + timeOffset)
            toGroup:addNote(n)
        end
    end, 
    
    copyGroups = function()
    -- FIXME BUG  Synthesizer V doens't provide an NoteGroupReference:setOnset API which is crucial for the operation
    
--         local toGroup = SV:getMainEditor():getCurrentGroup():getTarget()
--         
--         -- Don't copy a group into a group, SynthV editor doesn't support this
--         if #toGroup ~= 0 and not toGroup:isMain() then
--             return
--         end
--         
--         local toTrack = SV:getMainEditor():getCurrentTrack()
--         local timeOffset = getPlayheadTimeBlick() - beginTime
--         for k, v in pairs(selGroups) do
--             local n = v:clone()
--             n:setOnset(n:getOnset() + timeOffset)
--             toTrack:add(n)
--         end
    end,
    
    copyParams = function()
        params = {
            pitchDelta = 0, 
            vibratoEnv = 1, 
            loudness = 0, 
            tension = 0, 
            breathiness = 0, 
            voicing = 1, 
            gender = 0
        }
        for i, def in pairs(params) do
            local p = fromGroup:getParameter(i)
            local pts = p:getPoints(beginTime, endTime) -- Get points in range
            
            -- If no points found?
            if #pts == 0 then
                -- Check value right at the head and tail. If they are not default, then add exact points.
                if p:get(beginTime) ~= def then pts[1] = {beginTime, p:get(beginTime)} end
                if p:get(endTime) ~= def then pts[2] = {beginTime, p:get(endTime)} end
            end
            
            -- If still no points? Meaning the value stayed default, skip this parameter.
            if #pts == 0 then goto NextParam end
            
            -- Make the point at beginning and ending the exact values
            pts[1][2] = p:get(pts[1][1])
            pts[#pts][2] = p:get(pts[#pts][1])
            
            -- Clear the destination area, extends 100 blinks for safety
            local q = toGroup:getParameter(i)
            q:remove(destTime - 100, destTime + (endTime - beginTime) + 100)
            -- Add each one into destination
            for _, j in pairs(pts) do
                q:add(j[1] + timeOffset, j[2])
            end
            
            ::NextParam::
        end
    end
}
