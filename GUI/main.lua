--- @type Mq
local mq = require('mq')
require 'ImGui'
local utils = require('TSC.utils')
local tip = require('TSC.tooltips')
local cm = require('TSC.configmanager')
local tm = require('TSC.toonmanager')
local sm = require('TSC.statemanager')
local listWindow = require('TSC.GUI.listWindow')
local ignorewnd = require('TSC.GUI.ignore')
local matchesWindow = require('TSC.GUI.matcheswnd')
local leftoversWindow = require('TSC.GUI.leftoverswnd')
local searchWindow = require('TSC.GUI.searchwnd')

local main = {
    openGui = true,
    drawGui = true,
    status = 'Idle',
    disabled = false,
}

local me = mq.TLO.Me.Name()

--For adding new toons
local newToon = ''
local newMule = ''

---Drop down options
local modeOptions = {'Default', 'Generous', 'Greedy'}
local restOptions = {'Off', 'Depot > Bank > Mules', 'Depot > Bank', 'Depot > Mules', 'Bank > Mules', 'Bank', 'Mules'}

--Anonymizer function to hide toon names in the GUI


--Initialize the GUI
function main.initGui()
    if main.openGui then
        ImGui.SetNextWindowBgAlpha(1)
        main.openGui, main.drawGui = ImGui.Begin('TS Consolidator##'..me, main.openGui)
        if main.drawGui then
            main.tscWindow()
        end
        ImGui.End()
    else
        utils.stopAll()
    end
end

--Toon context menu
function main.toonContext(toon)
    if ImGui.BeginPopupContextItem('##'..toon) then
        if ImGui.Selectable('\xef\x89\x8e'..' Make tiebreaker') then
            cm.settings.tiebreaker = toon
            cm:save('settings')
            print('\at[TsC]\ao \ay'..utils.fname(toon)..'\ao is now the tiebreaker.')
        end
        if ImGui.Selectable('\xef\x8a\x90'..'  Add to mules') then
            tm:addMule(toon)
        end
        if ImGui.Selectable('\xef\x80\x94'..'  Remove') then
            tm:removeToon(toon)
            tm:createLists()
        end
    ImGui.EndPopup()
    end
end

--Mule context window
function main.muleContext(mule)
    if ImGui.BeginPopupContextItem('##'..mule) then
        if ImGui.Selectable('\xee\x97\x87'..' Move up') then tm.moveMuleUp(mule) end
        if ImGui.Selectable('\xee\x97\x85'..' Move down') then tm.moveMuleDown(mule) end
        if ImGui.Selectable('\xef\x80\x94'..'  Remove') then tm:removeMule(mule) end
    ImGui.EndPopup()
    end
end

--Main TSC window
function main.tscWindow()
    ImGui.SetWindowSize(1034,365)

    if sm.status == 'Idle' then
        main.disabled = false
    else
        main.disabled = true
    end

    --Initialize sub windows
    matchesWindow.draw()
    if sm.tradeConfirmWnd then
        matchesWindow.openMatch = true
    else
        matchesWindow.openMatch = false
    end

    leftoversWindow.draw()
    if sm.leftoverConfirmWnd then
        leftoversWindow.openLeft = true
    else
        leftoversWindow.openLeft = false
    end

    searchWindow.draw()
    -- if sm.searchWnd then
    --     searchWindow.openSearch = true
    -- else
    --     searchWindow.openSearch = false
    -- end

    if listWindow.whosList == '' then
        ImGui.PushStyleColor(ImGuiCol.TitleBg, ImVec4(0.3, 0.3, 0, 1.0)) -- Set the inactive title bar color
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, ImVec4(.5, .5, 0, 1)) -- Set the active title bar color
    elseif listWindow.whatList == 'hoard' then
        ImGui.PushStyleColor(ImGuiCol.TitleBg, ImVec4(0, 0.3, 0, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, ImVec4(0, 0.5, 0, 1.0))
    else
        ImGui.PushStyleColor(ImGuiCol.TitleBg, ImVec4(0.3, 0.3, 0, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, ImVec4(.5, .5, 0, 1))
    end
    listWindow.draw()
    ImGui.PopStyleColor(2)
    ignorewnd.draw()

    --Status section
    local tblflags = 0
    local columnFlags2 = ImGuiTableColumnFlags.WidthStretch
    local columnFlags = ImGuiTableColumnFlags.WidthFixed
    local statusX, statusY = ImGui.GetContentRegionAvail()
    local statusHalf = statusX * .55

    if ImGui.BeginTable('Status', 8, tblflags, statusX, 0) then
        --Set widths
        ImGui.TableSetupColumn('',columnFlags2,statusHalf/3 - 10)
        ImGui.TableSetupColumn('',columnFlags2,statusHalf/3)
        ImGui.TableSetupColumn('',columnFlags,statusHalf/3 + 7)
        ImGui.TableSetupColumn('',columnFlags2, statusX / 2 + 5)

        ImGui.TableNextRow()
            ImGui.TableNextColumn()
            --Status
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup()
                ImGui.Text('Status:')
                ImGui.SameLine()
                if sm.status == 'Idle' then
                    ImGui.TextColored(0,1,0,1,sm.status)
                else
                    ImGui.TextColored(1,1,0,1,sm.status)
                end
                ImGui.EndGroup()

            ImGui.TableNextColumn()
            --Tiebreaker
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup()
                ImGui.Text('Tiebreaker:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1,utils.fname(cm.settings.tiebreaker))
                ImGui.EndGroup()
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.tie) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.BeginDisabled(main.disabled)
            ImGui.TableNextColumn()
            --Item mode combo
                ImGui.Text('Item mode:')
                ImGui.SameLine()
                ImGui.SetNextItemWidth(120)
                if ImGui.BeginCombo('##Mode', sm.itemType,0) then
                    if ImGui.Selectable('Tradeskill', sm.itemType == 'Tradeskill') then
                        sm.itemType = 'Tradeskill'
                    end
                    if ImGui.Selectable('Collectibles', sm.itemType == 'Collectibles') then
                        sm.itemType = 'Collectibles'
                    end
                ImGui.EndCombo()
                end

            ImGui.TableNextColumn()
                   

        ImGui.EndDisabled()
    ImGui.EndTable()
    end
    --End status section

    --Toons table
    local tableFlags = ImGuiTableFlags.ScrollY + ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH

    if ImGui.BeginTable('ToonTable', 7, tableFlags, ImVec2(670,270)) then
        --Set widths
        ImGui.TableSetupColumn('', columnFlags, 10) -- Status icon
        ImGui.TableSetupColumn('', columnFlags2, 85) -- Name
        ImGui.TableSetupColumn('', columnFlags, 30) -- Inv
        ImGui.TableSetupColumn('', columnFlags, 120) -- Trade mode
        ImGui.TableSetupColumn('', columnFlags, 120) -- Leftovers
        ImGui.TableSetupColumn('', columnFlags, 100) -- Self-clean
        ImGui.TableSetupColumn('', columnFlags, 100) -- Give all items

        --Header row
        ImGui.TableNextRow(0, 25)
        ImGui.TableNextColumn()
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Name')
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Inv')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.inv) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Trade mode')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.mode) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Leftovers')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.rest) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Self-clean')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.self) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Give all items')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.give) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --A row for each toon
        local comboModeID = '##1'
        local comboRestID = '##2'
        local sortedOnlineToons = tm.alphabetizeTableByKey(tm.onlineToons)
        for _, toon in ipairs(sortedOnlineToons) do
            ImGui.BeginDisabled(main.disabled)
            if not toon or not cm.toons[toon] then
                goto continue
            end
            local inv = tm.onlineToons[toon]
            comboModeID = comboModeID..toon
            comboRestID = comboRestID..toon

            --First list toons that are in-zone
            ImGui.TableNextRow()

                --Red, green, or yellow icon
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    if inv > 49 then
                        ImGui.TextColored(0,1,0,1,'\xef\x84\x91')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Online and in-zone. Inv: '..inv) end
                    else
                        ImGui.TextColored(1,1,0,.8,'\xef\x84\x91')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Low inventory! Inv: '..inv) end
                    end

                --Name
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextColored(1,1,1,1,utils.fname(toon))
                    main.toonContext(toon)
                    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end

                --Inv
                ImGui.TableNextColumn()
                    local toonInv = inv
                    if mq.TLO.Spawn('PC ='..toon)() then
                        ImGui.TextColored(1,1,1,1, toonInv)
                    else
                        ImGui.TextDisabled(toonInv)
                    end

                --Mode
                ImGui.TableNextColumn()
                    local x = ImGui.GetContentRegionAvail()
                    ImGui.SetNextItemWidth(x)
                    if cm.toons[toon] and ImGui.BeginCombo(comboModeID, cm.toons[toon].mode) then
                        for _, mode in pairs(modeOptions) do
                            if ImGui.Selectable(mode, cm.toons[toon].mode == mode) then
                                cm.toons[toon].mode = mode
                                cm:save('toons')
                            end
                        end
                        ImGui.EndCombo()
                    end

                --Leftovers
                ImGui.TableNextColumn()
                    ImGui.SetNextItemWidth(x)
                    if cm.toons[toon] and ImGui.BeginCombo(comboRestID, cm.toons[toon].leftovers) then
                        for _, option in pairs(restOptions) do
                            if ImGui.Selectable(option, cm.toons[toon].leftovers == option) then
                                cm.toons[toon].leftovers = option
                                cm:save('toons')
                            end
                        end
                        ImGui.EndCombo()
                    end

                --Self-clean button
                ImGui.TableNextColumn()
                    if ImGui.Button('Clean toon##'..toon, 100, 20) then
                        if cm.settings.fullAuto == false then
                            ImGui.OpenPopup('Self-clean confirmation##'..toon)
                        else
                            sm.activeToon = toon sm.routine = 'clean' sm.start = true
                        end
                    end
                    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.self) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

                --Give button
                ImGui.TableNextColumn()
                    if ImGui.Button('Select...##'..toon, 100, 20) then ImGui.OpenPopup('give##'..toon) end

                    --Give pop-up
                    if ImGui.BeginPopup('give##'..toon) then
                        ImGui.TextColored(1,1,0,1,'Give all '..sm.itemType..' items to another?')
                        ImGui.Text('Who should '..utils.fname(toon)..' give to?')
                        if ImGui.BeginCombo('##GiveCombo', utils.fname(sm.giveTarget)) then
                            local list = utils.getAlphabetizedList(tm.onlineToons)
                            for _,peer in pairs(list) do
                                if toon ~= peer then
                                    if ImGui.Selectable(utils.fname(peer), sm.giveTarget == peer) then
                                        sm.giveTarget = peer
                                    end
                                end
                            end
                            ImGui.EndCombo()
                        end
                        if ImGui.Button('Start##'..toon) then
                            if sm.giveTarget ~= '' then
                                if cm.settings.fullAuto == false then
                                    ImGui.OpenPopup('Give confirmation##'..toon)
                                else
                                    sm.activeToon = toon sm.routine = 'give' sm.start = true
                                end
                            end
                        end
                        ImGui.SameLine()
                        local update
                        sm.includeBank, update = ImGui.Checkbox('Include bank/depot', sm.includeBank)
                        if update then utils.switch(sm.includeBank) end

                        --Give confirmation modal
                        ImGui.SetNextWindowSize(400, 120, ImGuiCond.Appearing)
                        if ImGui.BeginPopupModal('Give confirmation##'..toon, nil, ImGuiWindowFlags.AlwaysAutoResize) then
                            ImGui.TextColored(1,1,0,1,'Ready?')
                            ImGui.Text('Item mode:')
                            ImGui.SameLine()
                            ImGui.TextColored(0,1,0,1, sm.itemType)
                            ImGui.TextWrapped(utils.fname(toon)..' will give all their '..sm.itemType..' items to '..utils.fname(sm.giveTarget)..'.')
                            ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
                            if ImGui.Button('Give') then
                                if toon == sm.giveTarget then
                                    print('\at[TsC]\ao You can\'t give your yourself!')
                                else
                                    sm.activeToon = toon sm.routine = 'give' sm.start = true
                                    ImGui.CloseCurrentPopup()
                                end
                                ImGui.CloseCurrentPopup()
                            end
                            ImGui.PopStyleColor()
                            ImGui.SameLine()
                            ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
                                if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                            ImGui.PopStyleColor()
                        ImGui.EndPopup()
                        end
                    ImGui.EndPopup()
                    end

            --Self-clean confirmation modal
            ImGui.SetNextWindowSize(400, 170, ImGuiCond.Appearing)
            if ImGui.BeginPopupModal('Self-clean confirmation##'..toon, nil, ImGuiWindowFlags.AlwaysAutoResize) then
                ImGui.TextColored(1,1,0,1,'Ready?')
                ImGui.Text('Item mode:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1, sm.itemType)
                ImGui.TextWrapped(utils.fname(toon)..tip.confirmself)
                ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
                    if ImGui.Button('Self-clean') then sm.activeToon = toon sm.routine = 'clean' sm.start = true ImGui.CloseCurrentPopup() end
                ImGui.PopStyleColor()
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
                    if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                ImGui.PopStyleColor()
            ImGui.EndPopup()
            end

            
            ImGui.EndDisabled()
            ::continue::
        end
        --End in-zone toons

        --Off-line toons
        local sortedOnOfflineToons = tm.alphabetizeTableByKey(tm.offlineToons)
        for _, toon in ipairs(sortedOnOfflineToons) do
            ImGui.BeginDisabled(main.disabled)
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextColored(1,0,0,.5,'\xef\x84\x91')
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextDisabled(utils.fname(toon))
                    main.toonContext(toon)
                    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
            ImGui.EndDisabled()
        end

        --Add toon button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.TableNextColumn()

        ImGui.BeginDisabled(main.disabled)
            if ImGui.Button('Add...') then ImGui.OpenPopup('addtoon') end
        ImGui.EndDisabled()
        ImGui.SameLine()
        ImGui.Text('\xee\xa2\x8f')
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.toon) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Add toon pop-up
        if ImGui.BeginPopup('addtoon') then
            ImGui.TextColored(1,1,0,1,'Add a toon')
            ImGui.Text('DanNet peers:')
            if ImGui.BeginCombo('##AddToonCombo', newToon) then
                for peer,_ in pairs(tm.availableToons) do
                    if ImGui.Selectable(utils.fname(peer), newToon == peer) then
                        newToon = peer
                        tm:addToon(newToon)
                        newToon = ''
                        ImGui.CloseCurrentPopup()
                    end
                end

                ImGui.EndCombo()
            end
            if ImGui.Button('Add all') then tm:addAllToons() ImGui.CloseCurrentPopup() end
            ImGui.EndPopup()
        end

    ImGui.EndTable()
    end
    --End Toons table

    ImGui.SameLine()

    --Mules table
    local muleTableFlags = ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH + ImGuiTableFlags.NoHostExtendX +  ImGuiTableFlags.ScrollY
    if ImGui.BeginTable('Muletable',2,muleTableFlags, ImVec2(200, 270)) then
        ImGui.BeginDisabled(main.disabled)
        ImGui.TableSetupColumn('Mules', ImGuiTableColumnFlags.WidthStretch)
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.self) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.TableSetupColumn('Inv', ImGuiTableColumnFlags.WidthFixed, 40)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        --A row for each mule
        local sortedMules = tm.orderMulesTable(cm.mules)
        for _,mule in ipairs(sortedMules) do
            ImGui.TableNextRow()
                ImGui.TableNextColumn()
                    if tm.onlineMules[mule] then
                        ImGui.TextColored(1,1,1,1,utils.fname(mule))
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
                    else
                        ImGui.TextDisabled(utils.fname(mule))
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
                    end
                    main.muleContext(mule)
                ImGui.TableNextColumn()
                if tm.onlineMules[mule] then    
                    if mq.TLO.Spawn('PC ='..mule)() then
                        ImGui.TextColored(1,1,1,1, tm.onlineMules[mule])
                    else
                        ImGui.TextDisabled('0')
                    end
                end
        end

        --Add mule button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()

        if ImGui.Button('Add...') then ImGui.OpenPopup('addmule') end
        ImGui.SameLine()
    ImGui.EndDisabled()
        ImGui.Text('\xee\xa2\x8f')
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.mule) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Add mule pop-up
        if ImGui.BeginPopup('addmule') then
            ImGui.TextColored(1,1,0,1,'Add a mule')
            ImGui.Text('DanNet peers:')
            if ImGui.BeginCombo('##AddMuleCombo', newMule) then
                for peer,_ in pairs(tm.availableMules) do
                    if ImGui.Selectable(utils.fname(peer), newMule == peer) then
                        newMule = peer
                        tm:addMule(newMule)
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.EndPopup()
        end
    ImGui.EndTable()
    end
    --End mules table

    ImGui.SameLine()
    ImGui.BeginGroup()
        local x,y = ImGui.GetContentRegionAvail()
        --Consolidate all button
        ImGui.BeginDisabled(main.disabled)
        ImGui.PushStyleColor(ImGuiCol.Button, 0, 1, 0, .5)
            if ImGui.Button('Consolidate all', x,0) then 
                if cm.settings.fullAuto == false then
                    ImGui.OpenPopup('Consolidate confirmation')
                else
                    sm.routine = 'consolidate' sm.start = true
                end
            end
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.go) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Clean all button
        ImGui.PushStyleColor(ImGuiCol.Button, 0, .5, 0, .5)
        if ImGui.Button('Self-clean all',x,0) then
            if cm.settings.fullAuto == false then
                ImGui.OpenPopup('Self-clean ALL toons confirmation##all')
            else
                sm.routine = 'cleanAll' sm.start = true
            end
        end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.tidyall) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --All give to all
        if ImGui.Button('All give to...',x,0) then
            ImGui.OpenPopup('Every toon give all items to...##all')
        end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.allgive) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.PopStyleColor()

        --Give ALL pop-up
        if ImGui.BeginPopup('Every toon give all items to...##all') then
            ImGui.TextColored(1,1,0,1,'Everyone give all '..sm.itemType..' items to another?')
            ImGui.Text('Who should everyone give to?')
            if ImGui.BeginCombo('##GiveCombo', utils.fname(sm.giveTarget)) then
                local list = utils.getAlphabetizedList(tm.onlineToons)
                for _,peer in pairs(list) do
                    if ImGui.Selectable(utils.fname(peer), sm.giveTarget == peer) then
                        sm.giveTarget = peer
                    end
                end
                ImGui.EndCombo()
            end
            if ImGui.Button('Start##giveall') then
                if sm.giveTarget ~= '' then
                    if cm.settings.fullAuto == false then
                        ImGui.OpenPopup('Give confirmation##ALL')
                    else
                        sm.routine = 'giveAll' sm.start = true
                    end
                end
            end
            ImGui.SameLine()
            local update
            sm.includeBank, update = ImGui.Checkbox('Include bank/depot', sm.includeBank)
            if update then utils.switch(sm.includeBank) end

            --Give ALL confirmation modal
            ImGui.SetNextWindowSize(400, 120, ImGuiCond.Appearing)
            if ImGui.BeginPopupModal('Give confirmation##ALL', nil, ImGuiWindowFlags.AlwaysAutoResize) then
                ImGui.TextColored(1,1,0,1,'Ready?')
                ImGui.Text('Item mode:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1, sm.itemType)
                ImGui.TextWrapped('Everyone will give all their '..sm.itemType..' items to '..utils.fname(sm.giveTarget)..'.')
                ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
                if ImGui.Button('Give') then
                    sm.routine = 'giveAll' sm.start = true
                    ImGui.CloseCurrentPopup()
                end
                ImGui.PopStyleColor()
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
                    if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                ImGui.PopStyleColor()
            ImGui.EndPopup()
            end
        ImGui.EndPopup()
        end

        ImGui.Dummy(ImVec2(0, 2)) -- Add 10 pixels of vertical space before the separator- Add vertical space before the separator
        ImGui.Separator()
        ImGui.Dummy(ImVec2(0, 2)) -- Add 10 pixels of vertical space after the separator- Add vertical space after the separator

        

        --Search button
        ImGui.PushStyleColor(ImGuiCol.Button, 1, .5, 0, .5)
        if ImGui.Button('Search & Deliver',x,0) then
            sm.routine = 'search' sm.start = true
            searchWindow.openSearch = not searchWindow.openSearch
        end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.search) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.PopStyleColor()

        ImGui.Dummy(ImVec2(0, 2))
        ImGui.Separator()
        ImGui.Dummy(ImVec2(0, 2))

        --All lists button
        ImGui.PushStyleColor(ImGuiCol.Button, 1, 1, 0, .5)
        if ImGui.Button('Personal lists',x,0) then
            listWindow.openList = not listWindow.openList
            end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.ignorebutton) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Global ignore button
        if ImGui.Button('Global ignore list',x,0) then
            ignorewnd.openList = not ignorewnd.openList
        end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.ignorebutton) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.PopStyleColor()
        ImGui.Dummy(ImVec2(0, 2))
        ImGui.Separator()
        ImGui.Dummy(ImVec2(0, 2))
        ImGui.EndDisabled()

        --Stop button
        ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
            if ImGui.Button('Stop all',x,0) then utils.stopAll(true) end
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.stop) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            
    ImGui.EndGroup()
    ImGui.BeginDisabled(main.disabled)

    --Stats checkbox
    local updateStats
    cm.settings.stats, updateStats = ImGui.Checkbox('Run stats', cm.settings.stats)
    if updateStats then utils.switch(cm.settings.stats) cm:save('settings') end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.stats) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    --Full auto mode
    local updateFullAuto
    cm.settings.fullAuto, updateFullAuto = ImGui.Checkbox('Full-auto ', cm.settings.fullAuto)
    if updateFullAuto then utils.switch(cm.settings.fullAuto) cm:save('settings') end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.fullauto) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    --Real estate checkbox
    local updateReal
    cm.settings.includePlots, updateReal = ImGui.Checkbox('Include plots ', cm.settings.includePlots)
    if updateReal then utils.switch(cm.settings.includePlots) cm:save('settings') end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.real) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    --Prefer real estate
    local updateReal2
    cm.settings.preferPlots, updateReal2 = ImGui.Checkbox('Prefer plots ', cm.settings.preferPlots)
    if updateReal2 then utils.switch(cm.settings.preferPlots) cm:save('settings') end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.prefReal) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

    ImGui.EndDisabled()

    --Version info
    ImGui.SameLine()
    ImGui.TextColored(1,1,1,.7,' v'..cm.version)

    --Depot warning modal
    if sm.status == 'Depot warning' then ImGui.OpenPopup('Window Focus Warning') end
    ImGui.SetNextWindowSize(400, 0, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Window Focus Warning', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1,'WARNING!')
        ImGui.TextWrapped(tip.depotwarning)
        if ImGui.Button('I am ready') then sm.status = 'Depositing' ImGui.CloseCurrentPopup() end
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then sm.status = 'Idle' ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end

    --Consolidate all confirmation modal
    ImGui.SetNextWindowSize(400, 155, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Consolidate confirmation', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1, 'Ready?')
        ImGui.Text('Item mode:')
        ImGui.SameLine()
        ImGui.TextColored(0,1,0,1, sm.itemType)
        ImGui.TextWrapped(tip.goall)
        ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
            if ImGui.Button('Consolidate all') then sm.routine = 'consolidate' sm.start = true ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end

    --Clean all confirmation modal
    ImGui.SetNextWindowSize(400, 170, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Self-clean ALL toons confirmation##all', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1,'Ready?')
        ImGui.Text('Item mode:')
        ImGui.SameLine()
        ImGui.TextColored(0,1,0,1, sm.itemType)
        ImGui.TextWrapped('All toons'..tip.confirmself)
        ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
            if ImGui.Button('Self-clean all toons') then sm.routine = 'cleanAll' sm.start = true ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end
    
end

return main