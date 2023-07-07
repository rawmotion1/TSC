--Tradeskill Consolidator (TSC) by Rawmotion
--- @type Mq
local mq = require('mq')
local tip = require('tooltips')
local version = '1.0.0'
local me = mq.TLO.Me.Name()

local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local ignorePath = 'TSC/ignore.lua'
local matchesPath = 'TSC/tmp/matches.lua'

local settings = {}
local alltoons = {}

--------Create missing files--------
local function createFiles(file)

    if file == 'settings' then
        settings = { ['tiebreaker'] = 'Toonone', ['artisan'] = 'Nobody', ['stats'] = true, ['mules'] = {'Muleone', 'Muletwo', 'Mulethree'}, ['driver'] = '' }
        mq.pickle(settingPath, settings)
        print('\at[TsC]\ao Creating \ayTSC/settings.lua \aoin your config folder.')
    end

    if file == 'toons' then
        local defaultToons = {'Tooneone', 'Toontwo', 'Toonthree','Toonfour', 'Toonefive', 'Toonsix'}
        for _,v in pairs(defaultToons) do
            local toon = {
                name = v,
                mode = 'Default', --Default, Generous, Greedy
                leftovers = 'Off' --Off, DBM, DB, DM, BM, B, M
            }
            table.insert(alltoons, toon)
        end
        mq.pickle(toonPath, alltoons)
        print('\at[TsC]\ao Creating \ayTSC/toons.lua \aoin your config folder.')
    end

    if file == 'ignore' then
        local ignore = { 'Loaf of Bread', 'Water Flask' }
        mq.pickle(ignorePath, ignore)
        print('\at[TsC]\ao Creating \ayTSC/ignore.lua \aoin your config folder.')
    end
end

--------Load files--------
local fileMissing = false
local function loadFiles()

    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        createFiles('settings')
        fileMissing = true
    elseif loadSettings then
        settings = loadSettings()
    end

    local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
    if toonError then
        createFiles('toons')
        fileMissing = true
    elseif loadToons then
        alltoons = loadToons()
    end

    local loadIgnore, ignoreError = loadfile(mq.configDir..'/'..ignorePath)
    if ignoreError then
        createFiles('ignore')
        fileMissing = true
    end
end
loadFiles()

if fileMissing == true then
    print('\at[TsC]\ao Please update your ignore file and then run the script again.')
    mq.pickle(settingPath, settings)
    mq.exit()
end


print('\at[TsC]\ao Welcome to TS Consolidator v'..version)
print('\at[TsC]\ao Make sure all your toons are in the same zone.')
print('\at[TsC]\ao Make sure there is a banker nearby.')



---------------------Helper functions-------------------------

settings.driver = me
local status = 'Idle'

local function save()
    mq.pickle(toonPath, alltoons)
    mq.pickle(settingPath, settings)
end
save()

local function switch(v)
    v = not v
end

local function checkBanker()
    if mq.TLO.NearestSpawn('banker').Name() == nil then
        print('\at[TsC]\ao There is no banker in this zone. Stopping.')
        return false
    end
    return true
end

--Check which toons are in-zone
local toons = {}
local function checkToons()
    local tmptable = {}
    for index,toon in pairs(alltoons) do
        if mq.TLO.NearestSpawn('='..toon.name)() == nil then
            alltoons[index].inzone = false
        else
            alltoons[index].inzone = true
            local entry = toon
            table.insert(tmptable, entry)
        end
    end
    toons = tmptable --Create reduced toons table if not all toons are in-zone
end

--Check mule inventories
local muleInv = {}
local function checkMules()
    for _,mule in pairs(settings.mules) do
        if mq.TLO.NearestSpawn('='..mule)() then
            if mule == me then
                muleInv[mule] = mq.TLO.Me.FreeInventory()
            else
                mq.cmdf('/dquery %s -q Me.FreeInventory', mule)
                mq.delay(200)
                muleInv[mule] = mq.TLO.DanNet.Q()
            end
        else
            muleInv[mule] = 0
        end
    end
end

--Turn active toon into single-entry table
local function checkName(name)
    local toon = {[1]={}}
    toon[1]['name'] = name
    return toon
end

--Determine lize of given list
local function listSize(who)
    local count = 0
    for _,v in pairs(who) do
        count = count + 1
    end
    return count
end

--Emergency stop
local function stopAll()
    mq.cmd('/dgae /squelch /lua stop TSC/scan.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/match.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/grab.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/trade.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/bank.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/depot.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/leftover.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/give.lua')
    status = 'Idle'
end
----------------------------------------

--Routine functions

--------Create empty stat tables--------
local stats = {}
local function createStats(who)
    for _,toon in pairs(who) do
        stats = {
            beforeItems = 'unset',
            beforeSlots = 'unset',
            afterItems = 'unset',
            afterSlots = 'unset',
        }
        mq.pickle('TSC/tmp/stats_'..toon.name..'.lua', stats)
    end
end


--------Scan toons--------
local scanCount
local function stopWaitingScanning() scanCount = scanCount + 1 end
local function scan(who, mode, scope, what)
    --who: toon table, mode: 1 is normal 2 is givemode, scope: 1 is all 4 is inventory, what: 41 is mats 19 is collectibles
    print('\at[TsC]\ao------\agStart\ao scanning routine.')

    if mode == nil then mode = 1 end
    if scope == nil then scope = 1 end
    if what == nil then what = 41 end

    local length = listSize(who)
    if length > 0 then
        status = 'Scanning'

        for _,toon in pairs(who) do
            if toon.name == me then
                mq.cmdf('/lua run TSC/scan %s %s %s', mode, scope, what)
            else
                mq.cmdf('/dex %s /squelch /lua run TSC/scan %s %s %s', toon.name, mode, scope, what)
            end
        end

        scanCount = 0
        while scanCount < length do
            mq.delay(100)
        end
        scanCount = 0

    end
    print('\at[TsC]\ao------\arDone\ao scanning routine.')
    mq.delay(2000)
end


--------Find matches, determine trades, identify traders--------
local traders
local matches = {}
local waitingMatches
local function stopWaitingMatching() waitingMatches = false end
local function match()
    status = 'Finding matches'
    mq.cmd('/lua run TSC/match.lua')

    waitingMatches = true
    while waitingMatches do
        mq.delay(100)
    end

    mq.delay(2000)

    local matchlist, matchError = loadfile(mq.configDir..'/'..matchesPath)
    if matchError then
        print('\at[TsC]\ao Error loading matches.lua')
    elseif matchlist then
        matches = matchlist()
    end

    traders = {}
    for k,_ in pairs(matches) do
        local entry = {['name'] = k}
        table.insert(traders, entry)
    end
end


--------Grab items from the bank to give to others--------
local grabCount
local function stopWaitingGrabbing() grabCount = grabCount + 1 end
local function grab(who, what)

    print('\at[TsC]\ao------\agStart\ao grabbing routine.')

    if what == nil then what = 41 end

    local length = listSize(who)
    if length > 0 then
        status = 'Grabbing'

        for _,toon in pairs(who) do
            if toon.name == me then
                mq.cmdf('/squelch /lua run TSC/grab %s', what)
            else
                mq.cmdf('/squelch /dex %s /lua run TSC/grab %s', toon.name, what)
            end
        end

        grabCount = 0
        while grabCount < length do
            mq.delay(100)
        end
        grabCount = 0

    end
    print('\at[TsC]\ao------\arDone\ao grabbing routine.')
    mq.delay(2000)
end


--------Trading routine, one toon at a time--------
local waitingTrading
local function stopWaitingTrading() waitingTrading = false end
local function trade(who)

    print('\at[TsC]\ao------\agStart\ao trading routine.')

    local length = listSize(who)
    if length > 0 then
        status = 'Trading'

        for _,toon in pairs(who) do
            waitingTrading = true

            if toon.name == me then
                mq.cmd('/squelch /lua run TSC/trade')
            else
                mq.cmdf('/squelch /dex %s /lua run TSC/trade', toon.name)
            end

            print('\at[TsC]\ao Telling \ar'..toon.name..' \ao to start trading routine.')

            while waitingTrading do
                mq.delay(100)
            end
        end

    end
    print('\at[TsC]\ao------\arDone\ao trading routine.')
    mq.delay(2000)
end


--------Banking routine--------
local bankCount
local function stopwaitingBanking() bankCount = bankCount + 1 end
local function bank(who)
    status = 'Banking'

    print('\at[TsC]\ao------\agStart\ao banking routine.')

    local length = listSize(who)

    for _,toon in pairs(who) do
        if toon.name == me then
            mq.cmd('/squelch /lua run TSC/bank')
        else
            mq.cmdf('/squelch /dex %s /lua run TSC/bank', toon.name)
        end
    end

    bankCount = 0
    while bankCount < length do
        mq.doevents()
        mq.delay(100)
    end
    bankCount = 0

    print('\at[TsC]\ao------\arDone\ao banking routine.')
    mq.delay(2000)
end


--------Depot routine. This needs to be done one at a time.--------
local waitingDepot
local function stopWaitingDepot() waitingDepot = false end
local function depot(who)
    status = 'Depot'

    print('\at[TsC]\ao------\agStart\ao depot routine.')

    for _,toon in pairs(who) do
        waitingDepot = true
        if toon.name == me then
            mq.cmd('/squelch /lua run TSC/depot')
        else
            mq.cmdf('/squelch /dex %s /lua run TSC/depot', toon.name)
        end

        print('\at[TsC]\ao Telling \ar'..toon.name..' \ao to start depot routine.')
        print('\at[TsC]\ay Your window focus may change to \ar'..toon.name..'\'s \ayEQ window.')

        while waitingDepot do
            mq.delay(100)
        end
    end

    print('\at[TsC]\ao------\arDone\ao depot routine.')
    mq.delay(2000)
end


--------Leftover routine. This needs to be done one at a time.--------
local waitingRest
local function stopwaitingRest() waitingRest = false end
local function rest(who)
    status = 'Leftovers'

    print('\at[TsC]\ao------\agStart\ao leftover routine.')

    for _,toon in pairs(who) do
        if toon.leftovers ~= 'Off' then
            waitingRest = true
            if toon.name == me then
                mq.cmd('/squelch /lua run TSC/leftover')
            else
                mq.cmdf('/squelch /dex %s /lua run TSC/leftover', toon.name)
            end

            print('\at[TsC]\ao Telling \ar'..toon.name..' \ao to start leftover routine.')
            print('\at[TsC]\ay Your window focus may change to \ar'..toon.name..'\'s \ayEQ window.')

            while waitingRest do
                mq.delay(100)
            end
        end
    end

    print('\at[TsC]\ao------\arDone\ao leftover routine.')
    mq.delay(2000)
end


--------Calculate results--------
local function calcStats(who, what)
    status = 'Calculating'
    print('\at[TsC]\ao Rescanning to calculate stats...')

    if what == 'Collectibles' then scan(who,1,1,19) else scan(who) end

    print('\at[TsC]\ao------Approximate results------')
    
    local totalSavings = 0
    for _,toon in pairs(who) do
        local path = "TSC/tmp/stats_"..toon.name..".lua"
        local toonStats = {}
        local statList, staterror = loadfile(mq.configDir..'/'..path)
        if staterror then
            --nothing
        elseif statList then
            toonStats = statList()
        end

        local itemDifference = toonStats['afterItems'] - toonStats['beforeItems']
        local slotDifference = toonStats['afterSlots'] - toonStats['beforeSlots']

        local pid
        local pis
        if itemDifference < 0 then pid = '\ao(\ag'..itemDifference..'\ao)' elseif itemDifference > 0 then pid = '\ao(\ar+'..itemDifference..'\ao)' else pid = '\ao(\awnc\ao)' end
        if slotDifference < 0 then pis = '\ao(\ag'..slotDifference..'\ao)' elseif slotDifference > 0 then pis = '\ao(\ar+'..slotDifference..'\ao)' else pis = '\ao(\awnc\ao)' end
        
        print('\at[TsC]\ar '..toon.name..' \ao had \ay'..toonStats['beforeItems']..' \aoitems using \ay'..toonStats['beforeSlots']..'\ao slots, now has \am'..toonStats['afterItems']..' \ao items '..pid..' using \am'..toonStats['afterSlots']..' \aoslots '..pis..'.')
        totalSavings = totalSavings - slotDifference
    end
    print('\at[TsC]\ao TOTAL: You freed up \ag'..totalSavings..' \aoslots across \ay'..listSize(who)..'\ao toons.')
end


-------------------------
---Function parameters---
local itemMode = 'Tradeskill'
local activeToon = ''
local giveTarget = ''
local giveAll = false
local function clearParameters()
    activeToon = ''
    giveTarget = ''
    giveAll = false
end

----------------------------
--------Main routine--------
local function go(what)
    if checkBanker() == false then return end

    createStats(toons)

    if what == 'Collectibles' then scan(toons,1,1,19) else scan(toons) end
    match()

    if what == 'Collectibles' then grab(traders, 19) else grab(traders) end

    trade(traders)

    if what == 'Collectibles' then scan(traders,1,1,19) else scan(traders) end

    bank(toons)
    depot(toons)
    rest(toons)

    if settings.stats == true then calcStats(toons, what) end

    print('\at[TsC]\ao EVERYTHING DONE')
    status = 'Idle'
end


--------------------------------
--------Self-consolidate--------
local function self(who, what)

    --Reset parameters for GUI
    clearParameters()

    --Turn into single-entry table
    who = checkName(who)

    if checkBanker() == false then return end

    createStats(who)

    if what == 'Collectibles' then scan(who,1,1,19) else scan(who) end

    bank(who)
    depot(who)
    rest(who)

    if settings.stats == true then calcStats(who, what) end

    print('\at[TsC] \ar'..who[1].name..'\'s \ao self-consolidation is done.')
    status = 'Idle'
end


----------------------------
--------Give routine--------
local function give(who, receiver, im, ga)

    --Reset parameters for GUI
    clearParameters()

    --Turn into single-entry table
    who = checkName(who)

    --Ensure receiver is in-zone
    receiver = (receiver:gsub("^%l", string.upper))
    if not mq.TLO.NearestSpawn('='..receiver)() then
        print('\at[TsC]\ao Target not found in zone. Stopping.')
        return
    end

    --figure out flags
    local what, scope
    if im == 'Collectibles' then what = 19 else what = 41 end
    if ga == true then scope = 1 if not checkBanker() then return end else scope = 4 end

    scan(who, 2, scope, what)

    print('\at[TsC]\ao------\agStart\ao giving routine.')

    status = 'Giving'

    local player = who[1].name
    if player == me then
        mq.cmdf('/lua run TSC/give %s %s %s', receiver, scope, what)
    else
        mq.cmdf('/dex %s /lua run TSC/give %s %s %s', player, receiver, scope, what)
    end
end

local function doneGiving()
    print('\at[TsC]\ao------\arDone\ao giving routine.')
    status = 'Idle'
end

---------------------

--------Binds--------
local function binds(a, b, c, d)
    if a == 'match' then
        match()
    elseif a == 'rescan' then
        scan(traders, 2)
    elseif a == 'scan' then
        scan(toons)
    elseif a == 'grab' then
        grab(traders)
    elseif a == 'trade' then
        trade(traders)
    elseif a == 'bank' then
        bank(toons)
    elseif a == 'depot' then
        depot(toons)
    elseif a == 'stats' then
        createStats()
    elseif a == 'calc' then
        calcStats(toons)
    elseif a == 'rest' then
        rest(toons)
    elseif a == 'donescanning' then
        stopWaitingScanning()
    elseif a == 'donematching' then
        stopWaitingMatching()
    elseif a == 'donegrabbing' then
        stopWaitingGrabbing()
    elseif a == 'donetrading' then
        stopWaitingTrading()
    elseif a == 'donebanking' then
        stopwaitingBanking()
    elseif a == 'donedepot' then
        stopWaitingDepot()
    elseif a == 'donerest' then
        stopwaitingRest()
    elseif a == 'donegiving' then
        doneGiving()
    end
end
mq.bind('/tsc', binds)




-----------------------
---------GUI-----------
-----------------------

---Function activators---
local goNow = false
local selfNow = false
local giveNow = false

---Combo options---
local modeOptions = {'Default', 'Generous', 'Greedy'}
local restOptions = {'Off', 'DBM', 'DB', 'DM', 'BM', 'B', 'M'}

--Change ordering
local function moveUp(n)
    if n == 1 then return end
    local mule = settings.mules[n]
    local newindex
    for k,v in pairs (settings.mules) do
        if v == mule then
            newindex = k-1
            break
        end
    end
    local oldmule = settings.mules[newindex]
    settings.mules[n] = oldmule
    settings.mules[newindex] = mule
end
local function moveDown(n)
    local length = 0
    local mule = settings.mules[n]
    local newindex
    for k,v in pairs (settings.mules) do
        length = length + 1
        if v == mule then
            newindex = k+1
        end
    end
    if n == length then return end
    local oldmule = settings.mules[newindex]
    settings.mules[n] = oldmule
    settings.mules[newindex] = mule
end

--Context menus
local function toonContext(n, toon)
    if ImGui.BeginPopupContextItem('##'..toon) then
        if ImGui.Selectable('\xef\x89\x8e'..' Make tiebreaker') then settings.tiebreaker = alltoons[n].name save() end
        if ImGui.Selectable('\xef\x82\x91'..'  Make artisan') then settings.artisan = alltoons[n].name save() end
        if ImGui.Selectable('\xef\x8a\x90'..'  Add to mules') then table.insert(settings['mules'], alltoons[n].name) save() end
        if ImGui.Selectable('\xee\xa1\xb2'..' Remove') then alltoons[n] = nil save() end
    ImGui.EndPopup()
    end
end

local function muleContext(n, mule)
    if ImGui.BeginPopupContextItem('##'..mule) then
        if ImGui.Selectable('\xee\x97\x87'..' Move up') then moveUp(n) save() end
        if ImGui.Selectable('\xee\x97\x85'..' Move down') then moveDown(n) save() end
        if ImGui.Selectable('\xee\xa1\xb2'..' Remove') then settings['mules'][n] = nil save() end
    ImGui.EndPopup()
    end
end

--Add toons and mules
local newToon = ''
local function addToon(n)
    if n == nil then return end
    n = (n:gsub("^%l", string.upper))
    local alreadyAdded = false
    for _,toon in pairs(alltoons) do
        if toon.name == n then
            alreadyAdded = true
        end
    end
    if alreadyAdded == false then
        local entry = {
            name = n,
            mode = 'Default',
            leftovers = 'Off',
            inzone = false
        }
        table.insert(alltoons, entry)
    end
    newToon = ''
end
local newMule = ''
local function addMule(n)
    if n == nil then return end
    n = (n:gsub("^%l", string.upper))
    local alreadyAdded = false
    for _,mule in pairs(settings['mules']) do
        if mule == n then
            alreadyAdded = true
        end
    end
    if alreadyAdded == false then
        table.insert(settings['mules'], n)
    end
    newMule = ''
end


--------Draw main window--------
local function tscWindow()
    ImGui.SetWindowSize(780,345)

    --Status section
    if ImGui.BeginTable('Status', 4, ImGuiTableFlags.SizingStretchSame) then
        ImGui.TableNextRow()
            --Status
            ImGui.TableNextColumn()
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup()
                ImGui.Text('Status:')
                ImGui.SameLine()
                if status == 'Idle' then
                    ImGui.TextColored(0,1,0,1,status)
                else
                    ImGui.TextColored(1,1,0,1,status)
                end
                ImGui.EndGroup()
            --Tiebreaker
            ImGui.TableNextColumn()
                ImGui.AlignTextToFramePadding()
                ImGui.Text('Tiebreaker:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1,settings.tiebreaker)
                ImGui.SameLine()
                ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.tie) end
            --Artisan
            ImGui.TableNextColumn()
                ImGui.AlignTextToFramePadding()
                ImGui.Text('Artisan:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1,settings.artisan)
                ImGui.SameLine()
                ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.art) end
                ImGui.SameLine()
                ImGui.Text('\xef\x80\x94')
                if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove artisan') end
                if ImGui.IsItemClicked(ImGuiMouseButton.Left) then settings.artisan = 'Nobody' save() end
            --Item mode combo
            ImGui.TableNextColumn()
                local x = ImGui.GetContentRegionAvail()
                ImGui.SetNextItemWidth(x)
                if ImGui.BeginCombo('##Mode', itemMode,0) then
                    if ImGui.Selectable('Tradeskill', itemMode == 'Tradeskill') then
                        itemMode = 'Tradeskill'
                    end
                    if ImGui.Selectable('Collectibles', itemMode == 'Collectibles') then
                        itemMode = 'Collectibles'
                    end
                ImGui.EndCombo()
                end
    ImGui.EndTable()
    end
    --End status section

    --Toons table
    local tableFlags = ImGuiTableFlags.ScrollY + ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH
    local columnFlags = ImGuiTableColumnFlags.NoSort
    if ImGui.BeginTable('ToonTable', 6, tableFlags, 600, 250) then
        --Set widths
        ImGui.TableSetupColumn('',columnFlags,20)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)

        --Header row
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
            --No clouds here
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Name')
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Mode')
            ImGui.SameLine()
            ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.mode) end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Leftovers')
            ImGui.SameLine()
            ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.rest) end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Self-routine')
            ImGui.SameLine()
            ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.self) end
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Give')
            ImGui.SameLine()
                    ImGui.Text('\xee\xa2\x8f')
                    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.give) end
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible

        --A row for each toon
        local comboModeID = '##1'
        local comboRestID = '##2'
        for index,toon in pairs(alltoons) do
            comboModeID = comboModeID..toon.name
            comboRestID = comboRestID..toon.name

            --First list toons that are in-zone
            if toon.inzone == true then
            ImGui.TableNextRow()

                --Cloud
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.Text('\xee\x8a\xbd')

                --Name
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextColored(1,1,1,1,toon.name)
                    toonContext(index, toon.name)

                --Mode
                ImGui.TableNextColumn()
                    local x = ImGui.GetContentRegionAvail()
                    ImGui.SetNextItemWidth(x)
                    if ImGui.BeginCombo(comboModeID, toon.mode) then
                        for _,mode in pairs(modeOptions) do
                            if ImGui.Selectable(mode, toon.mode == mode) then
                                toon.mode = mode
                                save()
                            end
                        end
                        ImGui.EndCombo()
                    end

                --Leftovers
                ImGui.TableNextColumn()
                    ImGui.SetNextItemWidth(x)
                    if ImGui.BeginCombo(comboRestID, toon.leftovers) then
                        for _,option in pairs(restOptions) do
                            if ImGui.Selectable(option, toon.leftovers == option) then
                                toon.leftovers = option
                                save()
                            end
                        end
                        ImGui.EndCombo()
                    end

                --Self-consolidate button
                ImGui.TableNextColumn()
                    ImGui.PushStyleColor(ImGuiCol.Button, 0, .5, 0, .75)
                        if ImGui.Button('Consolidate##'..toon.name,100,20) then activeToon = toon.name selfNow = true end
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.self) end
                    ImGui.PopStyleColor()

                --Give button
                ImGui.TableNextColumn()
                    local focus = false
                    if ImGui.Button('Give...##'..toon.name,100,20) then ImGui.OpenPopup('give##'..toon.name) focus = true end

                    --Give pop-up
                    if ImGui.BeginPopup('give##'..toon.name) then
                        if focus == true then focus = false ImGui.SetKeyboardFocusHere() end
                        giveTarget = ImGui.InputTextWithHint('##RecipientName', 'Enter recipient\'s name...', giveTarget, 0)
                        if ImGui.Button('Start##'..toon.name) then
                            if giveTarget ~= nil and giveTarget ~= '' then
                                activeToon = toon.name
                                giveNow = true
                                ImGui.CloseCurrentPopup()
                            end
                        end
                        ImGui.SameLine()
                        local update
                        giveAll, update = ImGui.Checkbox('Include everything in bank/depot?', giveAll)
                        if update then switch(giveAll) end
                        ImGui.EndPopup()
                    end
            end
        end
        --End in-zone toons

        --Off-line toons
        for index,toon in pairs(alltoons) do
            if toon.inzone == false then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextDisabled('\xee\x8b\x81')
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextDisabled(toon.name)
                    toonContext(index, toon.name)
            end
        end

        --Add toon button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.TableNextColumn()
        local focus = false
        if ImGui.Button('Add...') then ImGui.OpenPopup('addtoon') focus = true end
        ImGui.SameLine()
                ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.toon) end
        --Add toon pop-up
        if ImGui.BeginPopup('addtoon') then
            if focus == true then focus = false ImGui.SetKeyboardFocusHere() end
            newToon = ImGui.InputTextWithHint('##ToonName', 'Enter name...', newToon, 0)
            if ImGui.Button('Save') then addToon(newToon) ImGui.CloseCurrentPopup() save() end
            ImGui.EndPopup()
        end

    ImGui.EndTable()
    end
    --End Toons table


    ImGui.SameLine()


    --Mules table
    local muleTableFlags = ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH + ImGuiTableFlags.NoHostExtendX
    if ImGui.BeginTable('Muletable',2,muleTableFlags, 0, 250) then
        ImGui.TableSetupColumn('Mules', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Inv', ImGuiTableColumnFlags.WidthFixed, 40)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        --A row for each mule
        for index,mule in pairs(settings.mules) do
            ImGui.TableNextRow()
                ImGui.TableNextColumn()
                    ImGui.TextColored(1,1,1,1,mule)
                    muleContext(index, mule)
                ImGui.TableNextColumn()
                    local inv = muleInv[mule] or '0'
                    ImGui.TextColored(1,1,1,1, inv)
        end

        --Add mule button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        local focus = false
        if ImGui.Button('Add...') then ImGui.OpenPopup('addmule') focus = true end
        ImGui.SameLine()
                ImGui.Text('\xee\xa2\x8f')
                if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.mule) end
        --Add mule pop-up
        if ImGui.BeginPopup('addmule') then
            if focus == true then focus = false ImGui.SetKeyboardFocusHere() end
            newMule = ImGui.InputTextWithHint('##MuleName', 'Enter name...', newMule, 0)
            if ImGui.Button('Save') then addMule(newMule) ImGui.CloseCurrentPopup() save() end
            ImGui.EndPopup()
        end
    ImGui.EndTable()
    end
    --End mules table


    --Go button
    ImGui.PushStyleColor(ImGuiCol.Button, 0, 1, 0, .5)
        if ImGui.Button('TSC Go') then goNow = true end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.go) end
    ImGui.SameLine()

    --Stop button
    ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
        if ImGui.Button('Stop all') then stopAll() end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.stop) end
    ImGui.SameLine()

    --Stats checkbox
    local update
    settings.stats, update = ImGui.Checkbox('Stats', settings.stats)
	if update then switch(settings.stats) save() end
    ImGui.SameLine()
    ImGui.Text('\xee\xa2\x8f')
    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.stats) end
    ImGui.SameLine()

    ImGui.Text('v'..version)
end

local openGui, drawGui = true, true
local function initGui()
    if openGui then
        ImGui.SetNextWindowBgAlpha(1)
        openGui, drawGui = ImGui.Begin('TS Consolidator##'..me, openGui)
        if drawGui then tscWindow() end
        ImGui.End()
    end
end

mq.imgui.init('TSC', initGui)


local terminate = false
while not terminate do
    checkToons()
    checkMules()

    if goNow == true then goNow = false go(itemMode) end
    if selfNow == true then selfNow = false self(activeToon, itemMode) end
    if giveNow == true then giveNow = false give(activeToon, giveTarget, itemMode, giveAll) end

    mq.delay(100)
end