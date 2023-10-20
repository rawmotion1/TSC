---@type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('home')

local args = {...}
local what = tonumber(args[1])

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

local settings = {}
local items = {}
local consol = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local allitems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('\at[TsC]\ao Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end

    local consolidate, consolerror = loadfile(mq.configDir..'/'..consolPath)
    if consolerror then
        print('\at[TsC]\ao Error loading consolidate.lua')
        mq.exit()
    elseif consolidate then
        consol = consolidate()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to real estate...')
mq.delay(1000)

local grabFromBank = false
local grabFromPlots = false
local putInPlots = false
local bankGrabList = {}
local plotGrabList = {}
local plotPutList = {}
local plotRestackList = {}
local plotRestackList2 = {}


--Items to grab plotGrabList = {place = {1 = item}}
local function addToGrabList(item, dest)
    local destination = string.match(dest, "^([^,]+,[^,]+)")
    local _, _, room = string.match(dest, "([^,]+),%s([^,]+),%s([^,]+)")

    for plot,_ in pairs(items[item]['plots']) do
        local place = string.match(plot, "^([^,]+,[^,]+)")
        local _, _, thisRoom = string.find(plot, "^[^,]+,[^,]+,([^,]+)")

        if destination ~= place then
            if not plotGrabList[place] then plotGrabList[place] = {} end
            local skip = false
            for _,v in pairs(plotGrabList[place]) do
                if v == item then
                    skip = true
                end
            end
            if skip == false then
                table.insert(plotGrabList[place], item)
            end
        elseif thisRoom ~= room then
            if not plotRestackList[place] then plotRestackList[place] = {} end
            local skip = false
            for _,v in pairs(plotRestackList[place]) do
                if v == item then
                    skip = true
                end
            end
            if skip == false then
                table.insert(plotRestackList[place], item)
                local finalroom = 'Closet'
                if string.match(room,'Crate') then finalroom = 'Crate' end
                if not plotRestackList2[place] then plotRestackList2[place] = {} end
                if not plotRestackList2[place][item] then plotRestackList2[place][item] = finalroom end
            end
        end
    end
end

--Items to put plotPutList = {place = {item = room}}
local function addToPutList(item, dest)
    local plot = string.match(dest, "^([^,]+,[^,]+)")
    local room = 'Closet'
    if string.match(dest,'Crate') then room = 'Crate' end
    if not plotPutList[plot] then plotPutList[plot] = {} end
    if not plotPutList[plot][item] then plotPutList[plot][item] = room end
end



local function createLists()
    if consol[me] then
        for item,dest in pairs(consol[me]) do

            --Item needs to go from bank to plot
            if string.match(dest, ",") and utils.listSize(items[item]['bank']) > 0 then
                print('\at[TsC]\ay '..item..' \ao needs to go from bank to plot')
                table.insert(bankGrabList, item)
                addToPutList(item, dest)
                grabFromBank = true
                putInPlots = true
            end

            --Item needs to go from plot to bank
            if (dest == "Depot" or dest == "Bank") and utils.listSize(items[item]['plots']) > 0 then
                print('\at[TsC]\ay '..item..' \ao needs to go from plot to bank')
                addToGrabList(item, dest)
                grabFromPlots = true
            end

            --Item needs to go from one plot to another
            if string.match(dest, ",") and utils.listSize(items[item]['plots']) > 1 then
                print('\at[TsC]\ay '..item..' \ao needs to go from one plot to another')
                addToGrabList(item, dest)
                addToPutList(item, dest)
                grabFromPlots = true
                putInPlots = true
            end

            --Item needs to go from inventory to plots
            if string.match(dest, ",") and utils.listSize(items[item]['inventory']) > 0 then
                print('\at[TsC]\ay '..item..' \ao needs to go from inventory to plots')
                addToPutList(item, dest)
                putInPlots = true
            end

            mq.delay(100)
        end
    end
end
createLists()

mq.pickle('TSC/tmp/myputlist'..me..'.lua',plotPutList)
mq.pickle('TSC/tmp/mygrablist'..me..'.lua',plotGrabList)
mq.pickle('TSC/tmp/mybanklist'..me..'.lua',bankGrabList)

local count = 0
local function plotPutGrab()
    if grabFromPlots == true then
        --Visit all necessary plots to grab and put items
        for place,_ in pairs(plotGrabList) do
            local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
            print('\at[TsC]\ao 159 Heading to \ay'..place..'\ao.')
            home.go(neigh, plot)
            utils.cleanup()
            mq.delay(1000)

            if plotGrabList[place] then
                utils.grabReal(plotGrabList[place])
                mq.delay(500)
            end

            if plotRestackList[place] then
                utils.grabReal(plotRestackList[place])
                mq.delay(500)
                count = count + utils.putReal(plotRestackList2[place])
                plotRestackList[place] = nil
                plotRestackList2[place] = nil
            end

            if putInPlots == true then
                if plotPutList[place] then
                    count = count + utils.putReal(plotPutList[place])
                    plotPutList[place] = nil
                end
            end
            utils.cleanup()
        end
    end

    --If necessary, visit plots a second time to put away items I just grabbed from other plots after visiting the put plot
    if putInPlots == true then
        for place,_ in pairs(plotPutList) do
            local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
            print('\at[TsC]\ao 191 Heading to \ay'..place..'\ao.')
            home.go(neigh, plot)
            utils.cleanup()
            mq.delay(1000)
            if plotPutList[place] then
                count = count + utils.putReal(plotPutList[place])
            end

            if plotRestackList[place] then
                utils.grabReal(plotRestackList[place])
                mq.delay(500)
                count = count + utils.putReal(plotRestackList2[place])
                plotRestackList[place] = nil
                plotRestackList2[place] = nil
            end
        end
        utils.cleanup()
    end

    --If there is anything left to restack
    for place,_ in pairs(plotRestackList) do
        local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao 213 Heading to \ay'..place..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        if plotRestackList[place] then
            count = count + utils.putReal(plotRestackList2[place])
        end
    end
    utils.cleanup()
end

if settings.preferPlots == true then
    if grabFromBank == true then
        utils.grab(bankGrabList, what, 3)
    end
end

if utils.listSize(plotGrabList) > 0 or utils.listSize(plotPutList) > 0 then
    plotPutGrab()
end

if count > 0 then
    mq.cmdf('/dt %s \awDone with real estate. Stored \ay%s \awunique items.', settings.driver, count)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc doneplots')
else
    mq.cmdf('/dex %s /tsc doneplots', settings.driver)
end