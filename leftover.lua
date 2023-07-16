--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local movePath = 'TSC/tmp/movetable.lua'
local artisanPath = 'TSC/artisan.lua'

local settings = {}
local toons = {}
local moveTable = {}
local artList = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
    if toonError then
        mq.exit()
    elseif loadToons then
        toons = loadToons()
    end

    local movefile, moveerror = loadfile(mq.configDir..'/'..movePath)
    if moveerror then
        print('Error loading movetable.lua')
        mq.exit()
    elseif movefile then
        moveTable = movefile()
    end

    local loadArt, artError = loadfile(mq.configDir..'/'..artisanPath)
    if artError then
        --Nothing
    elseif loadArt then
        artList = loadArt()
    end
end
loadfiles()

print('\at[TsC]\ao Attempting to store leftover items...')
mq.delay(1000)

local storeList = moveTable[me]['rest']

local bankCount
local depotCount
local muleCount = 0

local rest --Where should I store leftover items?
for _,toon in pairs(toons) do
    if toon.name == me then
        rest = toon.leftovers
        break
    end
end

local firstRun = true
local muleList = {}
local thisTradeCount
local function giveToMules(previousMule)

    if firstRun == true then
        --Prevent artisan from giving away artisan items by removing them from list
        if settings.artisan == me then
            for index,item in pairs(storeList) do
                for _,artitem in pairs(artList) do
                    if item == artitem then
                        storeList[index] = nil
                    end
                end
            end
        end

        --Convert storeList to muleList for utils.tradeNew to understand
        for _,item in pairs(storeList) do
            muleList[item] = ''
        end
        firstRun = false
    end

    local mule = nil
    for _,toon in pairs(settings.mules) do
        if toon.name ~= me and toon.name ~= previousMule and mq.TLO.NearestSpawn('='..toon.name)() then mule = toon.name break end
    end

    if mule then

        thisTradeCount, muleList, full = utils.tradeNew(mule, muleList, false)
        muleCount = muleCount + thisTradeCount

        if full == true then --Target's inventory is full, cancel any repeats.
            print('\at[TsC] \ar'..mule..' \ay is out of inventory space! Moving to next mule...')
            giveToMules(mule)
        end

    else
        print('\at[TsC]\ao Can\'t find any (more) mules. Make sure you defined mules in \aysettings.lua\ao, they\'re in-zone, and have free space.')
    end
end

if rest == 'Depot > Bank > Mules' then
    if mq.TLO.TradeskillDepot.Enabled() then
        depotCount, storeList = utils.depot(storeList)
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
    end
    bankCount, storeList = utils.bank(storeList)
    giveToMules()
elseif rest == 'Depot > Bank' then
    if mq.TLO.TradeskillDepot.Enabled() then
        depotCount, storeList = utils.depot(storeList)
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
    end
    bankCount, storeList = utils.bank(storeList)

elseif rest == 'Depot > Mules' then
    if mq.TLO.TradeskillDepot.Enabled() then
        depotCount, storeList = utils.depot(storeList)
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
    end
    giveToMules()
elseif rest == 'Bank > Mules' then
    bankCount, storeList = utils.bank(storeList)
    giveToMules()
elseif rest == 'Bank' then
    bankCount, storeList = utils.bank(storeList)
elseif rest == 'Mules' then
    giveToMules()
end

if bankCount == nil then bankCount = 0 end
if depotCount == nil then depotCount = 0 end

if bankCount > 0 or depotCount > 0 then
    mq.cmdf('/dt %s \awDone with leftovers. Dumped \ay%s \awremaining items into the bank/depot and \ay%s \awonto mules.', settings.driver, bankCount+depotCount, muleCount)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donerest')
else
    mq.cmdf('/dex %s /tsc donerest', settings.driver)
end