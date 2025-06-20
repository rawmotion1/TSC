---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local tm = require('TSC.toonmanager')
local sm = require('TSC.statemanager')
local utils = require('TSC.utils')
local compare = require('TSC.compare')
local assign = require('TSC.assign')
local search = require('TSC.search')
local im = require('TSC.itemmanager')

---@class Routines
local routines = {}

--Starts a routine based on the type passed from init
function routines:start()
    if sm.routine == 'consolidate' or sm.routine == 'clean' or sm.routine == 'cleanAll' then
        self:consolidate(sm.routine)
    elseif sm.routine == 'give' or sm.routine == 'giveAll' then
        self:give(sm.routine)
    elseif sm.routine == 'search' then
        self:search()
    elseif sm.routine == 'deliver' then
        self:deliver()
    end
end


--
--Subroutines
--

--Decide who should run banker.lua
function routines.shouldBank(tbl)
    local toonList = {}
    for toon in pairs(tbl) do
        if im.lists.toplot and im.lists.toplot[toon] then
            for item in pairs(im.lists.toplot[toon]) do
                mq.cmdf('/dquery %s -q "FindItemCount[=%s]"', toon, item)
                mq.delay(200)
                local query = "FindItemCount[="..item.."]"
                local remoteItem = mq.TLO.DanNet(toon).Q(query)() or '0'
                if remoteItem and tonumber(remoteItem) > 0 then
                    toonList[toon] = true -- I have items in my inventory that need to be put in plots
                    break
                end
            end
        end
        --Or, I haven't been to the plots yet, but I have items to move
        if im.lists.tomoveplot[toon] and utils.tableLength(im.lists.tomoveplot[toon]) > 0 then
            toonList[toon] = true -- I have items to move to plots
        end
        if (im.lists.tobank[toon] and utils.tableLength(im.lists.tobank[toon]) > 0) or (im.lists.tomovedepot[toon] and utils.tableLength(im.lists.tomovedepot[toon]) > 0) then
            toonList[toon] = true -- I have items to bank
        end
    end
    return toonList
end


--Run scanner 
function routines:scan(tbl, scope, give)
    for k in pairs(tbl) do
        utils.execute(k, '/lua run TSC/scripts/scanner '..sm.itemType..' '..scope)
        mq.delay(100)
    end
end

--Run grabber
function routines:grab(tbl)
    for k in pairs(tbl) do
        utils.execute(k, '/lua run TSC/scripts/grabber '..sm.itemType)
        mq.delay(100)
    end
end

--Run trader
function routines:trade(tbl)
    for k in pairs(tbl) do
        utils.execute(k, '/lua run TSC/scripts/trader '..sm.itemType)
        utils.waiting(1) --Wait for each toon to finish before moving on
        mq.delay(100)
    end
end

--Run banker
function routines:bank(tbl)
    for k in pairs(tbl) do
        utils.execute(k, '/lua run TSC/scripts/banker '..sm.itemType)
        mq.delay(100)
    end
end

--Run depot
function routines:depot(tbl)
    for k in pairs(tbl) do
        utils.execute(k, '/lua run TSC/scripts/depoter')
        utils.waiting(1) --Wait for each toon to finish before moving on
        mq.delay(100)
    end
end

--Run leftovers
function routines:leftovers(tbl)
    for k in pairs(tbl) do
        if cm.toons[k].leftovers ~= 'Off' then
            utils.execute(k, '/lua run TSC/scripts/leftover')
            utils.waiting(1) --Wait for each toon to finish before moving on
            mq.delay(100)
        end
    end
end

function routines.calculateStats(tbl)
    local total = 0
    for toon in pairs(tbl) do
        if sm.stats[toon] then
            local beforeItems = sm.stats[toon].beforeItems or 0
            local beforeSlots = sm.stats[toon].beforeSlots or 0
            local afterItems = sm.stats[toon].afterItems or 0
            local afterSlots = sm.stats[toon].afterSlots or 0
            local newItems = beforeItems - afterItems -- if you end with more than you started with, it's negative = bad, red, +
            local newSlots = beforeSlots - afterSlots -- If you have more slots at the end, it's negative = bad, red, -
            local itemSymbol, itemColor = '', '\ay'
            local slotSymbol, slotColor = '', '\ay'
            if newItems < 0 then itemSymbol, itemColor = '+', '\ar' elseif newItems > 0 then itemSymbol, itemColor = '-', '\ag' end
            if newSlots < 0 then slotSymbol, slotColor = '-', '\ar' elseif newSlots > 0 then slotSymbol, slotColor = '+', '\ag' end
            print('\at[TsC]\ar '..utils.fname(toon)..'\ao had \ay'..beforeItems..'\ao unique items taking up \ay'..beforeSlots..'\ao slots.')
            print('\at[TsC]\ar '..utils.fname(toon)..'\ao now has \ay'..afterItems..'\ao unique items taking up \ay'..afterSlots..'\ao slots.')
            printf('\at[TsC]\ar %s\ao: Items: %s%s%s\ao. Slots: %s%s%s\ao.', utils.fname(toon), itemColor, itemSymbol, math.abs(newItems), slotColor, slotSymbol, math.abs(newSlots))
            total = total + newSlots
        end
    end
    local length = utils.tableLength(tbl)
    print('\at[TsC]\ao TOTAL: freed up \ag'..total..'\ao slots across\ay '..length..'\ao toons.')
end

function routines.calculateGive(tbl)
    local total = 0
    for toon in pairs(tbl) do
        local given = sm.stats[toon].beforeItems - sm.stats[toon].afterItems
        print('\at[TsC]\ao \ar'..utils.fname(toon)..'\ao gave away \ay'..given..'\ao items.')
        total = total + given
    end
    print('\at[TsC]\ao TOTAL: \ag'..total..'\ao items given away across\ay '..utils.tableLength(tbl)..'\ao toons.')
end


--
--Main routines
--

--MAIN consolidation routine
function routines:consolidate(routine)

    if routine == 'consolidate' then
        -- Confirm at least 2 toons are online
        if utils.tableLength(tm.onlineToons) < 2 then
            print('\at[TsC]\ao Consolidate requires at least 2 toons in-zone.')
            return
        end
    end

    local toons = tm.onlineToons
    if routine == 'clean' then
        toons = { [sm.activeToon] = true }
    end

    -- Confirm banker is in the zone
    if utils.checkBanker() == false then
        print('\at[TsC]\ao No banker in zone. Stopping.')
        return
    end

    if routine == 'consolidate' then
        print('\at[TsC]\ao Start consolidation routine...')
    elseif routine == 'clean' then
        print('\at[TsC]\ao Start self-clean routine on \ar'..utils.fname(sm.activeToon)..'\ao...')
    elseif routine == 'cleanAll' then
        print('\at[TsC]\ao Start self-clean routine on all toons...')
    end

    --Reset stats for all toons
    utils.clearStats()

    print('\at[TsC]\ao----Pausing toons...')
    utils.pauseToons(toons)

    -- Tell each toon to run the scanner
    sm.status = 'Scanning'
    print('\at[TsC]\ao----Scanning toons...')
    self:scan(toons, 'all') -- Scan all items for all toons	
    utils.waiting(utils.tableLength(toons)) --Wait for all scans to finish
    print('\at[TsC]\ao----Done scanning.')

    --Print scan results
    for toon, stats in pairs(sm.stats) do
        if routine == 'clean' then
            if toon == sm.activeToon then
                print('\at[TsC]\ar '..utils.fname(toon)..'\ao has\ay '..stats.beforeItems..'\ao unique items taking up \ay'..stats.beforeSlots..'\ao slots.')
                break
            end
        else
            print('\at[TsC]\ar '..utils.fname(toon)..'\ao has\ay '..stats.beforeItems..'\ao unique items taking up \ay'..stats.beforeSlots..'\ao slots.')
        end
    end

    --Determine final destination for each item (trades and moves)
    sm.status = 'Comparing'
    print('\at[TsC]\ao----Comparing items...')
    im.combinedItems = {}
    if routine == 'clean' or routine == 'cleanAll' then
        compare.run(toons, true) -- Run compare for self-clean
    else
        compare.run(toons) -- Run compare normally for consolidation
    end
    print('\at[TsC]\ao----Done comparing.')

    --Wait for user to click continue or cancel on matches window
    if cm.settings.fullAuto == false then
        sm.status = 'Waiting for user'
        print('\at[TsC]\ao Waiting for user to confirm trades and moves...')
        sm.tradeConfirmWnd = true
        utils.waitingUser()
    end

    --Create definive lists after user has the chance to edit trades and moves
    im:clearLists()
    im:createLists()

    if sm.skipTrading == false then --They clicked continue

        -- Add toons that need to grab items from plots to the bank grab list because it's one script
        for toon in pairs(im.lists.toplotgrab) do
            im.lists.tograb[toon] = im.lists.tograb[toon] or {}
            print('\at[TsC]\ao \ar'..utils.fname(toon)..'\ao needs to grab items from plots.')
        end

        --Run the grabber: bank and real estate
        sm.status = 'Retreiving items'
        print('\at[TsC]\ao----Retreiving items...')
        self:grab(im.lists.tograb)
        utils.waiting(utils.tableLength(im.lists.tograb))
        print('\at[TsC]\ao----Done retreiving.')

        if routine == 'consolidate' then
            --Run trader script on one toon at a time
            sm.status = 'Trading items'
            print('\at[TsC]\ao----Trading items...')
            self:trade(im.lists.totrade)
            print('\at[TsC]\ao----Done trading.')
        end

        --Run the banker script, putting items in the bank, plots, and grabbing bank-to-depot items
        sm.status = 'Storing items'
        print('\at[TsC]\ao----Storing items (bank & real estate)...')
        local bankers = routines.shouldBank(toons) --Get a list of toons that need to run banker.lua
        self:bank(bankers)
        utils.waiting(utils.tableLength(bankers))
        print('\at[TsC]\ao----Done storing (bank & real estate).')

        --Add toons that need to move items from the bank to the depot to the depot list
        for toon in pairs(im.lists.tomovedepot) do
            im.lists.todepot[toon] = im.lists.todepot[toon] or {}
        end

        --Run the depot script on one toon at a time
        sm.status = 'Deposting'
        print('\at[TsC]\ao----Storing items in the depot...')
        --Show warning popup before running depot script
        if cm.settings.fullAuto == false and utils.tableLength(im.lists.todepot) > 0 then
            sm.status = 'Depot warning'
            utils.waitingUser()
            if sm.status == 'Depositing' then
                self:depot(im.lists.todepot)
                print('\at[TsC]\ao----Done storing (depot).')
            else
                print('\at[TsC]\ao Skipping depot routine.')
            end
        else
            self:depot(im.lists.todepot)
            print('\at[TsC]\ao----Done storing (depot).')
        end

    else --They cancelled the trades and moves
        print('\at[TsC]\ao Skipping consolidation.')
    end

    --Wait for user to click continue or cancel on leftovers window
    if cm.settings.fullAuto == false then
        sm.status = 'Waiting for user'
        print('\at[TsC]\ao Waiting for user to confirm leftovers...')
        sm.leftoverConfirmWnd = true
        utils.waitingUser()
    end

    if sm.skipLeftovers == false then --They clicked continue
        sm.status = 'Leftovers'
        print('\at[TsC]\ao----Handling leftovers...')

        --Decide if we need to show depot warning again
        local shouldShowWarning = false
        for toon in pairs(im.lists.todump) do
            if cm.toons[toon].leftovers:find('Depot') then
                shouldShowWarning = true
                break
            end
        end
        --Show depot warning if needed
        if shouldShowWarning and cm.settings.fullAuto == false then
            sm.status = 'Depot warning'
            utils.waitingUser()
            if sm.status == 'Depositing' then
                sm.status = 'Leftovers'
            end
        end
        --Run the leftovers script on one toon at a time
        self:leftovers(im.lists.todump)
        print('\at[TsC]\ao----Done with leftovers.')
    else --They cancelled the leftovers
        print('\at[TsC]\ao Skipping leftovers.')
    end

    if cm.settings.stats == true then
        -- Tell each toon to run the scanner
        sm.status = 'Scanning'
        print('\at[TsC]\ao----Scanning toons...')
        self:scan(toons, 'all')
        utils.waiting(utils.tableLength(toons)) --Wait for all scans to finish
        print('\at[TsC]\ao----Done scanning.')
        routines.calculateStats(toons)
    end

    --Unpause toons that were paused at the start of the routine
    print('\at[TsC]\ao----Unpausing toons.')
    utils.unpauseToons() --Unpause toons

    if routine == 'consolidate' then
        print('\at[TsC]\ao CONSOLIDATION COMPLETE.')
    elseif routine == 'clean' then
        print('\at[TsC]\ar '..sm.activeToon..'\'s \aoSELF-CLEAN COMPLETE.')
    elseif routine == 'cleanAll' then
        print('\at[TsC]\ao SELF-CLEAN COMPLETE FOR ALL TOONS.')
    end
    sm:clear() --Reset states
end



function routines:give(routine)
    if utils.checkBanker() == false and sm.includeBank == true then
        print('\at[TsC]\ao No banker in zone. Stopping.')
        return
    end

    local toons = {}
    if routine == 'give'then
        toons = { [sm.activeToon] = true, [sm.giveTarget] = true }
        print('\at[TsC]\ar '..sm.activeToon..' \aowill now give all \ay'..sm.itemType..' \ao items to \ar'..sm.giveTarget..'\ao...')
    elseif routine == 'giveAll' then
        for toon in pairs(tm.onlineToons) do
            toons[toon] = true -- Add all online toons to the list
        end
        print('\at[TsC]\ar ALL toons \aowill now give their \ay'..sm.itemType..' \ao items to \ar'..sm.giveTarget..'\ao...')
    end

    --Reset stats for all toons
    utils.clearStats()

    print('\at[TsC]\ao----Pausing toons...')
    utils.pauseToons(toons)

    -- Now remove the target from list
    toons[sm.giveTarget] = nil

    -- Tell each toon to run the scanner
    sm.status = 'Scanning'
    print('\at[TsC]\ao----Scanning toons...')
    local scope
    if sm.includeBank then
        scope = 'all give' -- Scan all items including bank
    else
        scope = 'inventory give' -- Scan only inventory items
    end

    self:scan(toons, scope)

    utils.waiting(utils.tableLength(toons)) --Wait for all scans to finish
    print('\at[TsC]\ao----Done scanning.')

    assign.run(toons, sm.giveTarget) --Run assign script to determine who gets what

    --Wait for user to click continue or cancel on matches window
    if cm.settings.fullAuto == false then
        sm.status = 'Waiting for user'
        print('\at[TsC]\ao Waiting for user to confirm trades and moves...')
        sm.tradeConfirmWnd = true
        utils.waitingUser()
    end

    --Create definive lists after user has the chance to edit trades and moves
    im:clearLists()
    im:createLists()

    if sm.skipTrading == false then --They clicked continue

    if sm.includeBank then
        sm.status = 'Retreiving items'
        print('\at[TsC]\ao----Retreiving items...')
        self:grab(im.lists.tograb) --Grab items from plots and bank
        utils.waiting(utils.tableLength(im.lists.tograb)) --Wait for all grabs to finish
        print('\at[TsC]\ao----Done retreiving.')

        utils.execute(sm.giveTarget, '/cleanup')
    end
        --Run the trader script on one toon at a time
        sm.status = 'Trading items'
        print('\at[TsC]\ao----Trading items...')
        self:trade(im.lists.totrade)
        print('\at[TsC]\ao----Done trading.')

        if cm.settings.stats then
            -- Tell each toon to run the scanner
            sm.status = 'Scanning'
            print('\at[TsC]\ao----Scanning toons...')
            self:scan(toons, scope)
            utils.waiting(utils.tableLength(toons)) --Wait for all scans to finish
            print('\at[TsC]\ao----Done scanning.')
            routines.calculateGive(toons)
        end

    else --They cancelled the trades and moves
        print('\at[TsC]\ao Skipping give routine.')
    end

    --Unpause toons that were paused at the start of the routine
    print('\at[TsC]\ao----Unpausing toons.')
    utils.unpauseToons() --Unpause toons

    sm:clear() --Reset states
    print('\at[TsC]\ao GIVE ROUTINE COMPLETE.')
end



function routines:search()

    search.results = {} -- Reset search results

    print('\at[TsC]\ao Updating items list...')
    sm.searchWnd = true

    print('\at[TsC]\ao----Pausing toons...')
    utils.pauseToons(tm.onlineToons)

    --Reset stats for all toons
    utils.clearStats()

    -- Tell each toon to run the scanner
    sm.status = 'Scanning'
    print('\at[TsC]\ao----Scanning toons...')
    self:scan(tm.onlineToons, 'all') -- Scan all items for all toons	
    utils.waiting(utils.tableLength(tm.onlineToons)) --Wait for all scans to finish
    print('\at[TsC]\ao----Done scanning.')

    search.run(tm.onlineToons) -- Create table of all toons' items and their quantities

    --Unpause toons that were paused at the start of the routine
    print('\at[TsC]\ao----Unpausing toons.')
    utils.unpauseToons() --Unpause toons

    print('\at[TsC]\ao Items list updated.')

    sm:clear() --Reset states
end

function routines:deliver()

    print('\at[TsC]\ao Starting Deliver routine...')
    sm.status = 'Delivering'

    local toons = { [sm.activeToon] = true, [sm.giveTarget] = true }

    print('\at[TsC]\ao----Pausing toons...')
    utils.pauseToons(toons)

    --Check how much deliverer has in inventory
    local inInventory = 0
    if im.combinedItems[sm.activeToon][sm.deliverItem].inventory and utils.tableLength(im.combinedItems[sm.activeToon][sm.deliverItem].inventory) > 0 then
        for _, qty in pairs(im.combinedItems[sm.activeToon][sm.deliverItem].inventory) do
            inInventory = inInventory + qty
        end
    end

    im:clearLists()

    --If not enough, we need to grab more from bank or plots
    local toGrab = 0
    if inInventory < sm.deliverQty then
        toGrab = sm.deliverQty - inInventory
        print('\at[TsC]\ao \ar'..sm.activeToon..'\ao does not have enough \ay'..sm.deliverItem..'\ao in inventory. Need to grab \ay'..toGrab..'\ao more from bank or plots.')
        if utils.checkBanker() == false then return end
        im.lists.tograb[sm.activeToon] = { [sm.deliverItem] = true } -- Add item to grab list
        im.lists.toplotgrab[sm.activeToon] = { [sm.deliverItem] = true } -- Add item to plot grab list
        cm.saveData('lists', im.lists) -- Save the lists to disk
        sm.status = 'Retreiving items'
        utils.execute(sm.activeToon, '/lua run TSC/scripts/grabber '..sm.itemType..' '..toGrab)
        utils.waiting(1) -- Wait for the grabber script to finish
    end

    print('\at[TsC]\ar '..sm.activeToon..' \aowill now deliver \ay'..sm.deliverItem..'\ao x\ay'..sm.deliverQty..'\ao to \ar'..sm.giveTarget..'\ao...')
    im.lists.totrade[sm.activeToon] = { [sm.deliverItem] = sm.giveTarget } -- Add item to trade list
    cm.saveData('lists', im.lists) -- Save the lists to disk
    utils.execute(sm.activeToon, '/lua run TSC/scripts/trader '..sm.deliverQty)
    utils.waiting(1) -- Wait for the trader script to finish

    print('\at[TsC]\ao Delivery complete.')


    print('\at[TsC]\ao Updating items list...')
    sm.searchWnd = true

    --Reset stats for all toons
    utils.clearStats()

    --Update toons' item tables quantity
    utils.execute(sm.activeToon, '/lua run TSC/scripts/scanner '..sm.itemType..' all '..'"'..sm.deliverItem..'"')
    utils.execute(sm.giveTarget, '/lua run TSC/scripts/scanner '..sm.itemType..' all '..'"'..sm.deliverItem..'"')
    utils.waiting(2)

    --Recompile search results
    search.run(tm.onlineToons) -- Create table of all toons' items and their quantities
    print('\at[TsC]\ao Items list updated.')

    --Unpause toons that were paused at the start of the routine
    print('\at[TsC]\ao----Unpausing toons.')
    utils.unpauseToons() --Unpause toons

    sm:clear() --Reset states
end

return routines