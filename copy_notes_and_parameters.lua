function getClientInfo()
    return {
        name = SV:T("Copy Notes and Parameters"),
        author = "RigoLigo",
        versionNumber = 2
    }
end

function getTranslations(langCode)
    if langCode == "zh-cn" then
        return {
            {"Copy Notes and Parameters", "带参数复制音符"},
            {"No selection", "没有选择音符"},
            {"You must select the notes to be copied.", "必须先选中要复制的音符。"},
            {"Begin copying", "开始复制"},
            {"Confirm copying", "确认复制"},
            {"Timeout", "等待时间"},
            {" secs", " 秒"},
            {"Script will now wait for you to move your playhead and track selection to the desired destination.\\n"..
             "Select a timeout, and click OK to continue. Click Cancel to abort.\\n\\n"..
             "Note: Timeout of 0 will activte copying immediately.",
             "脚本会等你把播放头和选定的轨道移动到粘贴位置。\\n请选择等待时长，单击“确定”继续。单击“取消”中止。\\n\\n"..
             "注意：等待时间为0时，会立即触发复制操作。"},
            {"Are you now ready for copying? Click Yes to confirm copying.\\n\\n"..
             "Otherwise, select a timeout, and click No to continue waiting.\\n"..
             "Click Cancel to abort.",
             "准备好复制了吗？单击“是”开始复制。否则，可再选择一次等待时间，然后单击“否”继续等待。\\n单击“取消”中止。"}
        }
    end
end

function main()
    if checkHasSelection() then
        useSelectionBounds:exec()
    else
        SV:showMessageBox(SV:T("No selection"), SV:T("You must select the notes to be copied."))
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
            title = SV:T("Begin copying"),
            message = SV:T("Script will now wait for you to move your playhead and track selection to the desired destination.\n"..
                      "Select a timeout, and click OK to continue. Click Cancel to abort.\n\n"..
                      "Note: Timeout of 0 will activte copying immediately."),
            buttons = "OkCancel",
            widgets = {
                {
                    name = "timeout", type = "Slider", label = SV:T("Timeout"),
                    format = "%.1f" .. SV:T(" secs"), minValue = 0, maxValue = 40, interval = 0.5, default = 10
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
            title = SV:T("Confirm copying"),
            message = SV:T("Are you now ready for copying? Click Yes to confirm copying.\n\n"..
                      "Otherwise, select a timeout, and click No to continue waiting.\n"..
                      "Click Cancel to abort."),
            buttons = "YesNoCancel",
            widgets = {
                {
                    name = "timeout", type = "Slider", label = SV:T("Timeout"),
                    format = "%.1f" .. SV:T(" secs"), minValue = 3, maxValue = 40, interval = 0.5, default = 10
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
        toGroup = SV:getMainEditor():getCurrentGroup():getTarget()
        -- Snap to nearest
        destTime = SV:getMainEditor():getNavigation():snap(getPlayheadTimeBlick())
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
                -- Check value right at the head and tail and add exact points.
                pts[1] = {beginTime, p:get(beginTime)}
                pts[2] = {beginTime, p:get(endTime)}
            end
            
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
