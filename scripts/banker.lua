---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

--Load data
local lists = cm.loadData('lists')
local combinedItems = cm.loadData('combined')

local args = {...}
local itemType
if args[1] == 'Tradeskill' then itemType = 42 else itemType = 20 end


-- Main real estate function. Manage moving between plots, grabbing items, and depositing them
local function putInPlots()
    print('\at[TsC]\ao Putting items in real estate plots.')

    local placesToVisit = {}
    local placesToVisit2 = {}
    local toDeposit = {}
    local toPickup = {}
    local toMove = {}

    --Items that need to be be moved
    if lists.tomoveplot and lists.tomoveplot[me] then
        for item, _ in pairs(lists.tomoveplot[me]) do
            for plot, _ in pairs(combinedItems[me][item].plots or {}) do
                if plot ~= combinedItems[me][item]['destination'] then
                    local neighborhood, plotAddress, _ = shared.parsePlotString(plot)
                    placesToVisit[neighborhood] = placesToVisit[neighborhood] or {}
                    placesToVisit[neighborhood][plotAddress] = true
                    toPickup[item] = true
                end
            end
        end
    end

    --Places those items need to be moved to
    if lists.tomoveplot and lists.tomoveplot[me] then
        for item, _ in pairs(lists.tomoveplot[me]) do
            local destination = combinedItems[me][item]['destination']
            local neighborhood, destPlot, _ = shared.parsePlotString(destination)
            placesToVisit2[neighborhood] = placesToVisit2[neighborhood] or {}
            placesToVisit2[neighborhood][destPlot] = true
            toMove[item] = destination
        end
    end

    --Items that just need to be deposited
    if lists.toplot and lists.toplot[me] then
        for item, plot in pairs(lists.toplot[me]) do
            if mq.TLO.FindItem('=' .. item)() then
                local neighborhood, plotAddress, _ = shared.parsePlotString(plot)
                placesToVisit[neighborhood] = placesToVisit[neighborhood] or {}
                placesToVisit[neighborhood][plotAddress] = true
                toDeposit[item] = plot
            end
        end
    end

    local currentNeighborhood = nil
    -- First round: Visit each plot to grab and deposit items
    for neighborhood, plots in pairs(placesToVisit) do
        print('\at[TsC]\ao Traveling to neighborhood: ' .. neighborhood)
        if neighborhood ~= currentNeighborhood then
            shared.goToNeighborhood(neighborhood)
            currentNeighborhood = neighborhood
        end
        for plotAddress, _ in pairs(plots) do
            print('\at[TsC]\ao Traveling to plot address: ' .. plotAddress)
            shared.goToAddress(plotAddress)
            shared.pickUpItemsFromPlot(toPickup)
            shared.depositItemsToPlot(toDeposit, neighborhood, plotAddress)
        end
    end

    -- Second round: Visit each plot to deposit 'move' items
    for neighborhood, plots in pairs(placesToVisit2) do
        if neighborhood ~= currentNeighborhood then
            print('\at[TsC]\ao Traveling to neighborhood: ' .. neighborhood)
            shared.goToNeighborhood(neighborhood)
            currentNeighborhood = neighborhood
        end
        for plotAddress, _ in pairs(plots) do
            print('\at[TsC]\ao Traveling to destination plot address: ' .. plotAddress)
            shared.goToAddress(plotAddress)
            shared.depositItemsToPlot(toMove, neighborhood, plotAddress)
        end
    end
end

local startZone = mq.TLO.Zone.ShortName()
startZone = startZone:gsub("_int$", "")

local function binds()
    shared.tryAgain = true
    shared.stuck = false
    if shared.state == 'spring' then                                                                                                                                                
        shared.navToSpring()
    elseif shared.state == 'plot' then
        shared.navToPlot()
    elseif shared.state == 'return' then
        shared.returnZone(startZone)
    end
end
mq.bind('/tsresume', binds)

--Decide if I should run the real estate function
local function shouldReal()
    if lists.toplot and lists.toplot[me] then
        for item in pairs(lists.toplot[me]) do
            if mq.TLO.FindItem('=' .. item)() then
                return true -- I have items in my inventory that need to be put in plots
            end
        end
    end
    --Or, I haven't been to the plots yet, but I have items to move
    if lists.tomoveplot[me] and shared.tableLength(lists.tomoveplot[me]) > 0 then
        return true
    end
end

if shouldReal() then
    putInPlots()
    shared.cleanup()
end

--Return to original zone from neighborhood
local currentZone = mq.TLO.Zone.ShortName()
currentZone = currentZone:gsub("_int$", "")
if startZone ~= currentZone then shared.returnZone(startZone) mq.delay(3000) end


if (lists.tobank[me] and shared.tableLength(lists.tobank[me]) > 0) or (lists.tomovedepot[me] and shared.tableLength(lists.tomovedepot[me]) > 0) then
    shared.putInBank(lists.tobank[me], lists.tomovedepot[me], itemType)
    shared.cleanup()
end

shared.execute(cm.settings.driver, '/tsc donebanking')

mq.unbind('/tsresume')