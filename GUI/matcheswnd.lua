--- @type Mq
local mq = require('mq')
require 'ImGui'
local cm = require('TSC.configmanager')
local sm = require('TSC.statemanager')
local im = require('TSC.itemmanager')
local utils = require('TSC.utils')

local matchesWindow = {
    openMatch = false,
    drawMatch = false,
}

--------Draw matches window--------
function matchesWindow.draw()
    if matchesWindow.openMatch then
        matchesWindow.openMatch, matchesWindow.drawMatch = ImGui.Begin('Confirm trades and moves', matchesWindow.openMatch)
        ImGui.SetWindowSize(600, 850, ImGuiCond.Once)
        if matchesWindow.drawMatch then
            ImGui.TextColored(1, 1, 0, 1, 'Review items to be traded and moved')
            ImGui.TextWrapped('Review each item and then click continue to begin.')

            ImGui.PushStyleColor(ImGuiCol.Button, 0, 1, 0, .5)
            if ImGui.Button('Continue') then sm.skipTrading = false sm.tradeConfirmWnd = false end
            ImGui.PopStyleColor()

            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
            if ImGui.Button('Cancel') then sm.skipTrading = true sm.tradeConfirmWnd = false end
            ImGui.PopStyleColor()

            -- Iterate over combinedItems
            local flags = ImGuiTableFlags.RowBg
            for toon, items in pairs(im.combinedItems) do
                ImGui.TextColored(1, 0, 0, 1, utils.fname(toon))

                -- Trades Table
                ImGui.PushStyleColor(ImGuiCol.TableHeaderBg, 0.6, 0.3, 0.3, 1.0) -- Set header background color
                if ImGui.BeginTable('Trades##' .. toon, 5, flags) then
                    ImGui.TableSetupColumn('Trades', ImGuiTableColumnFlags.WidthStretch)
                    ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 70)
                    ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 80)
                    ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 80)
                    ImGui.TableSetupColumn('Reverse', ImGuiTableColumnFlags.WidthFixed, 85)
                    ImGui.TableHeadersRow()
                    ImGui.PopStyleColor() -- Restore header color

                    for itemName, itemData in pairs(items) do
                        if itemData.destination and itemData.destination:match('^[A-Z]') and not itemData.destination:find(',') then
                            ImGui.TableNextRow()
                            ImGui.TableNextColumn()
                            if itemData.destination:find('skipped') then
                                ImGui.TextDisabled(itemName .. ' will be skipped this round')
                            elseif itemData.destination:find('ignored') then
                                ImGui.TextDisabled(itemName .. ' is now on the global ignore list')
                            elseif itemData.destination:find('pgnored') then
                                ImGui.TextDisabled(itemName .. ' is now ignored only for ' .. utils.fname(toon))
                            else
                                ImGui.Text(itemName .. ' will go to ' .. utils.fname(itemData.destination))
                            end

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, .16, .29, .48, 1)
                            if ImGui.Button('\xef\x81\x9e Skip##' .. toon .. itemName) then
                                itemData.destination = itemData.destination .. ' skipped'
                            end
                            ImGui.PopStyleColor()

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, .4, .4, 0, 1)
                            if ImGui.Button('\xef\x82\xac Ignore##' .. toon .. itemName) then
                                cm:addIgnoreItem(itemName)
                                itemData.destination = itemData.destination .. ' ignored'
                                for toon2, items2 in pairs(im.combinedItems) do
                                    if toon2 ~= toon then
                                        if items2[itemName] then
                                            items2[itemName].destination = items2[itemName].destination .. ' ignored'
                                        end
                                    end
                                end
                            end
                            ImGui.PopStyleColor()

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, 0, .4, .4, 1)
                            if ImGui.Button('\xef\x80\x87 Ignore##' .. toon .. itemName) then
                                cm:addPersonalIgnoreItem(toon, itemName)
                                itemData.destination = itemData.destination .. ' pgnored'
                            end
                            ImGui.PopStyleColor()

                            ImGui.TableNextColumn()
                            if sm.routine == 'consolidate' then
                                ImGui.PushStyleColor(ImGuiCol.Button, 0, .4, .4, 1)
                                if ImGui.Button('\xee\xa3\x94 Reverse##' .. toon .. itemName) then
                                    im:reverseTradeDirection(itemName, toon)
                                end
                                ImGui.PopStyleColor()
                            end
                        end
                    end
                    ImGui.EndTable()
                end

                -- Moves Table
                ImGui.PushStyleColor(ImGuiCol.TableHeaderBg, 0.3, 0.6, 0.3, 1.0) -- Set header background color
                if ImGui.BeginTable('Moves##' .. toon, 5, flags) then
                    ImGui.TableSetupColumn('Moves', ImGuiTableColumnFlags.WidthStretch)
                    ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 70)
                    ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 80)
                    ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 80)
                    ImGui.TableSetupColumn('', ImGuiTableColumnFlags.WidthFixed, 85)
                    ImGui.TableHeadersRow()
                    ImGui.PopStyleColor() -- Restore header color

                    for itemName, itemData in pairs(items) do
                        if itemData.destination and itemData.destination ~= "leftovers" and (itemData.destination:match('^%l') or itemData.destination:find(',')) then
                            ImGui.TableNextRow()
                            ImGui.TableNextColumn()
                            if itemData.destination == 'bankrestack' then
                                ImGui.Text(itemName .. ' must be restacked in the bank')
                            elseif itemData.destination:find('skipped') then
                                ImGui.TextDisabled(itemName .. ' will be skipped this round')
                            elseif itemData.destination:find('ignored') then
                                ImGui.TextDisabled(itemName .. ' is now on the global ignore list')
                            elseif itemData.destination:find('pgnored') then
                                ImGui.TextDisabled(itemName .. ' is now ignored only for ' .. utils.fname(toon))
                            else
                                ImGui.Text(itemName .. ' will go to ' .. itemData.destination)
                            end

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, .16, .29, .48, 1)
                            if ImGui.Button('\xef\x81\x9e Skip##' .. toon .. itemName) then
                                itemData.destination = itemData.destination..' skipped'
                            end
                            ImGui.PopStyleColor()

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, .4, .4, 0, 1)
                            if ImGui.Button('\xef\x82\xac Ignore##' .. toon .. itemName) then
                                cm:addIgnoreItem(itemName)
                                itemData.destination = 'ignored'
                                for toon2, items2 in pairs(im.combinedItems) do
                                    if toon2 ~= toon then
                                        if items2[itemName] then
                                            items2[itemName].destination = items2[itemName].destination .. ' ignored'
                                        end
                                    end
                                end
                            end
                            ImGui.PopStyleColor()

                            ImGui.TableNextColumn()
                            ImGui.PushStyleColor(ImGuiCol.Button, 0, .4, .4, 1)
                            if ImGui.Button('\xef\x80\x87 Ignore##' .. toon .. itemName) then
                                cm:addPersonalIgnoreItem(toon, itemName)
                                itemData.destination = itemData.destination .. ' pgnored'
                            end
                            ImGui.PopStyleColor()
                        end
                    end
                    ImGui.EndTable()
                end

                ImGui.Separator()
                ImGui.Text(" ")
            end
        end
        ImGui.End()
    end
end

return matchesWindow