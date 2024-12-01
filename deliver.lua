--- @type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('home')

local args = {...}

local receiver = args[1]
local item = args[2]
local qty = tonumber(args[3])
local what = tonumber(args[4]) -- 41 for mats, 19 for collectibles

local me = mq.TLO.Me.Name()
local startZone = mq.TLO.Zone.ShortName()

local items = {}
local settings = {}

local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local settingPath = 'TSC/settings.lua'

local function loadfiles()
    local allitems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('\at[TsC]\ao Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end
end
loadfiles()

local all = false
if qty == items[item]['total'] then all = true end

local tradeList = {[item] = 0}
local grabList = {[1] = item}

----Where is the item stored?
local inventory = 0
for k,v in pairs (items[item]['inventory']) do
    inventory = inventory + v
end

local plotLocations = {}
local plots = 0
for plot,q in pairs (items[item]['plots']) do
    plots = plots + q --total qty across plots
    local place = string.match(plot, "^([^,]+,[^,]+)")
    local skip = false
    for _,loc in pairs(plotLocations) do
        if loc == place then skip = true end
    end
    if skip == false then
        table.insert(plotLocations,place)
    end
end

local bank = 0
for k,v in pairs (items[item]['bank']) do
    bank = bank + v
end

local depot = items[item]['depot']

local bankDepot = bank + depot
----------------------------



local full
local mustRepeat
local invFull
local thisQty
local function give()
    _, _, invFull = utils.grab(grabList, what)
    if invFull == true and mq.TLO.FindItemCount('='..item)() < qty then --My inventory was full and I couldn't grab everything. I will have to repeat the cycle.
        mustRepeat = true
    else --I grabbed everything. No need for further repetitions.
        mustRepeat = false
    end
    thisQty = qty - mq.TLO.FindItemCount('='..item)()
    if all == true then
        _, _, full = utils.trade(receiver, tradeList)
    else
        _, _, full = utils.trade(receiver, tradeList, qty)
    end
    if full == true then --Target's inventory is full, cancel any repeats.
        mustRepeat = false
    end
    if mustRepeat == true then
        qty = thisQty
        tradeList = {[item] = 0}
        give()
    end
end


local stuck = false
local tryAgain = false
local function returnToStart()
    mq.cmdf('/travelto %s', startZone)
    print('\at[TsC]\ao Returning to \ay'..startZone..'\ao.')

    local startx, starty, endx, endy, diffx, diffy
    while mq.TLO.Navigation.Active() and mq.TLO.Zone.ShortName() == 'neighborhood' do
        startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
        mq.delay(5000)
        endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
        diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
        if diffx < 5 and diffy < 5 then
            stuck = true
        end
        while stuck == true do
            local function stop() return tryAgain end
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
            mq.delay(10000, stop)
        end
    end
    while mq.TLO.Zone.ShortName() ~= startZone do
        mq.delay(500)
    end
end

local function binds()
    tryAgain = true
    stuck = false
    returnToStart()
end
mq.bind('/tsresume', binds)




--Where should I grab it from? (cases)
if inventory >= qty then
    --just give qty to target
    if all == true then
        utils.trade(receiver, tradeList)
    else
        utils.trade(receiver, tradeList, qty)
    end
elseif (inventory + bankDepot) >= qty then
    --pick all from the bank, trade, return leftovers to bank
    give()
    if all == false then
        grabList = {[1] = item}
        if depot > 0 then
            utils.depot(grabList, false)
        else
            utils.bank(grabList)
        end
    end
elseif (inventory + plots) >= qty then
    --pick up qty - inventory from plots
    mq.cmdf('/dt %s \awHeading to Sunrise Hills.', settings.driver)
    print('\at[TsC]\ay '..item..'\ao needs to be picked up from your plot.')
    for _,v in pairs(plotLocations) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        --Grab items from plot to give to others
        utils.grabReal(grabList)
        utils.cleanup()
    end
    returnToStart()
    --Give qty to target
    if all == true then
        utils.trade(receiver, tradeList)
    else
        utils.trade(receiver, tradeList, qty)

        --now put leftovers back in plot
        local neigh, plot = string.match(plotLocations[1], "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..plotLocations[1]..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        local firstPlace = next(items[item]['plots'])
        local _, _, thisRoom = string.match(firstPlace, "([^,]+),%s([^,]+),%s([^,]+)")
        local myRoom = 'Closet'
        if string.match(thisRoom,'Crate') then myRoom = 'Crate' end
        local putList = {[item] = myRoom}
        utils.putReal(putList)
        returnToStart()
    end
elseif (inventory + bankDepot + plots) then
    --pickup all from bank and qty - (inventory + bankDepot) from plots
    give()
    grabList = {[1] = item}
    --pick up qty - inventory from plots
    mq.cmdf('/dt %s \awHeading to Sunrise Hills.', settings.driver)
    print('\at[TsC]\ay '..item..'\ao needs to be picked up from your plot.')
    for _,v in pairs(plotLocations) do
        local neigh, plot = string.match(v, "([^,]+),%s*([^,]+)")
        print('\at[TsC]\ao Heading to \ay'..v..'\ao.')
        home.go(neigh, plot)
        utils.cleanup()
        mq.delay(1000)
        --Grab items from plot to give to others
        utils.grabReal(grabList)
        utils.cleanup()
    end
    returnToStart()
    --Give qty to target
    if all == true then
        utils.trade(receiver, tradeList)
    else
        utils.trade(receiver, tradeList, thisQty)
        --now return leftovers to bank
        grabList = {[1] = item}
        if depot > 0 then
            utils.depot(grabList, false)
        else
            utils.bank(grabList)
        end
    end
end




--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donedelivering')
else
    mq.cmdf('/dex %s /tsc donedelivering', settings.driver)
end