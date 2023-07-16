--- @type Mq
local mq = require('mq')
local utils = require('utils')

local args = {...} 
local name = args[1] --receiver
local scope = tonumber(args[2]) --4 for inventory, 1 for everything
local what = tonumber(args[3]) -- 41 for mats, 19 for collectibles

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'

local settings = {}
local items = {}

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
end
loadfiles()


local shouldGrab
local grabList = {}
local grabListSize = 0
if scope == 1 then --if all mode, create list of things to grab
    for item,_ in pairs(items) do
        local inBank = false
        for _,location in pairs(items[item]['locations']) do
            if string.match(location,"Bank") or string.match(location,"Personal") then
                inBank = true
            end
        end
        if inBank == true then
            table.insert(grabList, item)
            shouldGrab = true
            grabListSize = grabListSize + 1
        end
    end
end


local mustRepeat
local thisTradeCount
local tradeCount = 0
local function give()
    if scope == 1 then
        local grabCount

        if shouldGrab == true then
            grabCount, grabList = utils.grab(grabList, 2, what) --2:give mode, means it will return the reduced grabList after each grab

            if grabCount < grabListSize then --My inventory was full and I couldn't grab everything. I will have to repeat the cycle.
                grabListSize = grabListSize - grabCount
                mustRepeat = true
            else --I grabbed everything. No need for further repetitions.
                shouldGrab = false
                mustRepeat = false
            end
        end
    end

    thisTradeCount, items, full = utils.tradeNew(name, items, false)
    tradeCount = tradeCount + thisTradeCount
    
    if full == true then --Target's inventory is full, cancel any repeats.
        mustRepeat = false
    end

    if mustRepeat == true then
        give()
    end
end
give()

mq.cmdf('/dt %s \awDone giving. Gave away \ay%s \awunique items.', settings.driver, tradeCount)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donegiving')
else
    mq.cmdf('/dex %s /tsc donegiving', settings.driver)
end

