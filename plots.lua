---@type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('home')

local args = {...}
local what = tonumber(args[1])

local me = mq.TLO.Me.Name()
local startZone = mq.TLO.Zone.ShortName()
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

print('\at[TsC]\ao Looking for items to move to/from real estate...')
mq.cmdf('/dt %s \awHeading to Sunrise Hills.', settings.driver)
mq.delay(1000)


local function skip(item, list)
    local toskip = false
    for _,v in pairs(list) do if v == item then toskip = true end end
    if toskip == false then return false else return true end
end

local bankGrabList = {}
local function addToBankGrabList(item)
    if skip(item, bankGrabList) == false then table.insert(bankGrabList, item) end
end

local plotGrabList = {}
local function addToPlotGrabList(item)
    for plot,_ in pairs(items[item]['plots']) do
        if plot ~= items[item]['destination'] then
            local place = string.match(plot, "^([^,]+,[^,]+)")
            if not plotGrabList[place] then plotGrabList[place] = {} end
            if skip(item, plotGrabList[place]) == false then table.insert(plotGrabList[place], item) end
        end
    end
end

local plotPutList = {}
local function addToplotPutList(item, destination, room)
    if not plotPutList[destination] then plotPutList[destination] = {} end
    local myRoom = 'Closet'
    if string.match(room,'Crate') then myRoom = 'Crate' end
    if not plotPutList[destination][item] then plotPutList[destination][item] = myRoom end
end

local plotRestackGrab = {}
local plotRestackPut = {}

--1 Item needs to go from plot(s) to bank
--2 Item needs to go from bank to plot
--3 Item needs to go from inventory to plot
--4 Item needs to go from plot(s) to plot
--5 Item needs to go from 1 room to another in same plot
local function createLists()
    if consol[me] then
        for item,dest in pairs(consol[me]) do
            if dest ~= true then
                local destination = string.match(dest, "^([^,]+,[^,]+)")
                local _, _, room = string.match(dest, "([^,]+),%s([^,]+),%s([^,]+)")

                --1 Item needs to go from plot(s) to bank or depot
                if (dest == "Depot" or dest == "Bank") and utils.listSize(items[item]['plots']) > 0 then
                    print('\at[TsC]\ay '..item..' \ao needs to go from plot(s) to bank')
                    addToPlotGrabList(item)

                --2 Item needs to go from bank to plot
                elseif string.match(dest, ",") then
                    if utils.listSize(items[item]['bank']) > 0 then
                        print('\at[TsC]\ay '..item..' \ao needs to go from bank to plot')
                        addToBankGrabList(item)
                        addToplotPutList(item, destination, room)
                    end

                    --3 Item needs to go from inventory to plot
                    if utils.listSize(items[item]['inventory']) > 0 then
                        print('\at[TsC]\ay '..item..' \ao needs to go from inventory to plot')
                        addToplotPutList(item, destination, room)
                    end

                    if utils.listSize(items[item]['plots']) > 1 then
                        for plot,_ in pairs(items[item]['plots']) do
                            local thisPlot = string.match(plot, "^([^,]+,[^,]+)")
                            local _, _, thisRoom = string.match(plot, "([^,]+),%s([^,]+),%s([^,]+)")
                            
                            --4 Item needs to go from plot(s) to plot
                            if thisPlot ~= destination then
                                print('\at[TsC]\ay '..item..' \ao needs to go from one plot to another')
                                addToPlotGrabList(item)
                                addToplotPutList(item, destination, room)

                            --5 Item needs to go from 1 room to another in same plot
                            elseif thisRoom ~= room then
                                print('\at[TsC]\ay '..item..' \ao needs to go from one room to another')
                                if not plotRestackPut[destination] then plotRestackPut[destination] = {} end
                                if not plotRestackGrab[destination] then plotRestackGrab[destination] = {} end
                                if not plotRestackPut[destination][item] then plotRestackPut[destination][item] = room end
                                if skip(item, plotRestackGrab[destination]) == false then table.insert(plotRestackGrab[destination], item) end
                            end
                        end
                    end
                end
            end
        end
    end
end
createLists()

if settings.preferPlots == true then
    if utils.listSize(bankGrabList) > 0 then
        utils.grab(bankGrabList, what, 3)
        utils.cleanup()
    end
end

local count = 0
--Run to all plots with items to grab. While there, also put and restack.
if utils.listSize(plotGrabList) > 0 then
    for place,_ in pairs(plotGrabList) do
        local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..place..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)

        utils.grabReal(plotGrabList[place])
        mq.delay(500)

        if plotPutList[place] then
            count = count + utils.putReal(plotPutList[place])
        end

        if plotRestackGrab[place] then
            utils.grabReal(plotRestackGrab[place])
            mq.delay(500)
            count = count + utils.putReal(plotRestackPut[place])
            plotRestackGrab[place] = nil
        end
    end
end

--Run to all plots with items to put, but only if they are in inventory because I grabbed them in the previous step or haven't been there yet. Also restack.
if utils.listSize(plotPutList) > 0 then
    for place,_ in pairs(plotPutList) do
        local inv = false
        for item,_ in pairs(plotPutList[place]) do
            if mq.TLO.FindItemCount('='..item)() > 0 then
                inv = true
            end
        end
        if inv == true then
            local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
            print('\at[TsC]\ao Heading to \ay'..place..'\ao.')
            home.go(neigh, plot)
            utils.cleanup()
            mq.delay(1000)

            count = count + utils.putReal(plotPutList[place])

            if plotRestackGrab[place] then

                utils.grabReal(plotRestackGrab[place])
                mq.delay(500)
                count = count + utils.putReal(plotRestackPut[place])
                plotRestackGrab[place] = nil
            end
        end
    end
end

--If restacking is required in any plots I have not yet visited, do so now.
if utils.listSize(plotRestackGrab) > 0 then
    for place,_ in pairs(plotRestackGrab) do
        local neigh, plot = string.match(place, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..place..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)

        utils.grabReal(plotRestackGrab[place])
        mq.delay(500)
        count = count + utils.putReal(plotRestackPut[place])
        plotRestackGrab[place] = nil
    end
end

if count > 0 then
    mq.cmdf('/dt %s \awDone with real estate. Stored \ay%s \awunique items.', settings.driver, count)
end

local stuck = false
local tryAgain = false
local function returnToStart()
    mq.cmdf('/travelto %s', startZone)
    print('\at[TsC]\ao Returning to \ay'..startZone..'\ao.')

    local startx, starty, endx, endy, diffx, diffy
    while mq.TLO.Navigation.Active() and mq.TLO.Zone.ShortName() == 'neighborhood' do
        startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
        mq.delay(5000)
        endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
        diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
        if diffx < 5 and diffy < 5 then
            stuck = true
        end
        while stuck == true do
            local function stop() return tryAgain end
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
            mq.delay(10000, stop)
        end
    end
end

local function binds()
    tryAgain = true
    stuck = false
    returnToStart()
end
mq.bind('/tsresume', binds)

returnToStart()

while mq.TLO.Zone.ShortName() ~= startZone do
    mq.delay(500)
end

mq.delay(2000)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc doneplots')
else
    local zone
    repeat --Make sure driver is available before sending done command
        mq.cmdf('/dquery %s -q Zone.ShortName', settings.driver)
        mq.delay(300)
        zone = mq.TLO.DanNet.Query()
        mq.delay(5000)
    until zone == startZone
    mq.delay(3000)
    mq.cmdf('/dex %s /tsc doneplots', settings.driver)
end
mq.unbind('/tsresume')