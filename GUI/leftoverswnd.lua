--- @type Mq
local mq = require('mq')
require 'ImGui'
local sm = require('TSC.statemanager')
local cm = require('TSC.configmanager')
local im = require('TSC.itemmanager')
local utils = require('TSC.utils')

local leftoversWindow = {
    openLeft = false,
    drawLeft = false,
}

--------Draw leftovers window--------
function leftoversWindow.draw()
    if leftoversWindow.openLeft then
        leftoversWindow.openLeft, leftoversWindow.drawLeft = ImGui.Begin('Leftovers list', leftoversWindow.openLeft)
        ImGui.SetWindowSize(600,850,ImGuiCond.Once)
        if leftoversWindow.drawLeft then
            ImGui.TextColored(1,1,0,1,'Review leftover items to store.')
            ImGui.TextWrapped('These are leftover items still in your toons\' inventories that will be now stored away according to their Leftovers setting. Review each item and then click continue to store them.')

            ImGui.PushStyleColor(ImGuiCol.Button,0,1,0,.5)
                if ImGui.Button('Continue') then sm.skipLeftovers = false sm.leftoverConfirmWnd = false end
            ImGui.PopStyleColor()
            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button,1,0,0,.5)
                if ImGui.Button('Cancel') then sm.skipLeftovers = true sm.leftoverConfirmWnd = false end
            ImGui.PopStyleColor()

            --Start leftover tables
            local flags = ImGuiTableFlags.RowBg
            local row_bg_type = 1
            local row_bg_target = 1
            for toon, items in pairs(im.combinedItems) do
                if activeToon == "" or toon.name == activeToon then

                    local left = false
                    if cm.toons[toon].leftovers ~= 'Off' then
                        left = true
                    end
                                        
                    ImGui.TextColored(1,0,0,1, utils.fname(toon))
                    if ImGui.BeginTable('##'..toon, 4, flags) then
                        ImGui.TableSetupColumn('Action', ImGuiTableColumnFlags.WidthStretch)
                        ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 100)
                        ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableHeadersRow()
                        ImGui.TableSetBgColor(1, ImVec4(1, 1, 0, .4))
                        --if consol[toon.name] then

                            --Alphabetize
                            local sortedKeys = {}
                            for item,_ in pairs(items) do
                                table.insert(sortedKeys, item)
                            end
                            table.sort(sortedKeys)

                            for _,item in pairs(sortedKeys) do
                                if items[item].destination == "leftovers" or items[item].destination == "skipped" or items[item].destination == "ignored" or items[item].destination == "pignored" then

                                    local function update(arg)
                                        if items[item].destination ~= 'skipped' and items[item].destination ~= 'ignored' and items[item].destination ~= 'pignored'  then
                                            if arg == 'skip' then
                                                items[item].destination = 'skipped'
                                            elseif arg == 'ignore' then
                                                cm:addIgnoreItem(item)
                                                items[item].destination = 'ignored'
                                            elseif arg == 'pignore' then
                                                cm:addPersonalIgnoreItem(toon, item)
                                                items[item].destination = 'pignored'
                                            end
                                            im.lists.todump[toon][item] = nil --Remove from to dump list
                                            cm.saveData('lists', im.lists)
                                        end
                                    end

                                    ImGui.TableNextRow()
                                    ImGui.TableNextColumn()
                                    if row_bg_type == 1 then
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.8, 0.8, 0.3, 0.35))
                                    else
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.9, 0.9, 0.2, 0.35))
                                    end

                                    if items[item].destination == 'skipped' then
                                        ImGui.TextDisabled(item..'will be skipped once')
                                    elseif items[item].destination == 'ignored' then
                                        ImGui.TextDisabled(item..'is now globally ignored')
                                    elseif items[item].destination == 'pignored' then
                                        ImGui.TextDisabled(item..'is now personally ignored')
                                    elseif left == false then
                                        ImGui.TextDisabled(item..' will not be stored (Leftovers off)')
                                    else
                                        ImGui.Text(item..' will be stored')
                                    end

                                    ImGui.TableNextColumn()
                                    if ImGui.Button('\xef\x81\x9e Skip##'..toon..item) then
                                        update('skip')
                                    end
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Skip this item once.') end

                                    ImGui.TableNextColumn()
                                    ImGui.PushStyleColor(ImGuiCol.Button,1,1,0,.5)
                                    if ImGui.Button('\xef\x82\xac Ignore##'..toon..item) then
                                        update('ignore')
                                    end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to your global ingore file.') end

                                    ImGui.TableNextColumn()
                                    ImGui.PushStyleColor(ImGuiCol.Button, 0,1,1,.4)
                                    if ImGui.Button('\xef\x80\x87 Ignore##'..toon..item) then
                                        update('pignore')
                                    end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to this toon\'s personal ingore file.') end
                                end
                            end
                        --end
                    ImGui.EndTable()
                    ImGui.Separator()
                    ImGui.Text(" ")
                    end
                end
            end
        end
        ImGui.End()
    end
end

return leftoversWindow