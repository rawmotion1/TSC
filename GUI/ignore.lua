--- @type Mq
local mq = require('mq')
require 'ImGui'
local utils = require('TSC.utils')
local tip = require('TSC.tooltips')
local cm = require('TSC.configmanager')

local ignoreWindow = {
    openList= false,
    drawList = false,
    ignoreBulkList = 'Gnomish Apples\nDwarven Peaches\nElven Carrots\n...'
}

function ignoreWindow.draw()
    local mytable = cm.ignore
    if ignoreWindow.openList then
        local windowTitle = 'Global ignore List'

        ignoreWindow.openList, ignoreWindow.drawList = ImGui.Begin(windowTitle, ignoreWindow.openList)
        ImGui.SetWindowSize(300, 450, ImGuiCond.Once)
        if ignoreWindow.drawList then
            if ImGui.Button('Add item') then
                if mq.TLO.Cursor() then
                    local itemName = mq.TLO.Cursor.Name()
                    cm:addIgnoreItem(itemName)
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
                ignoreWindow.ignoreBulkList = ImGui.InputTextMultiline('##bulkaddignore', ignoreWindow.ignoreBulkList, 300, 400, 0)
                if ImGui.Button('Add to ignore list') then
                    ignoreWindow.bulkAdd()
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()

                ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
                if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                ImGui.PopStyleColor()
                ImGui.EndPopup()
            end

            ImGui.TextWrapped('TSC ignores no-drop, lore, and non-stackable items by default.')

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
                        cm:removeIgnoreItem(key)
                        mytable[key] = nil
                    end
                    ImGui.SameLine()
                    ImGui.Text(key)
                end
                ImGui.EndTable()
            end
        end
        ImGui.End()
    end
end

--Bulk add ingore/artisan items via copy pasted list
function ignoreWindow.bulkAdd()
    for line in ignoreWindow.ignoreBulkList:gmatch("[^\n]+") do
        cm:addIgnoreItem(line)
    end
    ignoreWindow.ignoreBulkList = ''
end

return ignoreWindow