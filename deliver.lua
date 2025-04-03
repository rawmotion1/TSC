--- @type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('home')
local returnZone = require('return')

local args = {...}

local receiver = args[1]
local item = args[2]
local qty = tonumber(args[3])
local what = tonumber(args[4]) -- 42 for mats, 20 for collectibles

local me = mq.TLO.Me.Name()
local startZone = mq.TLO.Zone.ShortName()

local items = {}
local receiverItems = {}
local settings = {}


local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local receiverPath = 'TSC/tmp/allitems_'..receiver..'.lua'
local settingPath = 'TSC/settings.lua'


local function loadfiles()
    local allitems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('\at[TsC]\ao Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end
    local recItems, recItemerror = loadfile(mq.configDir..'/'..receiverPath)
    if recItemerror then
        print('\at[TsC]\ao Error loading allitems_'..receiver..'.lua')
        mq.exit()
    elseif recItems then
        receiverItems = recItems()
    end
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        print('\at[TsC]\ao Error loading settings.lua')
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end
end
loadfiles()

local tradeList = {[item] = 0}
local grabList = {[1] = item}

----Where is the item stored?
local inventory = 0
local bank = 0
local depot = 0
local plots = 0

for _,v in pairs (items[item]['inventory']) do
    inventory = inventory + v
end

for _,v in pairs (items[item]['bank']) do
    bank = bank + v
end

depot = items[item]['depot']

local plotLocations = {} --Every plot location that contains the item

for plot,q in pairs (items[item]['plots']) do
    plots = plots + q
    local place = string.match(plot, "^([^,]+,[^,]+)")
    local skip = false
    for _,loc in pairs(plotLocations) do
        if loc == place then skip = true end
    end
    if skip == false then
        table.insert(plotLocations,place)
    end
end

----------------------------

local function updateResults() --Update search results after trading
    if receiverItems[item] then
        receiverItems[item]['total'] = receiverItems[item]['total'] + qty
    else
        receiverItems[item] = {
            ['bank'] = {},
            ['inventory'] = {},
            ['plots'] = {},
            ['depot'] = 0,
            ['total'] = qty,
            ['locations'] = 1,
            ['destination'] = '',
        }
    end
    items[item]['total'] = items[item]['total'] - qty
    mq.pickle(itemsPath, items)
    mq.pickle(receiverPath, receiverItems)
    mq.cmd('/squelch /lua run TSC/search')
end

local case
local qtyToGrab
if inventory >= qty then
    case = 1 --just give
elseif inventory + bank + depot >= qty then
    case = 2 --grab from bank/depot then give
    qtyToGrab = qty - inventory
elseif inventory + plots >= qty then
    case = 3 --grab from plots then give
    qtyToGrab = qty - inventory
elseif inventory + bank + depot + plots >= qty then
    case = 4 --grab from plots and bank/depot then give
    qtyToGrab = qty - bank - depot - inventory --grab all from plots and what's left from bank
end

if case == 1 then
    utils.trade(receiver, tradeList, qty)
    updateResults()
elseif case == 2 then
    utils.grab(grabList, what, 2, qtyToGrab)
    utils.trade(receiver, tradeList)
    updateResults()
elseif case == 3 then
    mq.cmdf('/dt %s \awHeading to Sunrise Hills.', settings.driver)
    print('\at[TsC]\ay '..item..'\ao needs to be picked up from your plot.')
    local fromRealQty = qtyToGrab
    for _,v in pairs(plotLocations) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        local qtyGrabbed = utils.grabReal(grabList, fromRealQty) --Only grab what is needed
        fromRealQty = fromRealQty - qtyGrabbed
        utils.cleanup()
        if fromRealQty <= 0 then break end
    end
    if startZone ~= mq.TLO.Zone.ShortName() then returnZone.go(startZone) end
    utils.trade(receiver, tradeList)
    updateResults()
elseif case == 4 then
    mq.cmdf('/dt %s \awHeading to Sunrise Hills.', settings.driver)
    print('\at[TsC]\ay '..item..'\ao needs to be picked up from your plot.')

    for _,v in pairs(plotLocations) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        utils.grabReal(grabList) --Grab all
        utils.cleanup()
    end
    if startZone ~= mq.TLO.Zone.ShortName() then returnZone.go(startZone) end
    utils.grab(grabList, what, 2, qty - plots) --Only grab what is needed
    utils.trade(receiver, tradeList)
    updateResults()
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donedelivering')
else
    mq.cmdf('/dex %s /tsc donedelivering', settings.driver)
end