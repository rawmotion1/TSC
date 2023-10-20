--- @type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('home')

local args = {...}
local what = tonumber(args[1]) --41 for ts mats, 19 for collectibles

local me = mq.TLO.Me.Name()
local startZone = mq.TLO.Zone.ShortName()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local matchesPath = 'TSC/tmp/matches.lua'

local settings = {}
local items = {}
local matches = {}

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

    local allmatches, matcherror = loadfile(mq.configDir..'/'..matchesPath)
    if matcherror then
        print('\at[TsC]\ao Error loading matches.lua')
        mq.exit()
    elseif allmatches then
        matches = allmatches()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items I need to grab...')
mq.delay(1000)

local shouldGrab
local shouldReal
local grabList = {}
local realList = {}
local plots = {}

--Look through matches to see what items I need to grab from bank/depot/plots before trading.
local function toGrab()
    if matches[me] then
        for match,_ in pairs(matches[me]) do
            for item,stuff in pairs(items) do
                if match == item then

                    local inBank = false
                    local inReal = false

                    if stuff.depot > 0 or utils.listSize(stuff.bank) > 0 then
                        inBank = true
                    end

                    if settings.includePlots == true then
                        if utils.listSize(stuff.plots) > 0 then
                            inReal = true
                            --Keep track of plots items are in
                            for plot,_ in pairs(stuff.plots) do
                                local place = string.match(plot, "^([^,]+,[^,]+)")
                                local skip = false
                                for k,v in pairs(plots) do
                                    if v == place then skip = true end
                                end
                                if skip == false then
                                    table.insert(plots,place)
                                end
                            end
                        end
                    end

                    if inBank == true then
                        table.insert(grabList, match)
                        shouldGrab = true
                    end
                    if inReal == true then
                        table.insert(realList, match)
                        shouldReal = true
                    end
                    mq.delay(100)
                end
            end
        end
    end
end
toGrab()

local count = 0
local thisCount
if shouldGrab == true then
    for _,v in pairs(grabList) do
        print('\at[TsC]\ay '..v..'\ao needs to be picked up from the bank.')
    end

    --Grab from bank/depot items to give to others
    thisCount = utils.grab(grabList, what)

    count = count + thisCount
    utils.cleanup()
end

local newCount
if shouldReal == true then
    for _,v in pairs(realList) do
        print('\at[TsC]\ay '..v..'\ao needs to be picked up from your plot.')
    end

    for _,v in pairs(plots) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)

        --Grab items from plot to give to others
        newCount = utils.grabReal(realList)

        count = count + newCount
        utils.cleanup()
    end
end

if count > 0 then
    mq.cmdf('/dgt %s \awDone grabbing. Grabbed \ay%s \awunique items.', settings.driver, count)
end

if shouldReal then
    mq.cmdf('/travelto %s', startZone)
    print('\at[TsC]\ao Returning to \ay'..startZone..'\ao.')
    while mq.TLO.Zone.ShortName() ~= startZone do
        mq.delay(500)
    end
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donegrabbing')
else
    mq.cmdf('/dex %s /tsc donegrabbing', settings.driver)
end