--- @type Mq
local mq = require('mq')
require 'ImGui'
local tip = require('TSC.tooltips')
local cm = require('TSC.configmanager')
local utils = require('TSC.utils')
local PackageMan = require('mq/PackageMan')
PackageMan.Require('luafilesystem', 'lfs')
local filedialog = require('TSC.GUI.imguifiledialog')

local listWindow = {
    openList= false,
    drawList = false,
    whosList = '',
    whatList = '',
    bulkList = 'Gnomish Apples\nDwarven Peaches\nElven Carrots\n...'
}

function listWindow.draw()
    local mytable
    if listWindow.openList then
        local windowTitle
        if listWindow.whosList == '' then
            windowTitle = '\xef\x82\xac Global Ignore List'
            mytable = cm.ignore
        elseif listWindow.whatList == 'hoard' then
            windowTitle = '\xef\x82\x91 '..listWindow.whosList..'\'s Hoard List'
            mytable = cm.hoard[listWindow.whosList]
        else
            windowTitle = '\xef\x81\x9e '..listWindow.whosList .. '\'s Personal Ignore List'
            mytable = cm.pignore[listWindow.whosList]
        end

        listWindow.openList, listWindow.drawList = ImGui.Begin(windowTitle, listWindow.openList)
        ImGui.SetWindowSize(300, 450, ImGuiCond.Once)
        if listWindow.drawList then
            if ImGui.Button('Add item') then
                if mq.TLO.Cursor() then
                    local itemName = mq.TLO.Cursor.Name()
                    if listWindow.whosList == '' then
                        cm:addIgnoreItem(itemName)
                    elseif listWindow.whatList == 'hoard' then
                        cm:addhoardItem(listWindow.whosList, itemName)
                    else
                        cm:addPersonalIgnoreItem(listWindow.whosList, itemName)
                    end
                else
                    print('\at[TsC]\ao Please put an item on your cursor.')
                end
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(300)
                ImGui.TextWrapped(tip.addignoreitem)
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end
            ImGui.SameLine()

            if ImGui.Button('Bulk add...') then ImGui.OpenPopup('Bulk add') end
            if ImGui.IsItemHovered() then ImGui.SetTooltip('Paste a list of items.') end

            if ImGui.BeginPopup('Bulk add') then
                ImGui.TextWrapped('Paste your list here. Each item should be on its own line. No commas or quotes. Exact spelling and capitalization matter.')
                listWindow.bulkList = ImGui.InputTextMultiline('##bulkaddignore', listWindow.bulkList, 300, 400, 0)
                if ImGui.Button('Add to list') then
                    if listWindow.whosList == '' then
                        listWindow.bulkAdd('ignore')
                    elseif listWindow.whatList == 'hoard' then
                        listWindow.bulkAdd('hoard', listWindow.whosList)
                    else
                        listWindow.bulkAdd('personal', listWindow.whosList)
                    end
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()

                ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
                if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                ImGui.PopStyleColor()
                ImGui.EndPopup()
            end
            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button, 1, 1, 0, .5)
            ImGui.BeginGroup()
            if ImGui.Button('Add from file...') then filedialog.set_file_selector_open(true) end
            if filedialog.is_file_selector_open() then
                filedialog.draw_file_selector(mq.configDir .. '/TSC', '.txt')
            end
            if not filedialog.is_file_selector_open() and filedialog.get_filename() ~= '' then
                if listWindow.whosList == '' then
                    listWindow.importFile('ignore')
                elseif listWindow.whatList == 'hoard' then
                    listWindow.importFile('hoard', listWindow.whosList)
                else
                    listWindow.importFile('personal', listWindow.whosList)
                end
                filedialog.reset_filename()
            end
            ImGui.SameLine()
            ImGui.Text('\xee\xa2\x8f')
            ImGui.EndGroup()
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(300)
                ImGui.TextWrapped(tip.importignore)
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end
            ImGui.PopStyleColor()

            if listWindow.whosList == '' then
                ImGui.TextWrapped('TSC ignores no-drop, lore, and non-stackable items by default.')
            elseif listWindow.whatList == 'hoard' then
                ImGui.TextWrapped('Items you want ' .. listWindow.whosList .. ' to keep, always receive, and never give away.')
            else
                ImGui.TextWrapped('Items you want ' .. listWindow.whosList .. ' to ignore IN ADDITION to the global ignore list.')
            end

            local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY
            local x, y = ImGui.GetContentRegionAvail()
            if ImGui.BeginTable('IgnoreTable', 1, tableFlags, x, y) then
                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort, 0, 1)
                ImGui.TableSetupScrollFreeze(0, 1)

                current_sort_specs = ImGui.TableGetSortSpecs()
                ImGui.TableHeadersRow()

                -- Render the table rows using sorted keys
                local sortedKeys = utils.getSortedKeys(mytable)
                for _, key in ipairs(sortedKeys) do
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    ImGui.Text('\xef\x80\x94')
                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove item') end
                    if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                        if listWindow.whosList == '' then
                            cm:removeIgnoreItem(key)
                        elseif listWindow.whatList == 'hoard' then
                            cm:removehoardItem(listWindow.whosList, key)
                        else
                            cm:removePersonalIgnoreItem(listWindow.whosList, key)
                        end
                        mytable[key] = nil
                    end
                    ImGui.SameLine()
                    ImGui.Text(key)
                end
                ImGui.EndTable()
            end
        end
        ImGui.End()
    else
        listWindow.whosList = ''
        listWindow.whatList = ''
    end
end

--Bulk add ingore/artisan items via copy pasted list
function listWindow.bulkAdd(listType, toon)
    for line in listWindow.bulkList:gmatch("[^\n]+") do
        if listType == 'ignore' then
            cm:addIgnoreItem(line)
        elseif listType == 'hoard' then
            cm:addhoardItem(toon, line)
        elseif listType == 'personal' then
            cm:addPersonalIgnoreItem(toon, line)
        end
    end
    listWindow.bulkList = ''
end

--Import ignore/hoard items from file
function listWindow.importFile(listType, toon)
    local file
    file = io.open(mq.configDir..'/TSC/'..filedialog.get_filename())
    if not file then
        print('\at[TsC]\ao Error opening file.')
        return
    end
    local lines = file:lines()
    for line in lines do
        if listType == 'ignore' then
            cm:addIgnoreItem(line)
        elseif listType == 'hoard' then
            cm:addhoardItem(toon, line)
        elseif listType == 'personal' then
            cm:addPersonalIgnoreItem(toon, line)
        end
    end
end

return listWindow