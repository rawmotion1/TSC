--- @type Mq
local mq = require('mq')
local utils = require('utils')

local args = {...}
local what = tonumber(args[1]) --41 for ts mats, 19 for collectibles

local me = mq.TLO.Me.Name()
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

--Look through matches to see what items I need to grab from bank before trading.
local shouldGrab
local grabList = {}
local function toGrab()
    for match,_ in pairs(matches[me]) do
        for item,_ in pairs(items) do
            if match == item then
                local inBank = false
                for _,location in pairs(items[item]['locations']) do
                    if string.match(location,"Bank") or string.match(location,"Personal") then
                        inBank = true
                    end
                end
                if inBank == true then
                    table.insert(grabList, match)
                    shouldGrab = true
                end
            end
        end
    end
end
toGrab()

for _,v in pairs(grabList) do
    print('\at[TsC]\ay '..v..'\ao needs to be picked up from the bank.')
end

--Send grablist to grab functino, 1 is normal mode, 2 is used by give mode where it needs to repeat until bank is empty
local count = 0
if shouldGrab == true then
    count = count + utils.grab(grabList, 1, what)
end

if count > 0 then
    mq.cmdf('/dgt %s \awDone grabbing from bank. Grabbed \ay%s \awunique items.', settings.driver, count)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donegrabbing')
else
    mq.cmdf('/dex %s /tsc donegrabbing', settings.driver)
end