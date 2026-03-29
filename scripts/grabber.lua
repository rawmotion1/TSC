---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

-- Set observer on driver to track what zone they are in
mq.cmdf('/dobserve %s -q Zone.ShortName', cm.settings.driver)

local args = {...}

local itemType
if args[1] == 'Tradeskill' then itemType = shared.TS else itemType = shared.CL end

--If QTY arg is passed, assume we have just 1 item to grab QTY of
local qty = args[2] or nil
if qty then qty = tonumber(qty) end

--Load data
local lists = cm.loadData('lists')
local combinedItems = cm.loadData('combined')

local function grabFromBank()
    print('\at[TsC]\ao Grabbing items from the bank/depot.')

    --Go to banker and open bank window
    shared.banker()

    --Make sure nothing is in my hands
    shared.autoinv()

    --Load items in the find window
    shared.initFindWindow(itemType, 2) -- 2 is bank/depot
    local skippedItems = {} -- Track items that were put back
    local totalGrabbed = 0 -- Track total grabbed across calls

    for item, _ in pairs(lists.tograb[me]) do
        local qtyToGrab = qty and (qty - totalGrabbed) or nil

        repeat
            if mq.TLO.Me.FreeInventory() <= 0 then
                print('\at[TsC]\ao No free inventory space!!! Ending early.')
                return totalGrabbed -- Return total grabbed so far
            end

            local row = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('=' .. item, 2)()
            if not row or skippedItems[item] then break end

            local inDepot
            if string.find(mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(row, 5)(), 'Personal') then
                inDepot = true
            end

            local stackSize = tonumber(mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(row, 3)())

            if not stackSize or stackSize == 0 then break end

            print('\at[TsC]\ao Grabbing \ay'..item..'\ao from row '..row..' in the bank/depot.')

            if qtyToGrab and qtyToGrab <= stackSize then
                local grabAmount = math.min(qtyToGrab, 1000)

                if inDepot then
                    local depotRow = mq.TLO.Window('TradeskillDepotWnd').Child('TD_Item_List').List('=' .. item, 2)()
                    repeat
                        mq.cmdf('/notify TradeskillDepotWnd TD_Item_List listselect %s', depotRow)
                        mq.delay(100)
                        mq.cmd('/notify TradeskillDepotWnd TD_Withdraw_Button leftmouseup')
                        mq.delay(200)
                    until mq.TLO.Window('QuantityWnd').Open()
                else
                    repeat
                        mq.cmdf('/notify FindItemWnd FIW_ItemList listselect %s', row)
                        mq.delay(100)
                        mq.cmd('/notify FindItemWnd FIW_GrabButton leftmouseup')
                        mq.delay(100)
                    until mq.TLO.Window('QuantityWnd').Open()
                end
                repeat
                    mq.cmdf('/notify QuantityWnd QTYW_slider newvalue %s', grabAmount)
                    mq.delay(100)
                until mq.TLO.Window('QuantityWnd').Child('QTYW_SliderInput').Text() == tostring(grabAmount)
                repeat
                    mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')
                    mq.delay(100)
                until mq.TLO.Cursor() == item
                
                totalGrabbed = totalGrabbed + grabAmount
                qtyToGrab = qtyToGrab - grabAmount
            else
                local grabAmount = math.min(stackSize, qtyToGrab or stackSize)

                if inDepot then
                    local depotRow = mq.TLO.Window('TradeskillDepotWnd').Child('TD_Item_List').List('=' .. item, 2)()
                    repeat
                        mq.cmdf('/notify TradeskillDepotWnd TD_Item_List listselect %s', depotRow)
                        mq.delay(100)
                        mq.cmd('/shift /notify TradeskillDepotWnd TD_Withdraw_Button leftmouseup')
                        mq.delay(200)
                    until mq.TLO.Cursor() == item or not depotRow
                else
                    repeat
                        mq.cmdf('/notify FindItemWnd FIW_ItemList listselect %s', row)
                        mq.delay(100)
                        mq.cmd('/shift /notify FindItemWnd FIW_GrabButton leftmouseup')
                        mq.delay(200)
                    until mq.TLO.Cursor() == item or not row
                end

                totalGrabbed = totalGrabbed + grabAmount
                if qtyToGrab then
                    qtyToGrab = qtyToGrab - grabAmount
                end
            end

            mq.delay(100)

            if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                print('\at[TsC]\ao That\'s not right... Putting \ay'..item..'\ao back in the bank.') -- Item with same name, but is not what I'm looking for
                mq.cmd('/notify BigBankWnd BNK_AutoButton leftmouseup')
                skippedItems[item] = true -- Mark the item as skipped to avoid infinite loop
            else
                shared.autoinv()
            end

            mq.delay(200)
            row = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('=' .. item, 2)()
        until not row or (qtyToGrab and qtyToGrab <= 0)
    end

    --Put bank restack items back in the bank
    for item, dest in pairs(lists.tograb[me]) do
        if dest == 'bankrestack' then
            local id = mq.TLO.FindItem(item).ID()
            print('\at[TsC]\ao Putting \ay'..item..'\ao back in the bank (restack).')
            repeat
                mq.cmdf('/shift /itemnotify #%d leftmouseup', id)
                mq.delay(100)
                mq.cmd('/notify BigBankWnd BNK_AutoButton leftmouseup')
                mq.delay(100)
            until not mq.TLO.FindItem(item).ID()
        end
    end
    shared.cleanup()
    return totalGrabbed -- Return total grabbed
end

-- Main real estate function. Manage moving between plots, grabbing items, and depositing them
local function grabFromPlots()
    print('\at[TsC]\ao Grabbing items from real estate plots.')

    local placesToVisit = {}
    local placesToVisit2 = {}
    local toPickup = {}
    local toDeposit = {}
    local toMove = {}

    -- Collect plots to visit for first round
    if lists.toplotgrab and lists.toplotgrab[me] then
        for item, _ in pairs(lists.toplotgrab[me]) do
            for plot, _ in pairs(combinedItems[me][item].plots or {}) do
                local neighborhood, plotAddress, _ = shared.parsePlotString(plot)
                placesToVisit[neighborhood] = placesToVisit[neighborhood] or {}
                placesToVisit[neighborhood][plotAddress] = true
                toPickup[item] = true
            end
        end
    end

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

    -- Collect destination plots for second round (depositing items that we picked up)
    if lists.tomoveplot and lists.tomoveplot[me] then
        for item, _ in pairs(lists.tomoveplot[me]) do
            local destination = combinedItems[me][item]['destination']
            local neighborhood, destPlot, _ = shared.parsePlotString(destination)
            placesToVisit2[neighborhood] = placesToVisit2[neighborhood] or {}
            placesToVisit2[neighborhood][destPlot] = true
            toMove[item] = destination
        end
    end

    -- Collect plots to deposit in for either round if I am going there anyway and have the item
    if lists.toplot and lists.toplot[me] then
        for item, plot in pairs(lists.toplot[me]) do
            if mq.TLO.FindItem('=' .. item)() then
                local neighborhood, plotAddress, _ = shared.parsePlotString(plot)
                if placesToVisit[neighborhood] then --Only add if I'm already going there
                    placesToVisit[neighborhood] = placesToVisit[neighborhood] or {}
                    placesToVisit[neighborhood][plotAddress] = true
                    toDeposit[item] = plot
                elseif placesToVisit2[neighborhood] then --Only add if I'm already going there
                    placesToVisit2[neighborhood] = placesToVisit2[neighborhood] or {}
                    placesToVisit2[neighborhood][plotAddress] = true
                    toDeposit[item] = plot
                end
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
            shared.pickUpItemsFromPlot(toPickup, qty)
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


-- Main bank grab script execution
if lists.tograb[me] then
    if qty then
        qty = qty - grabFromBank() -- Grab items from the bank/depot
    else
        grabFromBank() -- Grab items from the bank/depot
    end
    shared.cleanup()
end

-- Main plot grab script execution
local beenToPlots = false
if lists.toplotgrab[me] and (qty == nil or qty > 0) then
    grabFromPlots() -- Grab items from real estate plots
    shared.cleanup()
    beenToPlots = true
end

--Return to original zone from neighborhood
local currentZone = mq.TLO.Zone.ShortName()
currentZone = currentZone:gsub("_int$", "")
if startZone ~= currentZone then shared.returnZone(startZone) mq.delay(3000) end

-- Tell driver we are done grabbing
if cm.settings.driver ~= me then
    local driverZone = ''
    repeat --Make sure driver is available before sending done command
        driverZone = mq.TLO.DanNet(cm.settings.driver).O('Zone.ShortName')() or ''
        driverZone = driverZone:gsub("_int$", "")
        mq.delay(3000)
    until driverZone == startZone
    mq.delay(200)
    shared.execute(cm.settings.driver, '/tsc donegrabbing '..me)
else
    mq.cmd('/tsc donegrabbing '..me)
end

if beenToPlots then
    -- Tell init to empty this toon's tomoveplot list so it doesn't try to move items again
    shared.execute(cm.settings.driver, '/tsc beentoplots ' .. me)
end

mq.unbind('/tsresume')

shared.cleanup()




