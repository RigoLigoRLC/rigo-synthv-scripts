--[[
    Synthesizer V Studio Pro Script
    Fine tune BPM. MIT License.
    When making a cover of a song, you may encounter strange BPMs in the song.
    This script makes it easier to align the beats with the audio waveform by
    tuning a specific BPM marker very easy.

    Copyright 2022 RigoLigo

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to
    deal in the Software without restriction, including without limitation the
    rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    sell copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
]]

function getClientInfo()
    return {
        name = SV:T("Fine tune BPM"),
        author = "RigoLigo",
        versionNumber = 1
    }
end

function getTranslations(langCode)
    if langCode == "zh-cn" then
        return {
            {"Fine tune BPM", "微调BPM"},
            {"Please select a BPM marker you want to edit from the dropdown,\\n" ..
             "select the smallest stepping you want to edit in one shot,\\n" ..
             "and click Yes for smaller BPM, No for higher BPM, Cancel to stop the script.",
             "先选择一个想要编辑的BPM标记，\\n然后选择要一次加上或减去的大小。\\n"..
             "单击“是”减小BPM、“否”增加BPM，“取消”退出脚本。"},
            {"BPM Marker", "BPM标记"},
            {"#%d   %2g BPM, at %s", "#%d   %2g BPM，位于 %s"},
            {"Step", "步长"}
        }
    end
end

function getTimecodeForSeconds(sec)
    local _, secDecimal = math.modf(sec)
    return string.format("%d:%.2d.%.2d",
                         math.floor(sec / 60),
                         math.fmod(math.floor(sec), 60),
                         math.floor(secDecimal * 100))
end

lastSelectedMarker = 1
lastSelectedStep = 0.1

function BpmEditDialogProc()
    -- Generate text for the marker selector
    local fmtStr = SV:T("#%d   %2g BPM, at %s")

    if bpmMarkerTextList == nil then -- First time generation
        bpmMarkerTextList = {}
        for i, v in pairs(tempoMarkers) do
            bpmMarkerTextList[i] =
                string.format(fmtStr,
                              i,
                              v.bpm,
                              getTimecodeForSeconds(v.positionSeconds))
        end
    else -- Clicked once, update BPM marker list and text entries
        tempoMarkers[lastSelectedMarker] = timeAxis:getTempoMarkAt(tempoMarkers[lastSelectedMarker].position)
        bpmMarkerTextList[lastSelectedMarker] =
                string.format(fmtStr,
                              lastSelectedMarker,
                              tempoMarkers[lastSelectedMarker].bpm,
                              getTimecodeForSeconds(tempoMarkers[lastSelectedMarker].positionSeconds))
    end

    local firstWaitForm = {
        title = SV:T("Fine tune BPM"),
        message = SV:T("Please select a BPM marker you want to edit from the dropdown,\n" ..
                       "select the smallest stepping you want to edit in one shot,\n" ..
                       "and click Yes for smaller BPM, No for higher BPM, Cancel to stop the script."),
        buttons = "YesNoCancel",
        widgets = {
            {
                name = "markerSel", type = "ComboBox", label = SV:T("BPM Marker"),
                choices = bpmMarkerTextList, default = lastSelectedMarker - 1
            },
            {
                name = "stepping", type = "Slider", label = SV:T("Step"),
                format = "%.2f BPM", minValue = 0, maxValue = 5, interval = 0.01, default = lastSelectedStep
            }
        }
    }

    local result = SV:showCustomDialog(firstWaitForm)

    local i = result.answers.markerSel + 1
    local step = result.answers.stepping

    if result.status == "Yes" then
        timeAxis:removeTempoMark(tempoMarkers[i].position)
        timeAxis:addTempoMark(tempoMarkers[i].position, tempoMarkers[i].bpm - step)
    elseif result.status == "No" then
        timeAxis:removeTempoMark(tempoMarkers[i].position)
        timeAxis:addTempoMark(tempoMarkers[i].position, tempoMarkers[i].bpm + step)
    else
        SV:finish()
        return
    end

    lastSelectedMarker = i
    lastSelectedStep = step

    SV:setTimeout(0, BpmEditDialogProc)
end

function dbgInfo(v)
    local x = "String form: <<" .. tostring(v) .. ">>\n"..
              "Type: <<" .. type(v) .. ">>"
    SV:showMessageBox("Debug", x);
end

function main()
    timeAxis = SV:getProject():getTimeAxis()
    tempoMarkers = timeAxis:getAllTempoMarks()

    BpmEditDialogProc()
end
