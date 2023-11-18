--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()

local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

local settings = {}
local items = {}

local function loadFiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        print('\at[TsC]\ao Error loading settings.lua')
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local allItems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('\at[TsC]\ao Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allItems then
        items = allItems()
    end
end
loadFiles()


--If in more than one plot location, find winner
local function findHighestValueKey(tbl)
    local highestKey = nil
    local highestValue = -math.huge

    for key, value in pairs(tbl) do
        if value > highestValue then
            highestKey = key
            highestValue = value
        end
    end
    return highestKey
end

---Self-consolidate logic tree on whatever is left
local consolidate = {}

for item, stuff in pairs(items) do
    if stuff.locations <= 1 then
        if utils.listSize(stuff.inventory) == 0 then
            --Already consolidated
        else
            stuff.destination = 'Leftovers'
        end
    else
        if stuff.depot > 0 then
            stuff.destination = 'Depot'
        else
            if utils.listSize(stuff.bank) > 0 and utils.listSize(stuff.plots) > 0 then
                if settings.preferPlots == true then
                    stuff.destination = findHighestValueKey(stuff.plots)
                else
                    stuff.destination = 'Bank'
                end
            elseif utils.listSize(stuff.plots) > 0 then
                stuff.destination = findHighestValueKey(stuff.plots)
            elseif utils.listSize(stuff.bank) > 0 then
                if utils.listSize(stuff.inventory) > 0 then
                    stuff.destination = 'Bank'
                else
                    stuff.destination = 'BankRestack'
                end
            else
                stuff.destination = 'Leftovers'
            end
        end
    end
    --Anything blank is already consolidated
    if stuff.destination ~= '' then
        if not consolidate[me] then
            consolidate[me] = {}
        end
        consolidate[me][item] = stuff.destination
        if utils.listSize(stuff.plots) > 0 then
            consolidate[me]['Real Estate'] = true
        end
    end
end

local lconsol = 0
if consolidate[me] then
    for _,dest in pairs(consolidate[me]) do
        if dest ~= true and dest ~= 'Leftovers' then
            lconsol = lconsol + 1
        end
    end
end

mq.pickle(consolPath, consolidate)
mq.pickle(itemsPath, items)




mq.cmdf('/dt %s \awDone identifying moves. Found \ag%s \awitems that need to be moved.', settings.driver, lconsol)
if settings.driver == me then
    mq.cmd('/tsc donematching')
else
    mq.cmdf('/dex %s /tsc donematching', settings.driver)
end