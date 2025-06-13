--- @type Mq
local mq = require('mq')
require 'ImGui'
local search = require('TSC.search')
local utils = require('TSC.utils')
local tip = require('TSC.tooltips')
local sm = require('TSC.statemanager')
local tm = require('TSC.toonmanager')

local searchWindow = {
    openSearch = false,
    drawSearch = false,
}

--------Draw search window--------
local search_term = ''
function searchWindow.draw()
    if searchWindow.openSearch then
        searchWindow.openSearch, searchWindow.drawSearch = ImGui.Begin('Searching all items', searchWindow.openSearch)
        ImGui.SetWindowSize(500,700,ImGuiCond.Once)
        if searchWindow.drawSearch then
            ImGui.PushStyleColor(ImGuiCol.Button, 1, 1, 0, .5)
            if ImGui.Button('Re-scan') then sm.routine = 'search' sm.start = true end
            ImGui.PopStyleColor()
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.rescan) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            ImGui.SameLine()

            
            search_term = ImGui.InputText('\xee\xa2\xb6', search_term)
            ImGui.SameLine()
            if ImGui.Button("Clear") then search_term = "" end

            ImGui.TextWrapped('These are all items owned by your toons in this zone. From here you can instruct toons to give items to others.')

            local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY
            local x, y = ImGui.GetContentRegionAvail()
            if ImGui.BeginTable('SearchTable', 3, tableFlags, x, y) then
                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.WidthStretch, 0, 1)
                local col2flag = ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.WidthFixed
                local col3flag = ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.WidthFixed
                ImGui.TableSetupColumn('Qty', col2flag, 40, 2)
                ImGui.TableSetupColumn('Give', col3flag, 60, 2)
                ImGui.TableSetupScrollFreeze(0, 1)

                local sort_specs = ImGui.TableGetSortSpecs()
                if sort_specs then
                    if sort_specs.SpecsDirty then
                        current_sort_specs = sort_specs
                        table.sort(search.results, utils.sortSearch)
                        current_sort_specs = nil
                        sort_specs.SpecsDirty = false
                    end
                end
                ImGui.TableHeadersRow()

                for k,v in ipairs(search.results) do
                    if (#search_term > 1 and string.find(v.item:lower(), search_term:lower())) or #search_term < 2 then
                    ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                            ImGui.TextColored(1,1,0,1, v.item)
                        ImGui.TableNextColumn()
                        ImGui.Text('')
                        ImGui.TableNextColumn()
                        ImGui.Text('')
                    ImGui.TableNextRow()
                        for l,details in pairs(v) do
                            if l ~= 'item' then
                                ImGui.TableNextColumn()
                                ImGui.Indent(15)
                                ImGui.Text(utils.fname(l))
                                ImGui.Unindent(15)
                                ImGui.TableNextColumn()
                                    ImGui.Text(details.total)
                                ImGui.TableNextColumn()
                                    if ImGui.Button('Select...##'..l..v.item, 60,20) then ImGui.OpenPopup('give##'..l..v.item) end
                                    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.deliver) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
                                    
                                    --Deliver pop-up
                                    if ImGui.BeginPopup('give##'..l..v.item) then
                                        ImGui.TextColored(1,1,0,1,'Give '..v.item..' to another?')
                                        ImGui.Text('Who should '..utils.fname(l)..' give to?')
                                        if ImGui.BeginCombo('##DeliverCombo'..l..v.item, utils.fname(sm.giveTarget)) then
                                            local availableToons = utils.getAlphabetizedList(tm.onlineToons)
                                            for _,peer in pairs(availableToons) do
                                                if l ~= peer then
                                                    if ImGui.Selectable(utils.fname(peer), sm.giveTarget == peer) then
                                                        sm.giveTarget = peer
                                                    end
                                                end
                                            end
                                            ImGui.EndCombo()
                                        end
                                        ImGui.Text('How many?')
                                        --sm.deliverQty = ImGui.SliderInt("Quantity##"..l..v.item, sm.deliverQty, 1, details.total)
                                        sm.deliverQty = ImGui.DragInt("Drag or double-click##"..l..v.item, sm.deliverQty, 1, 1, details.total)
                                        if ImGui.Button('Start##'..l..v.item) then
                                            if sm.giveTarget ~= '' then
                                                if sm.giveTarget == l then
                                                    print('\at[TsC]\ao You can\'t give your yourself!')
                                                else
                                                    sm.activeToon = l
                                                    sm.deliverItem = v.item
                                                    sm.routine = 'deliver'
                                                    sm.start = true
                                                end
                                            end
                                        end
                                        ImGui.EndPopup()
                                    end

                            end
                        end
                    end
                end
            ImGui.EndTable()
            end
        end
        ImGui.End()
    end
end

return searchWindow