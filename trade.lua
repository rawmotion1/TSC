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

--Create tradelist in format thar utils.newTrade can understand
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
mq.pickle('TSC/tmp/tradeList.lua', tradeList)

--Send one toon's tradelist to function at a time
local count = 0
for receiver,_ in pairs(tradeList) do
    count = count + utils.tradeNew(receiver, tradeList[receiver], true)
end

mq.cmdf('/dgt \ar%s \awdone trading. Gave away \ay%s \awunique items.', me, count)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donetrading')
else
    mq.cmdf('/dex %s /tsc donetrading', settings.driver)
end