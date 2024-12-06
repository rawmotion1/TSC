--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

local settings = {}
local items = {}
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

    local consolidate, consolerror = loadfile(mq.configDir..'/'..consolPath)
    if consolerror then
        print('\at[TsC]\ao Error loading consolidate.lua')
        mq.exit()
    elseif consolidate then
        consol = consolidate()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to depot...')
mq.delay(1000)


local depotList = {}
local bankToDepotList = {}

for item, dest in pairs(consol[me]) do
    if dest == 'Depot' then
        if utils.listSize(items[item]['bank']) > 0 then
            table.insert(bankToDepotList, item)
        else
            table.insert(depotList, item)
        end
    end
end

local count = 0
local move = 0

local function binds()
    utils.resume = true
end
mq.bind('/tscontinue', binds)

if mq.TLO.TradeskillDepot.Enabled() then
    if utils.listSize(depotList) > 0 then
        count = count + utils.depot(depotList, false) --False tells depot function not to worry about depot capacity since it's just adding to existing items
    end
    if utils.listSize(bankToDepotList) > 0 then
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

mq.unbind('/tscontinue')