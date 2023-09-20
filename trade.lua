--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local matchesPath = 'TSC/tmp/matches.lua'

local settings = {}
local toons = {}
local matches = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local loadToons, toonerror = loadfile(mq.configDir..'/'..toonPath)
    if toonerror then
        print('\at[TsC]\ao Error loading toons.lua')
        mq.exit()
    elseif loadToons then
        toons = loadToons()
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

print('\at[TsC]\ao Looking for items to give away...')
mq.delay(1000)

--Create tradelist in format that utils.newTrade can understand
local tradeList = {}
for _,toon in pairs(toons) do
    for item,receiver in pairs(matches[me]) do
        if toon.name ~= me and toon.name == receiver then
            if not tradeList[receiver] then
                tradeList[receiver] = {}
            end
            tradeList[receiver][item] = ''
        end
    end
end

--Send one toon's tradelist to function at a time
local count = 0
local thisCount = 0
local tradedItems
for receiver,_ in pairs(tradeList) do
    thisCount, tradedItems = utils.tradeNewest(receiver, tradeList[receiver])
    count = count + thisCount

    local items = {} --Load receiver's items
    local allitems, itemerror = loadfile(mq.configDir..'/TSC/tmp/allitems_'..receiver..'.lua')
    if itemerror then
        print('Error loading allitems_'..receiver..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end

    --Add traded items to receiver's item list so we don't have to rescan them
    for _,item in pairs(tradedItems) do
        if utils.listSize(items[item]['inventory']) < 1 then
            items[item]['inventory']['General'] = 1
        end
    end
    mq.pickle(mq.configDir..'/TSC/tmp/allitems_'..receiver..'.lua', items)
end

if count > 0 then
    mq.cmdf('/dgt %s \awDone trading. Gave away \ay%s \awunique items.', settings.driver, count)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donetrading')
else
    mq.cmdf('/dex %s /tsc donetrading', settings.driver)
end