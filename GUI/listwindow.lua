--- @type Mq
local mq = require('mq')
require 'ImGui'
local cm = require('TSC.configmanager')
local utils = require('TSC.utils')

local listWindow = {
    openList = false,
    bulkList = 'Gnomish Apples\nDwarven Peaches\nElven Carrots\n...'
}

function listWindow.draw()
    if listWindow.openList then
        listWindow.openList = ImGui.Begin('All Toons Lists', listWindow.openList, ImGuiWindowFlags.Resizable)
        ImGui.SetWindowSize(800, 600, ImGuiCond.Once)

        ImGui.PushStyleColor(ImGuiCol.Header, 0, 0.5, 0, .75) -- Set color for collapsible headers

        if ImGui.CollapsingHeader('Hoard Lists \xee\xa2\x8f') then
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped('Items you want this toon to keep, always receive, and never give away. An item can only be on one toon\'s hoard list at a time.') ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            local x, y = ImGui.GetContentRegionAvail()
            local gutterAdjustment = 8 -- Adjust for gutters and add a small buffer
            local sortedToons = utils.getAlphabetizedList(cm.toons) -- Sort toons alphabetically
            local tableWidth = (x - gutterAdjustment * (#sortedToons - 1)) / #sortedToons
            local maxHeight = y / 2 -- Limit height to prevent scroll bar

            ImGui.BeginChild('HoardLists', x, maxHeight, false)
            for _, toon in ipairs(sortedToons) do
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup() -- Group the toon name and table together
                ImGui.Text(utils.fname(toon)) -- Display the name of the toon above the table
                local hoardList = cm.hoard[toon] or {}
                local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY + ImGuiTableFlags.BordersOuter

                if ImGui.BeginTable(toon .. '_HoardTable', 1, tableFlags, tableWidth, maxHeight - 54) then
                    ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort, 0, 1)
                    ImGui.TableSetupScrollFreeze(0, 1)
                    current_sort_specs = ImGui.TableGetSortSpecs()
                    local sortedKeys = utils.getSortedKeys(hoardList)

                    ImGui.TableHeadersRow() -- Default header row without color

                    for _, key in ipairs(sortedKeys) do
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        ImGui.Text('\xef\x80\x94')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove item') end
                        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                            cm:removehoardItem(toon, key)
                            sortedKeys[key] = nil
                        end
                        ImGui.SameLine()
                        ImGui.Text(key)
                        if ImGui.BeginPopupContextItem('Item Context Menu##'..toon..key) then
                            for toon2, _ in pairs(cm.toons) do
                                if toon2 ~= toon then
                                    if ImGui.MenuItem('\xef\x81\xa1 Move to ' .. utils.fname(toon2) .. '##'..toon..key) then
                                        cm:addhoardItem(toon2, key)
                                    end
                                end
                            end
                            if ImGui.MenuItem('\xef\x81\x9e Move to personal ignore') then
                                cm:removehoardItem(toon, key)
                                cm:addPersonalIgnoreItem(toon, key)
                            end
                        ImGui.EndPopup()
                        end
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Right click to move') end
                    end
                    ImGui.EndTable()
                end

                ImGui.PushStyleColor(ImGuiCol.Button, 0, 0.5, 0, .75) -- Match button color to header
                if ImGui.Button('Text add##hoard' .. toon, tableWidth/2-5, 25) then
                    ImGui.OpenPopup('Bulk add##hoard'..toon)
                end
                ImGui.PopStyleColor() -- Reset button color
                if ImGui.BeginPopup('Bulk add##hoard'..toon) then
                    ImGui.TextColored(0, 0.5, 0, .75, utils.fname(toon)..'\'s Hoard List')
                    ImGui.TextWrapped('Each item should be on its own line. Exact spelling and capitalization matter.')
                    listWindow.bulkList = ImGui.InputTextMultiline('##bulkaddignore', listWindow.bulkList, 300, 400, 0)
                    if ImGui.Button('Add to list') then
                        listWindow.bulkAdd('hoard', toon)
                        ImGui.CloseCurrentPopup()
                    end
                    ImGui.SameLine()
    
                    ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
                    if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                    ImGui.PopStyleColor()
                    ImGui.EndPopup()
                end
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Button, 0, 0.5, 0, .75) -- Match button color to header
                if ImGui.Button('Cursor add##hoard' .. toon, tableWidth/2-4, 25) then
                    if mq.TLO.Cursor() then
                        local itemName = mq.TLO.Cursor.Name()
                            cm:addhoardItem(toon, itemName)
                    else
                        print('\at[TsC]\ao Please put an item on your cursor.')
                    end
                end
                ImGui.PopStyleColor() -- Reset button color
                ImGui.EndGroup()
                ImGui.SameLine() -- Keep the next group on the same line
            end
            ImGui.EndChild()
        end
        ImGui.PopStyleColor()

        ImGui.PushStyleColor(ImGuiCol.Header, 1, 1, 0, .5) -- Set color for collapsible headers

        if ImGui.CollapsingHeader('Personal Ignore Lists \xee\xa2\x8f') then
            if ImGui.IsItemHovered() then ImGui.SetTooltip('Items you want this toon to ignore IN ADDITION to the global ignore list.') end
            local x, y = ImGui.GetContentRegionAvail()
            local gutterAdjustment = 8 -- Adjust for gutters and add a small buffer
            local sortedToons = utils.getAlphabetizedList(cm.toons) -- Sort toons alphabetically
            local tableWidth = (x - gutterAdjustment * (#sortedToons - 1)) / #sortedToons
            local maxHeight = y -- Limit height to prevent scroll bar

            ImGui.BeginChild('IgnoreLists', x, maxHeight, false)
            for _, toon in ipairs(sortedToons) do
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup() -- Group the toon name and table together
                ImGui.Text(utils.fname(toon)) -- Display the name of the toon above the table
                local ignoreList = cm.pignore[toon] or {}
                local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY + ImGuiTableFlags.BordersOuter

                if ImGui.BeginTable(toon .. '_IgnoreTable', 1, tableFlags, tableWidth, maxHeight - 54) then
                    ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort, 0, 1)
                    ImGui.TableSetupScrollFreeze(0, 1)
                    current_sort_specs = ImGui.TableGetSortSpecs()
                    local sortedKeys = utils.getSortedKeys(ignoreList)

                    ImGui.TableHeadersRow() -- Default header row without color

                    for _, key in ipairs(sortedKeys) do
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        ImGui.Text('\xef\x80\x94')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove item') end
                        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                            cm:removePersonalIgnoreItem(toon, key)
                            sortedKeys[key] = nil
                        end
                        ImGui.SameLine()
                        ImGui.Text(key)
                        if ImGui.BeginPopupContextItem('Item Context Menu##'..toon..key) then
                            for toon2, _ in pairs(cm.toons) do
                                if toon2 ~= toon then
                                    if ImGui.MenuItem('\xef\x81\xa1 Move to ' .. utils.fname(toon2) .. '##'..toon..key) then
                                        cm:addPersonalIgnoreItem(toon2, key)
                                        cm:removePersonalIgnoreItem(toon, key)
                                    end
                                end
                            end
                            if ImGui.MenuItem('\xef\x82\x91 Move to hoard') then
                                cm:addhoardItem(toon, key)
                            end
                        ImGui.EndPopup()
                        end
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Right click to move') end
                    end
                    ImGui.EndTable()
                end

                ImGui.PushStyleColor(ImGuiCol.Button, 1, 1, 0, .5) -- Match button color to header
                if ImGui.Button('Text add##' .. toon, tableWidth/2-5, 25) then
                    ImGui.OpenPopup('Bulk add##pignore'..toon)
                end
                ImGui.PopStyleColor() -- Reset button color
                if ImGui.BeginPopup('Bulk add##pignore'..toon) then
                    ImGui.TextColored(1, 1, 0, .75, utils.fname(toon)..'\'s Personal Ignore List')
                    ImGui.TextWrapped('Each item should be on its own line. Exact spelling and capitalization matter.')
                    listWindow.bulkList = ImGui.InputTextMultiline('##bulkaddignore', listWindow.bulkList, 300, 400, 0)
                    if ImGui.Button('Add to list') then
                        listWindow.bulkAdd('personal', toon)
                        ImGui.CloseCurrentPopup()
                    end
                    ImGui.SameLine()
    
                    ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
                    if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                    ImGui.PopStyleColor()
                    ImGui.EndPopup()
                end
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Button, 1, 1, 0, .5) -- Match button color to header
                if ImGui.Button('Cursor add##' .. toon, tableWidth/2-4, 25) then
                    if mq.TLO.Cursor() then
                        local itemName = mq.TLO.Cursor.Name()
                            cm:addPersonalIgnoreItem(toon, itemName)
                    else
                        print('\at[TsC]\ao Please put an item on your cursor.')
                    end
                end
                ImGui.PopStyleColor() -- Reset button color
                ImGui.EndGroup()
                ImGui.SameLine() -- Keep the next group on the same line
            end
            ImGui.EndChild()
        end

        ImGui.PopStyleColor() -- Reset color styles

        ImGui.End()
    end
end

--Bulk add ingore/artisan items via copy pasted list
function listWindow.bulkAdd(listType, toon)
    for line in listWindow.bulkList:gmatch("[^\n]+") do
        if listType == 'hoard' then
            cm:addhoardItem(toon, line)
        elseif listType == 'personal' then
            cm:addPersonalIgnoreItem(toon, line)
        end
    end
    listWindow.bulkList = ''
end

return listWindow