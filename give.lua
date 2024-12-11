--- @type Mq
local mq = require('mq')
local utils = require('utils')

local args = {...}
local name = args[1] --receiver
local what = tonumber(args[2]) -- 41 for mats, 19 for collectibles
local bank = args[3]
local depot = args[4]

if bank == 'true' then bank = true end
if depot == 'true' then depot = true end

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local toonPath = 'TSC/toons.lua'
local artisanPath = 'TSC/artisan.lua'

local settings = {}
local items = {}

local toons = {}
local artList = {}
local isArtisan = false
local artisan

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

    local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
    if toonError then
        print('\at[TsC]\ao Error loading toons.lua')
        mq.exit()
    elseif loadToons then
        toons = loadToons()
    end

    local loadArt, artError = loadfile(mq.configDir..'/'..artisanPath)
    if artError then
        --Nothing
    elseif loadArt then
        for _,toon in pairs(toons) do
            if toon.name == settings.artisan then
                isArtisan = true
                artisan = settings.artisan
                artList = loadArt()
            end
        end
    end
end
loadfiles()

if utils.listSize(items) == 0 then
    mq.cmdf('/dt %s \awNothing to give away.', settings.driver)
    --Tell init that this script is done
    if settings.driver == me then
        mq.cmd('/tsc donegiving')
    else
        mq.cmdf('/dex %s /tsc donegiving', settings.driver)
    end
    mq.exit()
end

--Remove artisan items from list
if isArtisan == true and artisan == me then
    for _,v in pairs(artList) do
        for l,_ in pairs(items) do
            if l == v then
                items[l] = nil
            end
        end
    end
end

local full
local shouldGrab
local grabList = {}
local grabListSize = 0
if bank == true or depot == true then
    for item,stuff in pairs(items) do
        if utils.listSize(stuff['bank']) > 0 or stuff['depot'] > 0 then
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
    if shouldGrab == true then
        local grabCount


        grabCount, grabList = utils.grab(grabList, what)

        if grabCount < grabListSize then --My inventory was full and I couldn't grab everything. I will have to repeat the cycle.
            grabListSize = grabListSize - grabCount
            mustRepeat = true
        else --I grabbed everything. No need for further repetitions.
            shouldGrab = false
            mustRepeat = false
        end

    end

    thisTradeCount, items, full = utils.trade(name, items)
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

