--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local movePath = 'TSC/tmp/movetable.lua'

local settings = {}
local moveTable = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local movefile, moveerror = loadfile(mq.configDir..'/'..movePath)
    if moveerror then
        print('Error loading movetable.lua')
        mq.exit()
    elseif movefile then
        moveTable = movefile()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to depot...')
mq.delay(1000)

local function listSize(list)
    local n = 0
    for _,item in pairs(list) do
        if not string.match(item, 'be skipped') then
            n = n + 1
        end
    end
    return n
end

local depotList = moveTable[me]['todepot']
local bankToDepotList = moveTable[me]['tomove']

local count = 0
local move = 0

local function binds()
    utils.resume = true
end
mq.bind('/tsresume', binds)

if mq.TLO.TradeskillDepot.Enabled() then
    if listSize(depotList) > 0 then
        count = count + utils.depot(depotList, false) --False tells depot function not to worry about depot capacity since it's just adding to existing items
    end
    if listSize(bankToDepotList) > 0 then
        move = move + utils.bankToDepot(bankToDepotList)
    end
else
    print('\at[TsC]\ay Personal depot is not enabled on this toon.')
end

if count > 0 or move > 0 then
    mq.cmdf('/dt %s \awDone with depot. Placed \ay%s \awunique items from inventory and \ay%s \awfrom bank into the depot.', settings.driver, count, move)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donedepot')
else
    mq.cmdf('/dex %s /tsc donedepot', settings.driver)
end
