---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

--Load data
local lists = cm.loadData('lists')

print('\at[TsC]\ao Attempting to store leftover items...')
mq.delay(1000)

local storeList = lists.todump[me] or {}

--Where should I store leftover items?
local rest = cm.toons[me].leftovers

local function binds()
    shared.tryAgain = true
end
mq.bind('/tsresume', binds)


local firstRun = true
local muleList = {}
-- Put mules in order
for mule, order in pairs(cm.mules) do
    muleList[order] = mule
end

local function giveToMules(previousMule)
    local mule = nil
    for _, toon in ipairs(muleList) do
        if toon ~= me and toon ~= previousMule and mq.TLO.NearestSpawn('='..toon)() then 
            mule = toon
            break
        end
    end

    if mule then
        local full = false
        full = shared.tradeItems(storeList, mule)

        if full == true then --Target's inventory is full, cancel any repeats.
            print('\at[TsC] \ar'..mule..' \ay is out of inventory space! Moving to next mule...')
            giveToMules(mule)
        end
    else
        print('\at[TsC]\ao Can\'t find any (more) mules. Make sure you defined mules in \aysettings.lua\ao, they\'re in-zone, and have free space.')
    end
end

local depotIsFull = false
local bankIsFull = false
if rest == 'Depot > Bank > Mules' then
    if mq.TLO.TradeskillDepot.Enabled() then
        if shared.tableLength(storeList) > 0 then
            depotIsFull = shared.putInDepot(storeList)
        end
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
        depotIsFull = true
    end
    if depotIsFull then
        bankIsFull = shared.putInBank(storeList)
    end
    if bankIsFull then
        giveToMules()
    end
elseif rest == 'Depot > Bank' then
    if mq.TLO.TradeskillDepot.Enabled() then
        if shared.tableLength(storeList) > 0 then
           depotIsFull = shared.putInDepot(storeList)
        end
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
        depotIsFull = true
    end
    if depotIsFull then
        bankIsFull = shared.putInBank(storeList)
    end
elseif rest == 'Depot > Mules' then
    if mq.TLO.TradeskillDepot.Enabled() then
        if shared.tableLength(storeList) > 0 then
            depotIsFull = shared.putInDepot(storeList)
        end
    else
        print('\at[TsC]\ay Personal depot is not enabled on this toon.')
        depotIsFull = true
    end
    if depotIsFull then
        giveToMules()
    end
elseif rest == 'Bank > Mules' then
    if shared.tableLength(storeList) > 0 then
        bankIsFull = shared.putInBank(storeList)
    end
    if bankIsFull then
        giveToMules()
    end
elseif rest == 'Bank' then
    if shared.tableLength(storeList) > 0 then
        shared.putInBank(storeList)
    end
elseif rest == 'Mules' then
    if shared.tableLength(storeList) > 0 then
        giveToMules()
    end
end

shared.execute(cm.settings.driver, '/tsc donerest')
--Tell init that this script is done
