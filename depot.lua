--- @type Mq
local mq = require('mq')
local utils = require('utils')

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
        print('Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to depot...')
mq.delay(1000)


local shouldDepot
local shouldMove

local depotList = {}
local bankToDepotList = {}

--Create list of items in inventory and depot, but not in bank
--Create list of items in bank and depot, but not in inventory
local function toMove()
    for item,_ in pairs(items) do
        local bank = false
        local inventory = false
        local depot = false
        for _,v in pairs(items[item]['locations']) do
            if string.match(v, "Bank") then
                bank = true
            end
            if string.match(v, "General") then
                inventory = true
            end
            if string.match(v, "Personal") then
                depot = true
            end
        end
        if inventory == true and bank == false and depot == true then
            table.insert(depotList, item)
            shouldDepot = true
        elseif bank == true and depot == true then
            table.insert(bankToDepotList, item)
            shouldMove = true
        end
    end
end
toMove()

local count = 0
local move = 0

if mq.TLO.TradeskillDepot.Enabled() then
    if shouldDepot == true then
        count = count + utils.depot(depotList, false) --False tells depot function not to worry about depot capacity since it's just adding to existing items
    end

    if shouldMove == true then
        move = move + utils.bankToDepot(bankToDepotList)
    end
else
    print('\at[TsC]\ay Personal depot is not enabled on this toon.')
end

mq.cmdf('/dgt \ar%s \awdone with depot. Placed \ay%s \awunique items from inventory and \ay%s \awfrom bank into the depot.', me, count, move)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donedepot')
else
    mq.cmdf('/dex %s /tsc donedepot', settings.driver)
end