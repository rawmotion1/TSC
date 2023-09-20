--- @type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('plot')

local args = {...}
local what = tonumber(args[1]) --41 for ts mats, 19 for collectibles

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local matchesPath = 'TSC/tmp/matches.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

local settings = {}
local items = {}
local matches = {}
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

    local allmatches, matcherror = loadfile(mq.configDir..'/'..matchesPath)
    if matcherror then
        print('\at[TsC]\ao Error loading matches.lua')
        mq.exit()
    elseif allmatches then
        matches = allmatches()
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

print('\at[TsC]\ao Looking for items I need to grab...')
mq.delay(1000)

--Look through matches to see what items I need to grab from bank before trading.
local shouldGrab
local shouldReal
local grabList = {}
local realList = {}
local plots = {}
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

                    if utils.listSize(stuff.plots) > 0 then
                        inReal = true

                        --Keep track of different plots I own
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


--If I'm going to neighborhood, add items that need to be moved to and from real estate so we can grab them now instead of later
if settings.includePlots == true and shouldReal == true then
    for item,dest in pairs(consol[me]) do

        if dest == "Plots" and utils.listSize(items[item]['bank']) > 0 then
            table.insert(grabList, item)
            mq.delay(100)
        elseif (dest == "Depot" or dest == "Bank") and utils.listSize(items[item]['plots']) > 0 then
            table.insert(realList, item)
            mq.delay(100)

            --Again keep track of plots I own
            for plot,_ in pairs(items[item]['plots']) do
                local place = string.match(plot, "^([^,]+,[^,]+)")
                local skip2 = false
                for k,v in pairs(plots) do
                    if v == place then skip2 = true end
                end
                if skip2 == false then
                    table.insert(plots,place)
                end
                mq.delay(100)
            end
        end
    end
end

for _,v in pairs(grabList) do
    print('\at[TsC]\ay '..v..'\ao needs to be picked up from the bank.')
end


--Send grablist to grab functinon
local count = 0
local thisCount
if shouldGrab == true then
    thisCount = utils.grab(grabList, what)
    count = count + thisCount
    utils.cleanup()
end

for _,v in pairs(realList) do
    print('\at[TsC]\ay '..v..'\ao needs to be picked up from your plot.')
end

--Send plotlist to grab functino, 1 is normal mode, 2 is used by give mode where it needs to repeat until bank is empty
local startZone = mq.TLO.Zone.ShortName()
local newCount

if shouldReal == true then
    for k,v in pairs(plots) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        newCount = utils.grabReal(realList)
        count = count + newCount
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