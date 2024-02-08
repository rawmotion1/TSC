--Tradeskill Consolidator (TSC) by Rawmotion
--- @type Mq
local mq = require('mq')
local utils = require('utils')
require 'ImGui'
local PackageMan = require('mq/PackageMan')
PackageMan.Require('luafilesystem', 'lfs')

local tip = require('tooltips')
local filedialog = require('imguifiledialog')
local version = '2.2.1'
local me = mq.TLO.Me.Name()

local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local ignorePath = 'TSC/ignore.lua'
local artisanPath = 'TSC/artisan.lua'
local matchesPath = 'TSC/tmp/matches.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

local settings = {}
local alltoons = {}
local toons = {} --Only in-zone toons
local peerTable = {}
local ignore = {}
local pignoreList = {}
local artisan = {}
local matches = {}
local consol = {}

--------Create missing files--------
local function createFiles(file)

    if file == 'settings' then
        settings = { ['tiebreaker'] = 'Not set', ['artisan'] = 'Not set', ['stats'] = true, ['includePlots'] = false, ['preferPlots'] = false, ['mules'] = {}, ['driver'] = '' }
        mq.pickle(settingPath, settings)
        print('\at[TsC]\ao Creating \ayTSC/settings.lua \aoin your config folder.')
    end

    if file == 'toons' then
        alltoons[1] = {['name'] = me, ['inzone'] = true, ['mode'] = 'Default', ['leftovers'] = 'Off'}
        mq.pickle(toonPath, alltoons)
        local pignore = {}
        mq.pickle(mq.configDir..'/TSC/ignore_'..me..'.lua', pignore)
        print('\at[TsC]\ao Creating \ayTSC/toons.lua \aoin your config folder.')
    end

    if file == 'ignore' then
        ignore = { 'Loaf of Bread', 'Water Flask' }
        mq.pickle(ignorePath, ignore)
        print('\at[TsC]\ao Creating \ayTSC/ignore.lua \aoin your config folder.')
    end

    if file == 'artisan' then
        mq.pickle(artisanPath, artisan)
        print('\at[TsC]\ao Creating \ayTSC/artisan.lua \aoin your config folder.')
    end
end

--------Load files--------
local function loadFiles()

    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        createFiles('settings')
    elseif loadSettings then
        settings = loadSettings()
    end
    --Add additional settings
    if settings.includePlots == nil then
        settings.includePlots = false
    elseif settings.preferPlots == nil then
        settings.preferPlots = false
    end

    local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
    if toonError then
        createFiles('toons')
    elseif loadToons then
        alltoons = loadToons()
    end

    local loadIgnore, ignoreError = loadfile(mq.configDir..'/'..ignorePath)
    if ignoreError then
        createFiles('ignore')
    elseif loadIgnore then
        ignore = loadIgnore()
    end

    local loadArt, artError = loadfile(mq.configDir..'/'..artisanPath)
    if artError then
        createFiles('artisan')
    elseif loadArt then
        artisan = loadArt()
    end
end
loadFiles()


print('\at[TsC]\ao Welcome to TS Consolidator v'..version)

settings.driver = me
mq.pickle(settingPath, settings)
local status = 'Idle'

---------------------Helper functions-------------------------

--Save settings and files
local function save(who)
    if who == '' or who == nil then
        mq.pickle(ignorePath, ignore)
    elseif who ~= nil then
        mq.pickle('TSC/ignore_'..who..'.lua', pignoreList)
    end
    mq.pickle(toonPath, alltoons)
    mq.pickle(settingPath, settings)
    mq.pickle(artisanPath, artisan)
    mq.pickle(matchesPath, matches)
    mq.pickle(consolPath, consol)
end

local function saveToons()
    mq.pickle(toonPath, alltoons)
end

--Reindex tables to avoid nil values
local function reIndex(mytable)
    local reindex = {}
    for _,v in pairs (mytable) do
        table.insert(reindex, v)
    end
    if mytable == ignore then
        ignore = reindex
    elseif mytable == pignoreList then
        pignoreList = reindex
    elseif mytable == settings['mules'] then
        settings['mules'] = reindex
    elseif mytable == artisan then
        artisan = reindex
    elseif mytable == alltoons then
        alltoons = reindex
        saveToons()
        return
    end
    save()
end

--Turn active toon into single-entry table for solo routines
local function checkName(name)
    local single = {[1]={}}
    for _,toon in pairs(alltoons) do
        if toon.name == name then
            single[1] = toon
        end
    end
    return single
end


---------------------------Toon management---------------------------

--Check which toons are in-zone and populate toons table (included in main loop)
local function checkToons()
    local tmptableOn = {}
    for index,toon in pairs(alltoons) do
        if mq.TLO.Spawn('PC ='..toon.name)() == nil then
            alltoons[index].inzone = false
        else
            alltoons[index].inzone = true
            table.insert(tmptableOn, toon)
        end
    end
    table.sort(alltoons, utils.sortToons)
    reIndex(alltoons)
    toons = tmptableOn --Toons online and in zone
end

--Check mule inventories (included in main loop)
local function checkMules()
    for index,mule in pairs(settings.mules) do
        if mq.TLO.Spawn('PC ='..mule.name)() then
            settings['mules'][index]['inzone'] = true
        else
            settings['mules'][index]['inzone'] = false
        end
    end
end

--Set observers on mules
local function setObservers()
    for _,v in pairs(settings['mules']) do
        mq.cmdf('/dobserve %s -q Me.FreeInventory', v.name)
    end
    for _,v in pairs(toons) do
        mq.cmdf('/dobserve %s -q Me.FreeInventory', v.name)
    end
end
setObservers()

--Populate combo box for adding toons
local toonComboOptions = {}
local function getToonPeers()
    toonComboOptions = {}
    for _,name in pairs(peerTable) do
        local skip = false
        for index,toon in pairs(alltoons) do
            if toon.name == name then
                skip = true
            end
        end
        if skip == false then
            table.insert(toonComboOptions, name)
        end
    end
    --Remove option from combo if they're added to toons
    for k,name in pairs(toonComboOptions) do
        for index,toon in pairs(alltoons) do
            if name == toon.name then
                toonComboOptions[k] = nil
            end
        end
    end
end

--Populate combo box for adding mules
local muleComboOptions = {}
local function getMulePeers()
    muleComboOptions = {}
    for _,name in pairs(peerTable) do
        local skip = false
        for index,mule in pairs(settings['mules']) do
            if mule.name == name then
                skip = true
            end
        end
        if skip == false then
            table.insert(muleComboOptions, name)
        end
    end
    --Remove option from combo if they're added to mules
    for k,name in pairs(muleComboOptions) do
        for index,mule in pairs(settings['mules']) do
            if name == mule.name then
                muleComboOptions[k] = nil
            end
        end
    end
end

--Populate combo box for give drop down
local giveComboOptions = {}
local function getGivePeers()
    giveComboOptions = {}
    for _,name in pairs(peerTable) do
        local skip = false
        if not mq.TLO.Spawn('PC ='..name)() then
            skip = true
        end
        if skip == false then
            table.insert(giveComboOptions, name)
        end
    end
end

--Constantly check peers (included in main loop)
local peers
local function getPeers()
    if peers ~= mq.TLO.DanNet.Peers() then --Something changed
        peers = mq.TLO.DanNet.Peers()
        for peer in peers:gmatch("([^|]+)|") do
            peer = (peer:gsub("^%l", string.upper))
            local skip = false
            for _,v in pairs(peerTable) do
                if v == peer then
                    skip = true
                end
            end
            if skip == false then
                table.insert(peerTable, peer)
            end
        end
        getToonPeers()
        getMulePeers()
        getGivePeers()
        setObservers()
    end
end

--Waiting function
local function whileWaiting()
    checkToons()
    checkMules()
    getPeers()
    mq.delay(500)
end


--Window states
---------------------------------------
local whosIgnore = ''
local openArt, drawArt = false, false
local openList, drawList = false, false
local openMatch, drawMatch = false, false
local openMove, drawMove = false, false
local openRest, drawRest = false, false







----------------------------------------

--Routine functions

----------------------------------------






---------Pause/unpause macros and plugins---------
local pauseTable = {}
local function saveStates(a, b)
    if not pauseTable[b] then
        pauseTable[b] = {
            macro = false,
            plugin = false
        }
    end
    if a == 'pausedmacro' then
        pauseTable[b].macro = true
    elseif a =='pausedplugin' then
        pauseTable[b].plugin = true
    end
end

local function pause(who)
    pauseTable = {}
    for _,toon in pairs(who) do
        if toon.name == me then
            mq.cmd('/lua run TSC/pause on')
        else
            mq.cmdf('/dex %s /lua run TSC/pause on', toon.name)
        end
    end
end

local function unpause()
    for k,v in pairs(pauseTable) do
        if k == me then
            if v.macro == true and v.plugin == true then
                mq.cmd('/lua run TSC/pause off both')
            elseif v.macro == true then
                mq.cmd('/lua run TSC/pause off macro')
            elseif v.plugin == true then
                mq.cmd('/lua run TSC/pause off plugin')
            end
        else
            if v.macro == true and v.plugin == true then
                mq.cmdf('/dex %s /lua run TSC/pause off both', k)
            elseif v.macro == true then
                mq.cmdf('/dex %s /lua run TSC/pause off macro', k)
            elseif v.plugin == true then
                mq.cmdf('/dex %s /lua run TSC/pause off plugin', k)
            end
        end
    end
end

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
local function scan(who, mode, what)
    --who: toon table, mode: 1 is normal 2 is givemode, what: 41 is mats 19 is collectibles
    print('\at[TsC]\ao------\agStart\ao scanning routine.')

    if mode == nil then mode = 1 end
    if what == nil then what = 41 end

    local length = utils.listSize(who)
    if length > 0 then
        status = 'Scanning'

        for _,toon in pairs(who) do
            if toon.name == me then
                mq.cmdf('/lua run TSC/scan %s %s', mode, what)
            else
                mq.cmdf('/dex %s /squelch /lua run TSC/scan %s %s', toon.name, mode, what)
            end
        end

        scanCount = 0
        while scanCount < length do
            whileWaiting()
        end
        scanCount = 0

    end
    print('\at[TsC]\ao------\arDone\ao scanning routine.')
    mq.delay(2000)
end


--------Find matches, determine trades, identify traders--------
local traders
local bankers
local movers --Depot and bank to depot
local dumpers
local ploters
local waitingMatches
local matchCount = 0
local function stopWaitingMatching() waitingMatches = false matchCount = matchCount + 1 end
local function match(who, all)
    status = 'Finding matches'
    if who then
        if all == 'all' then
            for _,toon in pairs(who) do
                if toon.name == me then
                    mq.cmd('/lua run TSC/selfmatch.lua multiple')
                else
                    mq.cmdf('/dex %s /lua run TSC/selfmatch multiple', toon.name)
                end
            end
        elseif who == me then
            mq.cmd('/lua run TSC/selfmatch.lua')
        else
            mq.cmdf('/dex %s /lua run TSC/selfmatch', who)
        end
    else
        mq.cmd('/lua run TSC/match.lua')
    end

    if all == 'all' then
        local length = utils.listSize(who)
        matchCount = 0
        while matchCount < length do
            whileWaiting()
        end
        matchCount = 0
    else
        waitingMatches = true
        while waitingMatches do
            whileWaiting()
        end
    end

    mq.delay(2000)

    local matchlist, matchError = loadfile(mq.configDir..'/'..matchesPath)
    if matchError then
        print('\at[TsC]\ao Error loading matches.lua')
    elseif matchlist then
        matches = matchlist()
    end

    if all == 'all' then
        local allConsol = {}
        local allitems = {}
        for _,toon in pairs(who) do
            if mq.TLO.Spawn('PC ='..toon.name)() then --Only load results of toons in-zone
                local path = 'TSC/tmp/consolidate_'..toon.name..'.lua'
                local table, error = loadfile(mq.configDir..'/'..path)
                if error then
                    print('error')
                elseif table then
                    --allitems[toon.name] = {}
                    local tmpConsol = table()
                    allConsol[toon.name] = tmpConsol[toon.name]
                end
            end
        end
        mq.pickle(consolPath, allConsol)
    end

    local consollist, consolError = loadfile(mq.configDir..'/'..consolPath)
    if consolError then
        print('\at[TsC]\ao Error loading consolidate.lua')
    elseif consollist then
        consol = consollist()
    end

    traders = {}
    bankers = {}
    movers = {}
    dumpers = {}
    ploters = {}
    for player,list in pairs(matches) do
        if utils.listSize(list) > 0 then
            local entry = {['name'] = player}
            table.insert(traders, entry)
        end
    end

    for player,list in pairs(consol) do
        local bank = false
        local depot = false
        local dump = false
        for _,dest in pairs(list) do
            if dest == "Bank" or dest == "BankRestack" then bank = true end
            if dest == "Depot" then depot = true end
            if dest == "Leftovers" then dump = true end
        end
        local entry = {['name'] = player}
        if bank == true then table.insert(bankers, entry) end
        if depot == true then table.insert(movers, entry) end
        if dump == true then table.insert(dumpers, entry) end
        if list['Real Estate'] == true then table.insert(ploters, entry) end --Add to ploters whether or not plot is destination
    end

    openMatch = true
    status = 'Awaiting user input'
end


--------Grab items from the bank to give to others--------
local grabCount
local function stopWaitingGrabbing() grabCount = grabCount + 1 end
local function grab(who, what)
    status = 'Grabbing'

    print('\at[TsC]\ao------\agStart\ao grabbing routine.')

    if what == nil then what = 41 end

    local length = utils.listSize(who)
    if length > 0 then

        for _,toon in pairs(who) do
            if toon.name == me then
                mq.cmdf('/squelch /lua run TSC/grab %s', what)
            else
                mq.cmdf('/squelch /dex %s /lua run TSC/grab %s', toon.name, what)
            end
        end

        grabCount = 0
        while grabCount < length do
            whileWaiting()
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
    status = 'Trading'

    print('\at[TsC]\ao------\agStart\ao trading routine.')

    local length = utils.listSize(who)
    if length > 0 then

        for _,toon in pairs(who) do
            if matches[toon.name] then
                waitingTrading = true

                if toon.name == me then
                    mq.cmd('/squelch /lua run TSC/trade')
                else
                    mq.cmdf('/squelch /dex %s /lua run TSC/trade', toon.name)
                end

                print('\at[TsC]\ao Telling \ar'..toon.name..' \ao to start trading routine.')

                while waitingTrading do
                    whileWaiting()
                end
            end
        end

    end
    print('\at[TsC]\ao------\arDone\ao trading routine.')
    mq.delay(2000)
end


--------Real estate routine--------
local realCount
local function stopwaitingPlots() realCount = realCount + 1 end
local function realEstate(who, what)
    status = 'Real estate'

    print('\at[TsC]\ao------\agStart\ao real estate routine.')

    if what == nil then what = 41 end

    local length = utils.listSize(who)

    for _,toon in pairs(who) do
        if toon.name == me then
            mq.cmdf('/squelch /lua run TSC/plots.lua %s', what)
        else
            mq.cmdf('/squelch /dex %s /lua run TSC/plots %s', toon.name, what)
        end
    end

    realCount = 0
    while realCount < length do
        mq.doevents()
        whileWaiting()
    end
    realCount = 0

    print('\at[TsC]\ao------\arDone\ao real estate routine.')
    mq.delay(2000)
end


--------Banking routine--------
local bankCount
local function stopwaitingBanking() bankCount = bankCount + 1 end
local function bank(who)
    status = 'Banking'

    print('\at[TsC]\ao------\agStart\ao banking routine.')

    local length = utils.listSize(who)

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
        whileWaiting()
    end
    bankCount = 0

    print('\at[TsC]\ao------\arDone\ao banking routine.')
    mq.delay(2000)
end


--------Depot routine. This needs to be done one at a time.--------
local depotWarning

local waitingDepot
local function stopWaitingDepot() waitingDepot = false end
local function depot(who)
    status = 'Depot'

    print('\at[TsC]\ao------\agStart\ao depot routine.')

    local length = utils.listSize(who)
    if length > 0 then --Only show depot warning if movers > 0

        depotWarning = true
        status = "Awaiting user input"
        while depotWarning == true do
            mq.delay(1000)
            if status == 'Idle' then
                print('\at[TsC]\ay Depot routine cancelled.')
                return
            end
        end

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
                whileWaiting()
            end
        end

    end

    print('\at[TsC]\ao------\arDone\ao depot routine.')
    mq.delay(2000)
end


--------Leftover routine. This needs to be done one at a time.--------
local waitingRest
local function stopwaitingRest() waitingRest = false end
local function rest(who)

    if utils.listSize(who) > 0 then
        openRest = true
        status = 'Awaiting user input'
        while openRest == true do
            mq.delay(100)
            if status == 'Idle' then
                print('\at[TsC]\ay Skipping leftover routine.')
                return
            end
        end
    end

    status = 'Leftovers'
    print('\at[TsC]\ao------\agStart\ao leftover routine.')

    --Should I show depot warning?
    local show = false
    for _,toon in pairs(who) do
        for _,player in pairs(toons) do
            if player.name == toon.name then
                if string.match(player.leftovers, "Depot") then --At least 1 toon has depot in their leftovers routine
                    show = true
                end
            end
        end
    end
    if show == true then
        depotWarning = true
        while depotWarning == true do
            status = "Awaiting user input"
            mq.delay(1000)
            if status == 'Idle' then
                print('\at[TsC]\ay Leftover routine cancelled.')
                return
            end
        end
    end


    for _,toon in pairs(who) do
        if toon.leftovers ~= 'Off' then
            waitingRest = true
            if toon.name == me then
                mq.cmd('/squelch /lua run TSC/leftover')
            else
                mq.cmdf('/squelch /dex %s /lua run TSC/leftover', toon.name)
            end

            print('\at[TsC]\ao Telling \ar'..toon.name..' \ao to start leftover routine.')
            if show == true then
                print('\at[TsC]\ay Your window focus may change to \ar'..toon.name..'\'s \ayEQ window.')
            end

            while waitingRest do
                whileWaiting()
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

    if what == 'Collectibles' then scan(who,1,19) else scan(who) end

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
    print('\at[TsC]\ao TOTAL: You freed up \ag'..totalSavings..' \aoslots across \ay'..utils.listSize(who)..'\ao toons.')
end







-------------------------






-------------------------
---Function parameters---
local itemMode = 'Tradeskill'
local activeToon = ''
local giveTarget = ''
local giveBank = false
local giveDepot = false
local function clearParameters()
    activeToon = ''
    giveTarget = ''
    giveBank = false
    giveDepot = false
end


----------------------------
--------Main routine--------
local continue
local skipTrading
local function go(what)
    matches = {}
    consol = {}
    save()
    --Pre checks
    if status ~= 'Idle' then return end
    if utils.checkBanker() == false then return end
    if utils.listSize(toons) < 1 then print('\at[TsC]\ao Add some toons first.') return end

    --Pause plugins
    pause(toons)

    if settings.stats == true then
        createStats(toons)
    end

    --Scan
    if what == 'Collectibles' then scan(toons,1,19) else scan(toons) end

    --Determine moves and trades
    match()

    --Wait for confirmation
    continue = false
    skipTrading = false
    while continue == false do
        whileWaiting()
    end

    if skipTrading == false then
        if what == 'Collectibles' then grab(traders, 19) else grab(traders) end

        --Execute trades
        trade(traders)

        --Handle real-estate
        if settings.includePlots == true then
            if what == 'Collectibles' then realEstate(ploters, 19) else realEstate(ploters) end
        end

        --Execute banking
        bank(bankers)

        --Execute depot
        depot(movers)

    else
        print('\at[TsC]\ay Skipping consolidation.')
    end

    --Handle leftovers
    rest(dumpers)

    --Calculate stats
    if settings.stats == true then calcStats(toons, what) end

    print('\at[TsC]\ao EVERYTHING DONE')
    unpause()
    status = 'Idle'
end


--------------------------------
-----------Tidy up--------------
local function self(who, what)
    matches = {}
    consol = {}
    save()
    if status ~= 'Idle' then return end
    if utils.checkBanker() == false then return end

    local all = false
    if who == 'all' then
        all = true
    end

    --Turn into single-entry table
    if all == true then
        who = toons
    else
        who = checkName(who)
    end

    pause(who)

    createStats(who)

    --Scan
    if what == 'Collectibles' then scan(who,1,19) else scan(who) end

    --Determine moves and trades
    if all == true then
        match(who, 'all')
    else
        match(who[1].name)
    end

    --Wait for bank confirmation
    continue = false
    skipTrading = false
    while continue == false do
        whileWaiting()
    end

    if skipTrading == false then

        --Handle real-estate
        if settings.includePlots == true then
            if what == 'Collectibles' then realEstate(ploters, 19) else realEstate(ploters) end
        end

        --Execute banking
        bank(bankers)

        --Execute depot
        depot(movers)

    else
        print('\at[TsC]\ay Skipping consolidation.')
    end

    --Handle leftovers
    rest(dumpers)

    --Calculate stats
    if settings.stats == true then calcStats(who, what) end

    if all == true then
        print('\at[TsC] \arAll toon\'s \ao self-consolidation is done.')
    else
        print('\at[TsC] \ar'..who[1].name..'\'s \ao self-consolidation is done.')
    end
    unpause()

    --Reset parameters for GUI
    clearParameters()
    status = 'Idle'
end


----------------------------
--------Give routine--------
local function give(who, receiver, what, givebank, givedepot)
    matches = {}
    consol = {}
    save()
    if status ~= 'Idle' then return end
    if givebank == true or givedepot == true then
        if not utils.checkBanker() then return end
    end

    --Ensure receiver is in-zone
    receiver = (receiver:gsub("^%l", string.upper))
    if not mq.TLO.Spawn('PC ='..receiver)() then
        print('\at[TsC]\ao Target not found in zone. Stopping.')
        return
    end

    local pausers = {
        [1] = {['name'] = who},
        [2] = {['name'] = receiver}
    }

    --Turn into single-entry table
    who = checkName(who)

    pause(pausers)

    --Scan
    if what == 'Collectibles' then scan(who,1,19) else scan(who) end



    print('\at[TsC]\ao------\agStart\ao giving routine.')
    

    status = 'Giving'

    local player = who[1].name
    if player == me then
        mq.cmdf('/lua run TSC/give %s %s %s %s', receiver, what, givebank, givedepot)
    else
        mq.cmdf('/dex %s /lua run TSC/give %s %s %s %s', player, receiver, what, givebank, givedepot)
    end

    --Reset parameters for GUI
    clearParameters()
end

local function doneGiving()
    unpause()
    print('\at[TsC]\ao------\arDone\ao giving routine.')
    status = 'Idle'
end








---------------------
--------Binds--------
local function binds(a, b)
    if a == 'donescanning' then
        stopWaitingScanning()
    elseif a == 'donematching' then
        stopWaitingMatching()
    elseif a == 'donegrabbing' then
        stopWaitingGrabbing()
    elseif a == 'donetrading' then
        stopWaitingTrading()
    elseif a == 'doneplots' then
        stopwaitingPlots()
    elseif a == 'donebanking' then
        stopwaitingBanking()
    elseif a == 'donedepot' then
        stopWaitingDepot()
    elseif a == 'donerest' then
        stopwaitingRest()
    elseif a == 'donegiving' then
        doneGiving()
    elseif a == 'pausedmacro' then
        saveStates(a, b)
    elseif a == 'pausedplugin' then
        saveStates(a, b)
    end
end
mq.bind('/tsc', binds)






-----------------------
-----------------------
---------GUI-----------
-----------------------






----ANONYMIZOR----
local function fname(name)
    return name
end

---Function activators for main loop
local goNow = false
local selfNow = false
local giveNow = false


--Add toons and mules
local newToon = ''
local function addToon(n)
    local entry = {
        name = n,
        mode = 'Default',
        leftovers = 'Off',
        inzone = false
    }
    table.insert(alltoons, entry)
    reIndex(alltoons)
    getToonPeers() --To remove option from combo
    save()
    local pignore = {}
    mq.pickle(mq.configDir..'/TSC/ignore_'..n..'.lua', pignore)
    newToon = ''
end
local newMule = ''
local function addMule(n)
    local skip = false
    for _,mule in pairs(settings['mules']) do
        if mule.name == n then
            skip = true
        end
    end
    if skip == false then
        local entry = {
            name = n,
            inzone = false
        }
        table.insert(settings['mules'], entry)
        getMulePeers() --To remove option from combo
        setObservers()
        save()
    end
    newMule = ''
end


--Add all toons currently in-zone
local function addAllInZone()
    for _,name in pairs(peerTable) do
        local skip = false
        for index,toon in pairs(alltoons) do
            if toon.name == name then
                skip = true
            end
        end
        if skip == false and mq.TLO.Spawn('PC ='..name) then
            local entry = {
                name = name,
                inzone = true,
                mode = 'Default',
                leftovers = 'Off'
            }
            table.insert(alltoons, entry)
        end
    end
    getToonPeers() --To remove option from combo
    save()
end


--Change ordering of mules
local function moveUp(n)
    if n == 1 then return end
    local mule = settings.mules[n].name
    local newindex
    for k,v in pairs (settings.mules) do
        if v.name == mule then
            newindex = k-1
            break
        end
    end
    local oldmule = settings.mules[newindex].name
    settings.mules[n].name = oldmule
    settings.mules[newindex].name = mule
end
local function moveDown(n)
    local length = 0
    local mule = settings.mules[n].name
    local newindex
    for k,v in pairs (settings.mules) do
        length = length + 1
        if v.name == mule then
            newindex = k+1
        end
    end
    if n == length then return end
    local oldmule = settings.mules[newindex].name
    settings.mules[n].name = oldmule
    settings.mules[newindex].name = mule
end


--If a toon is removed, make sure they are no longer artisan or tiebreaker
local function removeTieArt(name)
    if name == settings.artisan then settings.artisan = 'Not set' end
    if name == settings.tiebreaker then settings.tiebreaker = 'Not set' end
end


--Add item to ignore/artisan list from cursor
local function addIgnore(list)
    local cursor = mq.TLO.Cursor
    local name = mq.TLO.Cursor.Name()
    if name == nil then
        print('\at[TsC]\ao Place an item on your cursor.')
        return
    end
    if cursor.Tradeskills() == false and cursor.Collectible() == false then
        print('\at[TsC]\ao You can only add tradeskill items and collectibles.')
        return
    end
    local mytable
    if list == 'ignore' then mytable = ignore elseif list == 'artisan' then mytable = artisan elseif list == 'personal' then mytable = pignoreList end

    for _,v in pairs(mytable) do
        if v == name then
            print('\at[TsC]\ao This item is already in your '..list..' list.')
            return
        end
    end
    table.insert(mytable, name)
    if list == 'personal' then
        print('\at[TsC]\ao Added \ag'..name..' \ao to \ar'..whosIgnore..'\'s\ao personal ignore list.')
    else
        print('\at[TsC]\ao Added \ag'..name..' \ao to your '..list..' list.')
    end

    if list == 'ignore' then ignore = mytable elseif list == 'artisan' then artisan = mytable elseif list == 'personal' then pignoreList = mytable end
    save(whosIgnore)
end


--Bulk add ingore/artisan via copy pasted list
local ignoreBulkList = 'Gnomish Apples\nDwarven Peaches\nElven Carrots\n...'
local function bulkAdd(list)
    local mytable
    if list == 'ignore' then mytable = ignore elseif list == 'artisan' then mytable = artisan elseif list == 'personal' then mytable = pignoreList end
    for line in ignoreBulkList:gmatch("[^\n]+") do
        local skip = false
        for _,v in pairs(mytable) do
            if v == line then
                skip = true
            end
        end
        if skip == false then
            table.insert(mytable, line)
            if list == 'personal' then
                print('\at[TsC]\ao Added \ag'..line..' \ao to \ar'..whosIgnore..'\'s\ao personal ignore list.')
            else
                print('\at[TsC]\ao Added \ag'..line..' \ao to your '..list..' list.')
            end
        end
    end
    if list == 'ignore' then ignore = mytable elseif list == 'artisan' then artisan = mytable elseif list == 'personal' then pignoreList = mytable end
    save(whosIgnore)
    ignoreBulkList = ''
end


--Import ignore/artisan from file
local function importIgnore(list)
    local file
    file = io.open(mq.configDir..'/TSC/'..filedialog.get_filename())
    if file == nil then
        print('\at[TsC]\ao Couldn\'t find '..list..'.txt')
        return
    end
    local mytable
    if list == 'ignore' then mytable = ignore elseif list == 'artisan' then mytable = artisan elseif list == 'personal' then mytable = pignoreList end
    local lines = file:lines()
    for line in lines do
        local skip = false
        for _,v in pairs(mytable) do
            if line == v then skip = true end
        end
        if skip == false then
            table.insert(mytable, line)
            if list == 'personal' then
                print('\at[TsC]\ao Added \ag'..line..' \ao to \ar'..whosIgnore..'\'s\ao personal ignore list.')
            else
                print('\at[TsC]\ao Added \ag'..line..' \ao to your '..list..' list.')
            end
        end
    end
    if list == 'ignore' then ignore = mytable elseif list == 'artisan' then artisan = mytable elseif list == 'personal' then pignoreList = mytable end
    file:close()
    print('\at[TsC]\ao Done importing.')
    save(whosIgnore)
end


--Alphabetically sort ignore/artisan list table
local current_sort_specs = nil
local function sortBName(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0
        if a == nil or b == nil then return end
        a = a:lower()
        b = b:lower()
        if a < b then
            delta = -1
        elseif b < a then
            delta = 1
        else
            delta = 0
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end
    return a < b
end


--Add items to ignore lists from matches window
local function ignoreMatch(name, list)
    if list == 'global' then
        local skip = false
        for _,item in pairs(ignore) do
            if item == name then
                skip = true
            end
        end
        if skip == false then
            whosIgnore = ''
            openList = true
            table.insert(ignore, name)
            print('\at[TsC]\ao \ag'..name..' \aohas been added to your ignore list.')
            save()
        end
    else
        local List = loadfile(mq.configDir..'/TSC/ignore_'..list..'.lua')
        if List then
            pignoreList = List()
        end
        local skip = false
        for _,item in pairs(pignoreList) do
            if item == name then
                skip = true
            end
        end
        if skip == false then
            whosIgnore = list
            openList = true
            table.insert(pignoreList, name)
            print('\at[TsC]\ao \ag'..name..' \aohas been added to \ar'..list..'\'s \aopersonal ignore list.')
            save(list)
        end
    end
end


--------Draw leftovers window--------
local function restWindow()
    if openRest then
        openRest, drawRest = ImGui.Begin('Leftovers list', openRest)
        ImGui.SetWindowSize(600,850,ImGuiCond.Once)
        if drawRest then
            ImGui.TextColored(1,1,0,1,'Review leftover items to store.')
            ImGui.TextWrapped('These are leftover items still in your toons\' inventories that will be now stored away according to their Leftovers setting. Review each item and then click continue to store them.')

            ImGui.PushStyleColor(ImGuiCol.Button,0,1,0,.5)
                if ImGui.Button('Continue') then openRest = false end
            ImGui.PopStyleColor()
            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button,1,0,0,.5)
                if ImGui.Button('Cancel') then status = 'Idle' openRest = false end
            ImGui.PopStyleColor()

            --Start leftover tables
            local flags = ImGuiTableFlags.RowBg
            local row_bg_type = 1
            local row_bg_target = 1
            for _,toon in pairs(toons) do
                if activeToon == "" or toon.name == activeToon then

                    local left = false
                    for _,player in pairs(toons) do
                        if player.name == toon.name then
                            if player.leftovers ~= 'Off' then
                                left = true
                            end
                        end
                    end
                    
                    ImGui.TextColored(1,0,0,1, fname(toon.name))
                    if ImGui.BeginTable('##'..toon.name, 4, flags) then
                        ImGui.TableSetupColumn('Action', ImGuiTableColumnFlags.WidthStretch)
                        ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 100)
                        ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableHeadersRow()
                        ImGui.TableSetBgColor(1, ImVec4(1, 1, 0, .4))
                        if consol[toon.name] then

                            --Alphabetize
                            local sortedKeys = {}
                            for item,_ in pairs(consol[toon.name]) do
                                table.insert(sortedKeys, item)
                            end
                            table.sort(sortedKeys)

                            for _,item in pairs(sortedKeys) do
                                if consol[toon.name][item] == "Leftovers" or consol[toon.name][item] == "skipped" or consol[toon.name][item] == "ignored" or consol[toon.name][item] == "pignored" then

                                    local function update(arg)
                                        if consol[toon.name][item] ~= 'skipped' and consol[toon.name][item] ~= 'ignored' and consol[toon.name][item] ~= 'pignored'  then
                                            if arg == 'skip' then
                                                consol[toon.name][item] = 'skipped'
                                                save()
                                            elseif arg == 'ignore' then
                                                ignoreMatch(item, 'global')
                                                consol[toon.name][item] = 'ignored'
                                            elseif arg == 'pignore' then
                                                ignoreMatch(item, toon.name)
                                                consol[toon.name][item] = 'pignored'
                                            end
                                            save()
                                        end
                                    end

                                    ImGui.TableNextRow()
                                    ImGui.TableNextColumn()
                                    if row_bg_type == 1 then
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.8, 0.8, 0.3, 0.35))
                                    else
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.9, 0.9, 0.2, 0.35))
                                    end

                                    if consol[toon.name][item] == 'skipped' then
                                        ImGui.TextDisabled(item..'will be skipped once')
                                    elseif consol[toon.name][item] == 'ignored' then
                                        ImGui.TextDisabled(item..'is now globally ignored')
                                    elseif consol[toon.name][item] == 'pignored' then
                                        ImGui.TextDisabled(item..'is now personally ignored')
                                    elseif left == false then
                                        ImGui.TextDisabled(item..' will not be stored (Leftovers off)')
                                    else
                                        ImGui.Text(item..' will be stored')
                                    end

                                    ImGui.TableNextColumn()
                                    if ImGui.Button('\xef\x81\x9e Skip##'..toon.name..item) then
                                        update('skip')
                                    end
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Skip this item once.') end

                                    ImGui.TableNextColumn()
                                    ImGui.PushStyleColor(ImGuiCol.Button,1,1,0,.5)
                                    if ImGui.Button('\xef\x82\xac Ignore##'..toon.name..item) then
                                        update('ignore')
                                    end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to your global ingore file.') end

                                    ImGui.TableNextColumn()
                                    ImGui.PushStyleColor(ImGuiCol.Button, 0,1,1,.4)
                                    if ImGui.Button('\xef\x80\x87 Ignore##'..toon.name..item) then
                                        update('pignore')
                                    end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to this toon\'s personal ingore file.') end
                                end
                            end
                        end
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



--------Draw matches window--------
local function matchWindow()
    if openMatch then
        openMatch, drawMatch = ImGui.Begin('Confirm trades and moves', openMatch)
        ImGui.SetWindowSize(600,850,ImGuiCond.Once)
        if drawMatch then

            ImGui.TextColored(1,1,0,1,'Review items to be traded and moved')
            ImGui.TextWrapped('These are items that exist on more than one toon or in more than one location. Review each item and then click continue to begin consolidation.')

            ImGui.PushStyleColor(ImGuiCol.Button,0,1,0,.5)
                if ImGui.Button('Continue') then continue = true openMatch = false end
            ImGui.PopStyleColor()

            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button,1,0,0,.5)
                if ImGui.Button('Cancel') then skipTrading = true continue = true openMatch = false end
            ImGui.PopStyleColor()

            --Start match tables
            local flags = ImGuiTableFlags.RowBg
            local row_bg_type = 1
            local row_bg_target = 1
            for _,toon in pairs(toons) do
                if activeToon == "" or toon.name == activeToon then
                    ImGui.TextColored(1,0,0,1, fname(toon.name))
                    
                    if ImGui.BeginTable('##'..toon.name, 4, flags) then
                        ImGui.TableSetupColumn('Trades', ImGuiTableColumnFlags.WidthStretch)
                        ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 80)
                        ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableHeadersRow()
                        ImGui.TableSetBgColor(1, ImVec4(1, 0, 0, .4))
                        if matches[toon.name] then
                            
                            --Alphabetize
                            local sortedKeys = {}
                            for item,_ in pairs(matches[toon.name]) do
                                table.insert(sortedKeys, item)
                            end
                            table.sort(sortedKeys)

                            for _,item in pairs(sortedKeys) do

                                local function update(arg)
                                    if matches[toon.name][item] ~= 'skipped' and matches[toon.name][item] ~= 'ignored' and matches[toon.name][item] ~= 'pignored'  then
                                        if arg == 'skip' then
                                            matches[toon.name][item] = 'skipped'
                                        elseif arg == 'ignore' then
                                            ignoreMatch(item, 'global')
                                            for player,_ in pairs(matches) do
                                                if matches[player][item] then
                                                    matches[player][item] = 'ignored'
                                                end
                                            end
                                            for player,_ in pairs(consol) do
                                                if consol[player][item] then
                                                    consol[player][item] = 'ignored'
                                                    save()
                                                end
                                            end
                                        elseif arg == 'pignore' then
                                            ignoreMatch(item, toon.name)
                                            matches[toon.name][item] = 'pignored'
                                        end
                                        save()
                                    end
                                end

                                ImGui.TableNextRow()
                                ImGui.TableNextColumn()
                                if row_bg_type == 1 then
                                    ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.8, 0.3, 0.3, 0.35))
                                else
                                    ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.9, 0.2, 0.2, 0.35))
                                end

                                if matches[toon.name][item] == 'ignored' then
                                    ImGui.TextDisabled(item..' is now globally ignored')
                                elseif matches[toon.name][item] == 'pignored' then
                                    ImGui.TextDisabled(item..' is now personally ignored')
                                elseif matches[toon.name][item] == 'skipped' then
                                    ImGui.TextDisabled(item..' will be skipped once')
                                else
                                    ImGui.Text(item..' will go to '..fname(matches[toon.name][item]))
                                end

                                ImGui.TableNextColumn()
                                ImGui.PushStyleColor(ImGuiCol.Button,.16,.29,.48,1)
                                    if ImGui.Button('\xef\x81\x9e Skip##'..toon.name..item) then
                                        update('skip')
                                    end
                                ImGui.PopStyleColor()
                                if ImGui.IsItemHovered() then ImGui.SetTooltip('Skip trading this item once.') end

                                ImGui.TableNextColumn()

                                ImGui.PushStyleColor(ImGuiCol.Button,.4,.4,0,1)
                                    if ImGui.Button('\xef\x82\xac Ignore##'..toon.name..item) then
                                        update('ignore')
                                    end
                                ImGui.PopStyleColor()
                                if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to your global ingore file.') end

                                ImGui.TableNextColumn()

                                ImGui.PushStyleColor(ImGuiCol.Button, 0,.4,.4,1)
                                    if ImGui.Button('\xef\x80\x87 Ignore##'..toon.name..item) then
                                        update('pignore')
                                    end
                                ImGui.PopStyleColor()
                                if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to this toon\'s personal ingore file.') end
                            end
                        end
                    ImGui.EndTable()
                    
                    end

                    if ImGui.BeginTable('###'..toon.name, 4, flags) then
                        ImGui.TableSetupColumn('Moves', ImGuiTableColumnFlags.WidthStretch)
                        ImGui.TableSetupColumn('Skip', ImGuiTableColumnFlags.WidthFixed, 80)
                        ImGui.TableSetupColumn('Global', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableSetupColumn('Personal', ImGuiTableColumnFlags.WidthFixed, 90)
                        ImGui.TableHeadersRow()
                        ImGui.TableSetBgColor(1, ImVec4(0, 0, 1, .6))
                        if consol[toon.name] then

                            --Alphabetize
                            local sortedKeys = {}
                            for item,_ in pairs(consol[toon.name]) do
                                table.insert(sortedKeys, item)
                            end
                            table.sort(sortedKeys)

                            for _,item in pairs(sortedKeys) do
                                if consol[toon.name][item] ~= "Leftovers" and consol[toon.name][item] ~= true then
                                    local function update(arg)
                                        if consol[toon.name][item] ~= 'skipped' and consol[toon.name][item] ~= 'ignored' and consol[toon.name][item] ~= 'pignored'  then
                                            if arg == 'skip' then
                                                consol[toon.name][item] = 'skipped'
                                            elseif arg == 'ignore' then
                                                ignoreMatch(item, 'global')
                                                for player,_ in pairs(consol) do
                                                    if consol[player][item] then
                                                        consol[player][item] = 'ignored'
                                                    end
                                                end
                                                ignoreMatch(item, 'global')
                                            for _,player in pairs(toons) do
                                                if matches[player.name][item] then
                                                    matches[player.name][item] = 'ignored'
                                                end
                                            end
                                            elseif arg == 'pignore' then
                                                ignoreMatch(item, toon.name)
                                                consol[toon.name][item] = 'pignored'
                                            end
                                            save()
                                        end
                                    end
                                    
                                    ImGui.TableNextRow()
                                    ImGui.TableNextColumn()
                                    if row_bg_type == 1 then
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.3, 0.3, 0.8, 0.35))
                                    else
                                        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + row_bg_target, ImVec4(0.2, 0.2, 0.9, 0.35))
                                    end
                                    if consol[toon.name][item] == 'ignored' then
                                        ImGui.TextDisabled(item..' is now globally ignored')
                                    elseif consol[toon.name][item] == 'pignored' then
                                        ImGui.TextDisabled(item..' is now personally ignored')
                                    elseif consol[toon.name][item] == 'skipped' then
                                        ImGui.TextDisabled(item..' will be skipped once')
                                    elseif consol[toon.name][item] == "BankRestack" then
                                        ImGui.Text(item..' needs to be restacked in the bank')
                                    else
                                        ImGui.Text(item..' will go to '..consol[toon.name][item])
                                    end

                                    ImGui.TableNextColumn()
                                    ImGui.PushStyleColor(ImGuiCol.Button,.16,.29,.48,1)
                                        if ImGui.Button('\xef\x81\x9e Skip##'..toon.name..item) then
                                            update('skip')
                                        end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Skip this item once.') end

                                    ImGui.TableNextColumn()

                                    ImGui.PushStyleColor(ImGuiCol.Button,.4,.4,0,1)
                                        if ImGui.Button('\xef\x82\xac Ignore##'..toon.name..item) then
                                            update('ignore')
                                        end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to your global ingore file.') end

                                    ImGui.TableNextColumn()

                                    ImGui.PushStyleColor(ImGuiCol.Button, 0,.4,.4,1)
                                        if ImGui.Button('\xef\x80\x87 Ignore##'..toon.name..item) then
                                            update('pignore')
                                        end
                                    ImGui.PopStyleColor()
                                    if ImGui.IsItemHovered() then ImGui.SetTooltip('Add this item to this toon\'s personal ingore file.') end
                                end
                            end
                        end
                    ImGui.EndTable()
                    ImGui.Separator()
                    ImGui.Text(" ")
                    end
                end
            end
        end
        ImGui.End()
    else
        openMatch = false
    end
end


--------Draw ignore list windows--------
local function ignoreWindow()
    local mytable
    if openList then
        local windowTitle

        if whosIgnore == '' then
            windowTitle = 'Global ignore List'
            mytable = ignore
        else
            windowTitle = fname(whosIgnore)..'\'s personal ignore list'
            mytable = pignoreList
        end

        openList, drawList = ImGui.Begin(windowTitle, openList)
        ImGui.SetWindowSize(300,450,ImGuiCond.Once)
        if drawList then

            if ImGui.Button('Add item') then
                if whosIgnore == '' then
                    addIgnore('ignore')
                else
                    addIgnore('personal')
                end
            end
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.addignoreitem) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            ImGui.SameLine()

            if ImGui.Button('Bulk add...') then ImGui.OpenPopup('Bulk add') end
            if ImGui.IsItemHovered() then ImGui.SetTooltip('Paste a list of items.') end

            if ImGui.BeginPopup('Bulk add') then
                ImGui.TextWrapped('Paste your list here. Each item should be on its own line. No commas or quotes. Exact spelling and capitalization matter.')
                ignoreBulkList = ImGui.InputTextMultiline('##bulkaddignore', ignoreBulkList, 300, 400,0)
                if ImGui.Button('Add to ignore list') then
                    if whosIgnore == '' then
                        bulkAdd('ignore')
                    else
                        bulkAdd('personal')
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
                        filedialog.draw_file_selector(mq.configDir..'/TSC', '.txt')
                    end
                    if not filedialog.is_file_selector_open() and filedialog.get_filename() ~= '' then
                        if whosIgnore == '' then
                            importIgnore('ignore')
                        else
                            importIgnore('personal')
                        end
                        filedialog.reset_filename()
                    end
                    ImGui.SameLine()
                    ImGui.Text('\xee\xa2\x8f')
                ImGui.EndGroup()
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.importignore) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            ImGui.PopStyleColor()

            if whosIgnore == '' then
                ImGui.TextWrapped('TSC ignores no-drop, lore, and non-stackable items by default.')
            else
                ImGui.TextWrapped('Items you want '..fname(whosIgnore)..' to ignore IN ADDITION to the global ignore list.')
            end

            local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY
            local x, y = ImGui.GetContentRegionAvail()
            if ImGui.BeginTable('IgnoreTable', 1, tableFlags, x, y) then
                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort, 0, 1)
                ImGui.TableSetupScrollFreeze(0, 1)

                local sort_specs = ImGui.TableGetSortSpecs()
                if sort_specs then
                    if sort_specs.SpecsDirty then
                        current_sort_specs = sort_specs
                        table.sort(mytable, sortBName)
                        if whosIgnore == '' then
                            ignore = mytable
                        else
                            pignoreList = mytable
                        end
                        save(whosIgnore)
                        current_sort_specs = nil
                        sort_specs.SpecsDirty = false
                    end
                end
                ImGui.TableHeadersRow()

                for k,v in pairs(mytable) do
                    ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                            ImGui.Text('\xef\x80\x94')
                            if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove item') end
                            if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                                mytable[k] = nil
                                if whosIgnore == '' then
                                    ignore = mytable
                                    reIndex(ignore)
                                else
                                    pignoreList = mytable
                                    reIndex(pignoreList)
                                end
                                save(whosIgnore)
                            end
                            ImGui.SameLine()
                            ImGui.Text(v)
                end
            ImGui.EndTable()
            end
        end
        ImGui.End()
    else
        whosIgnore = ''
    end
end


--------Draw artisan list window--------
local function artWindow()
    if openArt then
        openArt, drawArt = ImGui.Begin('Artisan list', openArt)
        ImGui.SetWindowSize(300,450,ImGuiCond.Once)
        if drawArt then

            if ImGui.Button('Add item') then addIgnore('artisan') end
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.addignoreitem) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            ImGui.SameLine()

            if ImGui.Button('Bulk add...') then ImGui.OpenPopup('Bulk add') end
            if ImGui.IsItemHovered() then ImGui.SetTooltip('Paste a list of items.') end

            if ImGui.BeginPopup('Bulk add') then
                ImGui.TextWrapped('Paste your list here. Each item should be on its own line. No commas or quotes. Exact spelling and capitalization matter.')
                ignoreBulkList = ImGui.InputTextMultiline('##bulkaddartisan', ignoreBulkList, 300, 400,0)
                if ImGui.Button('Add to artisan list') then bulkAdd('artisan') ImGui.CloseCurrentPopup() end
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
                        filedialog.draw_file_selector(mq.configDir..'/TSC', '.txt')
                    end
                    if not filedialog.is_file_selector_open() and filedialog.get_filename() ~= '' then
                        importIgnore('artisan')
                        filedialog.reset_filename()
                    end
                    ImGui.SameLine()
                    ImGui.Text('\xee\xa2\x8f')
                ImGui.EndGroup()
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.importignore) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
            ImGui.PopStyleColor()

            ImGui.TextWrapped('Items listed here will always be given to your artisan.')

            local tableFlags = ImGuiTableFlags.Sortable + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY
            local x, y = ImGui.GetContentRegionAvail()
            if ImGui.BeginTable('ArtisanTable', 1, tableFlags, x, y) then
                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort, 0, 1)
                ImGui.TableSetupScrollFreeze(0, 1)

                local sort_specs = ImGui.TableGetSortSpecs()
                if sort_specs then
                    if sort_specs.SpecsDirty then
                        current_sort_specs = sort_specs
                        table.sort(artisan, sortBName)
                        save()
                        current_sort_specs = nil
                        sort_specs.SpecsDirty = false
                    end
                end
                ImGui.TableHeadersRow()

                for k,v in pairs(artisan) do
                    ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                            ImGui.Text('\xef\x80\x94')
                            if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove item') end
                            if ImGui.IsItemClicked(ImGuiMouseButton.Left) then artisan[k] = nil reIndex(artisan) end
                            ImGui.SameLine()
                            ImGui.Text(v)
                end
            ImGui.EndTable()
            end
        end
        ImGui.End()
    end
end


--Context menus
local function toonContext(n, toon)
    if ImGui.BeginPopupContextItem('##'..toon) then
        if ImGui.Selectable('\xef\x89\x8e'..' Make tiebreaker') then settings.tiebreaker = alltoons[n].name save() end
        if ImGui.Selectable('\xef\x82\x91'..'  Make artisan') then settings.artisan = alltoons[n].name save() end
        if ImGui.Selectable('\xef\x8a\x90'..'  Add to mules') then addMule(alltoons[n].name) reIndex(settings['mules']) save() end
        if ImGui.Selectable('\xef\x81\x9e'..'  Edit personal ignore list') then
            whosIgnore = toon
            local List, error = loadfile(mq.configDir..'/TSC/ignore_'..toon..'.lua')
            if List then
                pignoreList = List()
            end
            openList = not openList
        end
        if ImGui.Selectable('\xef\x80\x94'..'  Remove') then removeTieArt(alltoons[n].name) alltoons[n] = nil getToonPeers() save() end
    ImGui.EndPopup()
    end
end
local function muleContext(n, mule)
    if ImGui.BeginPopupContextItem('##'..mule) then
        if ImGui.Selectable('\xee\x97\x87'..' Move up') then moveUp(n) save() end
        if ImGui.Selectable('\xee\x97\x85'..' Move down') then moveDown(n) save() end
        if ImGui.Selectable('\xef\x80\x94'..'  Remove') then settings['mules'][n] = nil reIndex(settings['mules']) getMulePeers() end
    ImGui.EndPopup()
    end
end


---Combo options
local modeOptions = {'Default', 'Generous', 'Greedy'}
local restOptions = {'Off', 'Depot > Bank > Mules', 'Depot > Bank', 'Depot > Mules', 'Bank > Mules', 'Bank', 'Mules'}


--------------------------------
--------Draw main window--------
local function tscWindow()
    ImGui.SetWindowSize(775,345)
    restWindow()
    matchWindow()
    ignoreWindow()
    artWindow()

    --Depot warning modal
    if depotWarning == true then ImGui.OpenPopup('Window Focus Warning') end
    ImGui.SetNextWindowSize(400, 200, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Window Focus Warning', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1,'WARNING!')
        ImGui.TextWrapped(tip.depotwarning)
        if ImGui.Button('I am ready') then depotWarning = false ImGui.CloseCurrentPopup() end
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then status = 'Idle' ImGui.CloseCurrentPopup() depotWarning = false end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end


    --Status section
    local tblflags = 0
    local columnFlags2 = ImGuiTableColumnFlags.WidthStretch
    local columnFlags = ImGuiTableColumnFlags.WidthFixed
    if ImGui.BeginTable('Status', 4, tblflags, 758, 0) then
        --Set widths
        ImGui.TableSetupColumn('',columnFlags2,150)
        ImGui.TableSetupColumn('',columnFlags2,150)
        ImGui.TableSetupColumn('',columnFlags2,150)
        ImGui.TableSetupColumn('',columnFlags,200)
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
                ImGui.BeginGroup()
                ImGui.Text('Tiebreaker:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1,fname(settings.tiebreaker))
                ImGui.EndGroup()
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.tie) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

            --Artisan
            ImGui.TableNextColumn()
                ImGui.AlignTextToFramePadding()
                ImGui.BeginGroup()
                ImGui.Text('Artisan:')
                ImGui.SameLine()
                ImGui.TextColored(0,1,0,1,fname(settings.artisan))
                ImGui.EndGroup()
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.art) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
                ImGui.SameLine()
                ImGui.Text('\xef\x80\x94')
                if ImGui.IsItemHovered() then ImGui.SetTooltip('Remove artisan') end
                if ImGui.IsItemClicked(ImGuiMouseButton.Left) then settings.artisan = 'Not set' save() end

            ImGui.TableNextColumn()
                local x,y = ImGui.GetContentRegionAvail()
                local half = x/2 - 4
                if ImGui.Button('Artisan list', half, 0) then openArt = not openArt end
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.hoardlist) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
                ImGui.SameLine()
                ImGui.SetNextItemWidth(x)
                if ImGui.Button('Ignore list', half, 0) then openList = not openList end
                if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.ignorebutton) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.EndTable()
    end
    --End status section

    --Toons table
    local tableFlags = ImGuiTableFlags.ScrollY + ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH

    if ImGui.BeginTable('ToonTable', 6, tableFlags, ImVec2(600,250)) then
        --Set widths
        ImGui.TableSetupColumn('',columnFlags,10)
        ImGui.TableSetupColumn('',columnFlags2,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)
        ImGui.TableSetupColumn('',columnFlags,100)

        --Header row
        ImGui.TableNextRow()
        ImGui.TableNextColumn()

        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Name')
        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Mode')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.mode) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Leftovers')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.rest) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Tidy up')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.self) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        ImGui.TableNextColumn()
            ImGui.TextColored(1,1,0,1,'Give')
            if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.give) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

       --ImGui.TableSetupScrollFreeze(0, 1) -- causes crash for some reason

        
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
                    local inv = tonumber(mq.TLO.DanNet(toon.name).O('Me.FreeInventory')()) or 0
                    if inv > 49 then
                        ImGui.TextColored(0,1,0,1,'\xef\x84\x91')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Online and in-zone. Inv: '..mq.TLO.DanNet(toon.name).O('Me.FreeInventory')()) end
                    else
                        ImGui.TextColored(1,1,0,.8,'\xef\x84\x91')
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Low inventory! Inv: '..mq.TLO.DanNet(toon.name).O('Me.FreeInventory')()) end
                    end

                --Name
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextColored(1,1,1,1,fname(toon.name))
                    toonContext(index, toon.name)
                    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end

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
                        if ImGui.Button('Tidy up##'..toon.name,100,20) then ImGui.OpenPopup('Tidy up confirmation##'..toon.name) end
                        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.self) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
                    ImGui.PopStyleColor()
                        ImGui.SetNextWindowSize(400, 170, ImGuiCond.Appearing)
                        if ImGui.BeginPopupModal('Tidy up confirmation##'..toon.name, nil, ImGuiWindowFlags.AlwaysAutoResize) then
                            ImGui.TextColored(1,1,0,1,'Ready?')
                            ImGui.Text('Item mode:')
                            ImGui.SameLine()
                            ImGui.TextColored(0,1,0,1, itemMode)
                            ImGui.TextWrapped(fname(toon.name)..tip.confirmself)
                            ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
                                if ImGui.Button('Tidy up') then activeToon = toon.name selfNow = true ImGui.CloseCurrentPopup() end
                            ImGui.PopStyleColor()
                            ImGui.SameLine()
                            ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
                                if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
                            ImGui.PopStyleColor()
                        ImGui.EndPopup()
                        end

                --Give button
                ImGui.TableNextColumn()

                    if ImGui.Button('Select...##'..toon.name,100,20) then ImGui.OpenPopup('give##'..toon.name)end

                    --Give pop-up
                    if ImGui.BeginPopup('give##'..toon.name) then
                        ImGui.TextColored(1,1,0,1,'Give all '..itemMode..' items to another?')
                        ImGui.Text('Who should '..fname(toon.name)..' give to?')
                        if ImGui.BeginCombo('##GiveCombo', fname(giveTarget)) then
                            for _,peer in pairs(giveComboOptions) do
                                if toon.name ~= peer then
                                    if ImGui.Selectable(fname(peer), giveTarget == peer) then
                                        giveTarget = peer
                                    end
                                end
                            end
                            ImGui.EndCombo()
                        end

                        if ImGui.Button('Start##'..toon.name) then
                            if giveTarget ~= '' then
                                ImGui.OpenPopup('Give confirmation##'..toon.name)
                            end
                        end

                        --Give confirmation modal
                        ImGui.SetNextWindowSize(400, 120, ImGuiCond.Appearing)
                        if ImGui.BeginPopupModal('Give confirmation##'..toon.name, nil, ImGuiWindowFlags.AlwaysAutoResize) then
                            ImGui.TextColored(1,1,0,1,'Ready?')
                            ImGui.Text('Item mode:')
                            ImGui.SameLine()
                            ImGui.TextColored(0,1,0,1, itemMode)
                            ImGui.TextWrapped(fname(toon.name)..' will give all their '..itemMode..' items to '..fname(giveTarget)..'.')
                            ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
                            if ImGui.Button('Give') then
                                if toon.name == giveTarget then
                                    print('\at[TsC]\ao You can\'t give your yourself!')
                                else
                                    activeToon = toon.name
                                    giveNow = true
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

                        ImGui.SameLine()

                        local update
                        giveBank, update = ImGui.Checkbox('Include bank', giveBank)
                        if update then utils.switch(giveBank) end

                        ImGui.SameLine()

                        local update2
                        giveDepot, update2 = ImGui.Checkbox('Include depot', giveDepot)
                        if update2 then utils.switch(giveDepot) end
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
                    ImGui.TextColored(1,0,0,.5,'\xef\x84\x91')
                ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextDisabled(fname(toon.name))
                    toonContext(index, toon.name)
                    if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
            end
        end

        --Add toon button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.TableNextColumn()

        if ImGui.Button('Add...') then ImGui.OpenPopup('addtoon') end
        ImGui.SameLine()
        ImGui.Text('\xee\xa2\x8f')
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.toon) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Add toon pop-up
        if ImGui.BeginPopup('addtoon') then
            ImGui.TextColored(1,1,0,1,'Add a toon')
            ImGui.Text('DanNet peers:')
            if ImGui.BeginCombo('##AddToonCombo', newToon) then
                for _,peer in pairs(toonComboOptions) do
                    if ImGui.Selectable(fname(peer), newToon == peer) then
                        newToon = peer
                        addToon(newToon)
                    end
                end
                ImGui.EndCombo()
            end
            if ImGui.Button('Add all in zone') then addAllInZone() ImGui.CloseCurrentPopup() end
            ImGui.EndPopup()
        end

    ImGui.EndTable()
    end
    --End Toons table

    ImGui.SameLine()

    --Mules table
    local muleTableFlags = ImGuiTableFlags.BordersOuterV + ImGuiTableFlags.RowBg + ImGuiTableFlags.BordersOuterH + ImGuiTableFlags.NoHostExtendX +  ImGuiTableFlags.ScrollY
    if ImGui.BeginTable('Muletable',2,muleTableFlags, ImVec2(150, 250)) then
        ImGui.TableSetupColumn('Mules', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Inv', ImGuiTableColumnFlags.WidthFixed, 40)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        --A row for each mule
        for index,mule in pairs(settings.mules) do
            ImGui.TableNextRow()
                ImGui.TableNextColumn()
                    local zone = mule.inzone or '0'
                    if zone == true then
                        ImGui.TextColored(1,1,1,1,fname(mule.name))
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
                    else
                        ImGui.TextDisabled(fname(mule.name))
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(tip.name) end
                    end
                    muleContext(index, mule.name)
                ImGui.TableNextColumn()
                    local inv = mq.TLO.DanNet(mule.name).O('Me.FreeInventory')() or '0'
                    if mq.TLO.Spawn('PC ='..mule.name)() then
                        ImGui.TextColored(1,1,1,1, inv)
                    else
                        ImGui.TextDisabled(inv)
                    end
        end

        --Add mule button
        ImGui.TableNextRow()
        ImGui.TableNextColumn()

        if ImGui.Button('Add...') then ImGui.OpenPopup('addmule') end
        ImGui.SameLine()
        ImGui.Text('\xee\xa2\x8f')
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.mule) ImGui.PopTextWrapPos() ImGui.EndTooltip() end

        --Add mule pop-up
        if ImGui.BeginPopup('addmule') then
            ImGui.TextColored(1,1,0,1,'Add a mule')
            ImGui.Text('DanNet peers:')
            if ImGui.BeginCombo('##AddMuleCombo', newMule) then
                for _,peer in pairs(muleComboOptions) do
                    if ImGui.Selectable(fname(peer), newMule == peer) then
                        newMule = peer
                        addMule(newMule)
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.EndPopup()
        end
    ImGui.EndTable()
    end
    --End mules table

    --Go button
    ImGui.PushStyleColor(ImGuiCol.Button, 0, 1, 0, .5)
        if ImGui.Button('Consolidate all') then ImGui.OpenPopup('Consolidate confirmation') end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.go) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()
    
    --Tidy-up all button
    ImGui.PushStyleColor(ImGuiCol.Button, 0, .5, 0, .75)
        if ImGui.Button('Tidy up all') then ImGui.OpenPopup('Tidy up ALL confirmation##all') end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.tidyall) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.PopStyleColor()
    ImGui.SetNextWindowSize(400, 170, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Tidy up ALL confirmation##all', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1,'Ready?')
        ImGui.Text('Item mode:')
        ImGui.SameLine()
        ImGui.TextColored(0,1,0,1, itemMode)
        ImGui.TextWrapped('All toons'..tip.confirmself)
        ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
            if ImGui.Button('Tidy up all') then allSelfNow = true ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end
    ImGui.SameLine()


    --Stop button
    ImGui.PushStyleColor(ImGuiCol.Button, 1, 0, 0, .5)
        if ImGui.Button('Stop all') then utils.stopAll(true) end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.stop) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    --Consolidate all confirmation modal
    ImGui.SetNextWindowSize(400, 155, ImGuiCond.Appearing)
    if ImGui.BeginPopupModal('Consolidate confirmation', nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(1,1,0,1, 'Ready?')
        ImGui.Text('Item mode:')
        ImGui.SameLine()
        ImGui.TextColored(0,1,0,1, itemMode)
        ImGui.TextWrapped(tip.goall)
        ImGui.PushStyleColor(ImGuiCol.Button, 0,1,0,.5)
            if ImGui.Button('Consolidate all') then goNow = true ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Button, 1,0,0,.5)
            if ImGui.Button('Cancel') then ImGui.CloseCurrentPopup() end
        ImGui.PopStyleColor()
    ImGui.EndPopup()
    end

    --Item mode combo
    ImGui.SetNextItemWidth(120)
    if ImGui.BeginCombo('##Mode', itemMode,0) then
        if ImGui.Selectable('Tradeskill', itemMode == 'Tradeskill') then
            itemMode = 'Tradeskill'
        end
        if ImGui.Selectable('Collectibles', itemMode == 'Collectibles') then
            itemMode = 'Collectibles'
        end
    ImGui.EndCombo()
    end
    ImGui.SameLine()

    --Real estate checkbox
    local updateReal
    settings.includePlots, updateReal = ImGui.Checkbox('Include plots', settings.includePlots)
	if updateReal then utils.switch(settings.includePlots) save() end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.real) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    if settings.includePlots == true then
        local updateReal2
        settings.preferPlots, updateReal2 = ImGui.Checkbox('Prefer plots', settings.preferPlots)
        if updateReal2 then utils.switch(settings.preferPlots) save() end
        if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.prefReal) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
        ImGui.SameLine()
    end

    --Stats checkbox
    local update
    settings.stats, update = ImGui.Checkbox('Run stats', settings.stats)
	if update then utils.switch(settings.stats) save() end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip() ImGui.PushTextWrapPos(300) ImGui.TextWrapped(tip.stats) ImGui.PopTextWrapPos() ImGui.EndTooltip() end
    ImGui.SameLine()

    ImGui.TextColored(1,1,1,.7,' v'..version)
end

local openGui, drawGui = true, true
local function initGui()
    if openGui then
        ImGui.SetNextWindowBgAlpha(1)
        openGui, drawGui = ImGui.Begin('TS Consolidator##'..me, openGui)
        if drawGui then tscWindow() end
        ImGui.End()
    else
        utils.stopAll()
    end
end

mq.imgui.init('TSC', initGui)

while openGui do
    whileWaiting()
    if goNow == true then goNow = false go(itemMode) end
    if selfNow == true then selfNow = false self(activeToon, itemMode) end
    if allSelfNow == true then allSelfNow = false self('all', itemMode) end
    if giveNow == true then giveNow = false give(activeToon, giveTarget, itemMode, giveBank, giveDepot) end
    mq.delay(100)
end