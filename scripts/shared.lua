---@type Mq
local mq = require('mq')
local loc = require('TSC.plotlocations')

---@class Shared
local shared = {
    stuck = false,
    tryAgain = false,
    state = nil,
    TS = 44,
    CL = 21
}

local me = mq.TLO.Me.Name() -- Get the name of the current character

--Return the length of a table
function shared.tableLength(tbl)
    local count = 0
    tbl = tbl or {}
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--Check if the cursor is empty and if so, run autoinv
function shared.autoinv()
    while mq.TLO.Cursor() do
        mq.cmd('/autoinv')
        mq.delay(200)
    end
end

--Close all windows
function shared.cleanup()
    mq.cmd('/cleanup')
end

function shared.banker()
    local banker = mq.TLO.NearestSpawn('npc banker').Name()
    if banker == nil then
        banker = mq.TLO.NearestSpawn('banker').Name() --Look for personal bankers
        if banker == nil then
            print('\at[TsC]\ao No banker found in zone. Stopping.')
            return
        end
    end

    if mq.TLO.Spawn(banker).Distance() > 20 then
        mq.cmdf('/squelch /nav spawn %s', banker)
    end

    mq.delay(100)

    while mq.TLO.Navigation.Active() do
        if mq.TLO.Spawn(banker).Distance() <= 20 then
            mq.cmd('/squelch /nav stop')
            break
        end
    end

    while mq.TLO.Target.Name() ~= banker do
        mq.cmdf('/target %s', banker)
        mq.delay(100)
    end

    while not mq.TLO.Window('BigBankWnd').Open() do
        mq.cmd('/usetarget')
        mq.delay(100)
    end

    while not mq.TLO.Window('TradeskillDepotWnd').Open() do
        mq.cmd('/notify BigBankWnd BNK_TradeskillDepot leftmouseup')
        --Wait for items to load
        while not mq.TLO.TradeskillDepot.ItemsReceived() do mq.delay(1000) end
    end
end

--Load items in the find window
function shared.initFindWindow(itemType, scope)
    mq.cmd('/invoke ${Window[FindItemWnd].DoOpen}')
    mq.delay(100)
    --Reset defaults
    mq.cmd('/notify FindItemWnd FIW_Default leftmouseup')
    mq.delay(100)
    --Open depot window to refresh items
    mq.cmd('/invoke ${Window[TradeSkillDepotWnd].DoOpen}')
    --Wait for items to load
    while not mq.TLO.TradeskillDepot.ItemsReceived() do mq.delay(1000) end
    --Close depot window again
    mq.cmd('/invoke ${Window[TradeSkillDepotWnd].DoClose}')
    --Check the depot checkbox
    if not mq.TLO.Window('FindItemWnd').Child('FIW_SearchDepotButton').Checked() then
        mq.cmd('/notify FindItemWnd FIW_SearchDepotButton leftmouseup')
    end
    mq.delay(100)
    --Set item type
    mq.cmdf('/notify FindItemWnd FIW_ItemTypeCombobox listselect %s', itemType)
    mq.delay(100)
    --Set location to everywhere
    mq.cmdf('/notify FindItemWnd FIW_ItemLocationCombobox listselect %s', scope) --1 is everywhere, 2 is bank/depot
    mq.delay(100)
    --Click search
    mq.cmd('/notify FindItemWnd FIW_QueryButton leftmouseup')
    mq.delay(1000)
end

--Handles mq.cmd(f) for the current toon or other toons, deciding to use /dex or not
function shared.execute(who, command)
    --Only if the command contains a variable
    if string.find(command, '%${') then
        if who == me then
            mq.cmdf('/docommand %s', command)
        else
            mq.cmdf('/noparse /dex %s /docommand %s', who, command)
        end
    --If the command does not contain a variable, we can use /dex to send it to other toons
    else
        if who == me then
            mq.cmd(command)
        else
            mq.cmdf('/dex %s %s', who, command)
        end
    end
end

function shared.goToNeighborhood(neigh)
    local guildhallzonesbyID = {
        [345] = true, -- "Guild Hall"
        [737] = true, -- "Palatial Guild Hall"
        [738] = true, -- "Grand Guild Hall"
        [751] = true, -- "Modest Guild Hall"
    }
    if guildhallzonesbyID[mq.TLO.Zone.ID()] == true and mq.TLO.Ground.Search('Shabby Lobby Door')() and mq.TLO.Navigation.PathExists('item Shabby Lobby Door')() then
        mq.cmd('/nav item Shabby Lobby Door')
        while mq.TLO.Navigation.Active() do
            mq.delay(1000)
        end
        mq.cmd("/click right item")
        mq.delay(1000)
        mq.cmdf('/squelch /notify "Open the door to the lobby" menuselect')
        while mq.TLO.Zone.ShortName() ~= 'guildlobby' do
            mq.delay(500)
        end
    elseif mq.TLO.Zone.ShortName() ~= 'guildlobby' then
        mq.cmd('/travelto guildlobby')
        while mq.TLO.Zone.ShortName() ~= 'guildlobby' do
            mq.delay(500)
        end
    end
    if mq.TLO.Zone.ShortName() == 'guildlobby' then
        --Run to gate, select neghborhood, and zone in
        mq.cmd('/squelch /nav loc 969 293 -18')
        while mq.TLO.Navigation.Active() do
            mq.delay(1000)
        end
        while not mq.TLO.Window('RealEstateNeighborHoodWnd').Open() do
            mq.cmd('/doortarget id 38')
            mq.delay(100)
            mq.cmd('/click left door')
            mq.delay(1000)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowNonGuild_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowNonGuild_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowGuild_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowGuild_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowFullPPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowFullPPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowOpenPPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowOpenPPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowFullGPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowFullGPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowOpenGPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowOpenGPlots_Btn leftmouseup')
            mq.delay(300)
        end
        mq.cmd('/notify RealEstateNeighborHoodWnd RENW_MyPlots_Button leftmouseup')
        mq.delay(3000)
        local listSize = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').Items()
        for i=1, listSize do
            local location = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').List(i,1)()
            mq.delay(300)
            if location == neigh then
                mq.cmdf('/notify RealEstateNeighborHoodWnd RENW_NeighborhoodList listselect %s', i)
                break
            end
        end
        mq.delay(500)
        mq.cmd('/notify RealEstateNeighborHoodWnd RENW_Go_Button leftmouseup')
        while mq.TLO.Zone.ShortName() ~= 'neighborhood' do
            mq.delay(500)
        end
    end
end

function shared.navToSpring(address)
    shared.state = 'spring'
    mq.cmd('/squelch /nav locxy 1943 -2779')
    local startx, starty, endx, endy, diffx, diffy
    while mq.TLO.Navigation.Active() and mq.TLO.Zone.ShortName() == 'neighborhood' do
        startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
        mq.delay(5000)
        endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
        diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
        if diffx < 5 and diffy < 5 then
            shared.stuck = true
        end
        while shared.stuck == true do
            local function stop() return shared.tryAgain end
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
            mq.delay(10000, stop)
        end
    end

    while not mq.TLO.Window('RealEstatePlotSearchWnd').Open() do
        mq.cmd('/doortarget id 132')
        mq.delay(500)
        mq.cmd('/click left door')
        mq.delay(1000)
    end
    if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowPlayer_Btn').Checked() then
        mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowPlayer_Btn leftmouseup')
        mq.delay(300)
    end
    if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowGuild_Btn').Checked() then
        mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowGuild_Btn leftmouseup')
        mq.delay(300)
    end
    if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowOwned_Btn').Checked() then
        mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowOwned_Btn leftmouseup')
        mq.delay(300)
    end
    if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowVacant_Btn').Checked() then
        mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowVacant_Btn leftmouseup')
        mq.delay(300)
    end
    local listSize = mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_PlotList').Items()
    for i=1, listSize do
        local location = mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_PlotList').List(i,2)()
        if string.match(location, address) then
            mq.cmdf('/notify RealEstatePlotSearchWnd REPSW_PlotList listselect %s', i)
            break
        end
    end
    mq.delay(500)
    mq.cmd('/notify RealEstatePlotSearchWnd REPSW_Go_Btn leftmouseup')
    mq.delay(1000)
    while mq.TLO.Me.Moving() do
        mq.delay(1000)
    end
end

function shared.navToPlot(x, y)
    shared.state = 'plot'
    if mq.TLO.Math.Distance(y..','..x)() > 20 then
        mq.cmdf('/squelch /nav locxy %s', address)
    end
    local startx, starty, endx, endy, diffx, diffy
    while mq.TLO.Navigation.Active() do
        startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
        mq.delay(5000)
        endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
        diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
        if diffx < 5 and diffy < 5 then
            shared.stuck = true
        end
        while shared.stuck == true do
            local function stop() return shared.tryAgain end
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
            mq.delay(10000, stop)
        end
    end
end

function shared.goToAddress(address)
    local coords = loc[address]
    local x,y = string.match(coords, '([^,]+),%s([^,]+)')
    x, y = tonumber(x), tonumber(y)
    local myX, myY = mq.TLO.Me.X(), mq.TLO.Me.Y()
    local disToSpringX, disToSpringY = math.abs(myX - 1943), math.abs(myY + 2779)
    local disToSpring = disToSpringX + disToSpringY
    local disToPlotX, disToPlotY = math.abs(myX - x), math.abs(myY - y)
    local disToPlot = disToPlotX + disToPlotY

    if disToPlot > disToSpring then
        shared.navToSpring(address)
    else
        shared.navToPlot(x, y)
    end

    --Make sure I am standing IN the plot
    local square = {
        [1] = {
            ['x'] = x + 10,
            ['y'] = y
        },
        [2] = {
            ['x'] = x - 10,
            ['y'] = y
        },
        [3] = {
            ['x'] = x,
            ['y'] = y  - 10
        },
        [4] = {
            ['x'] = x,
            ['y'] = y  + 10
        },
    }
    if not mq.TLO.Window('RealEstatePurchaseWnd').Open() then
        mq.TLO.Window('RealEstatePurchaseWnd').DoOpen()
    end
    mq.delay(3000)
    if not mq.TLO.Window('RealEstatePurchaseWnd').Child('REPW_Manage_Button').Enabled() then
        for _,pair in pairs(square) do
            mq.cmdf('/squelch /nav locxy %s %s', pair['x'], pair['y'])
            mq.delay(3000)
            if mq.TLO.Window('RealEstatePurchaseWnd').Child('REPW_Manage_Button').Enabled() then break end
        end
    end
end

function shared.returnZone(startZone)
    shared.state = 'return'

    mq.cmdf('/travelto %s', startZone)
    print('\at[TsC]\ao Returning to \ay'..startZone..'\ao.')

    local startx, starty, endx, endy, diffx, diffy
    while mq.TLO.Navigation.Active() and mq.TLO.Zone.ShortName() == 'neighborhood' do
        startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
        mq.delay(5000)
        endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
        diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
        if diffx < 5 and diffy < 5 then
            shared.stuck = true
        end
        while shared.stuck == true do
            local function stop() return shared.tryAgain end
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
            mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
            mq.delay(10000, stop)
        end
    end

    local currentZone
    while currentZone  ~= startZone do
        currentZone = mq.TLO.Zone.ShortName()
        currentZone = currentZone:gsub('_int$', '')
        mq.delay(500)
    end
end

-- Helper functions for checking if plot items are not no-drop, etc
function shared.getInventory()
    local inventory = {}
    for i=23, 32 do
        local bagSize = mq.TLO.Me.Inventory(i).Container()
        if bagSize and bagSize ~= 0 then
            for j=1, bagSize do
                if mq.TLO.Me.Inventory(i).Item(j)() then
                    inventory[i..'-'..j] = mq.TLO.Me.Inventory(i).Item(j)()
                else
                    inventory[i..'-'..j] = 'empty'
                end
            end
        else
            inventory[tostring(i)] = mq.TLO.Me.Inventory(i)() or 'empty'
        end
    end
    return inventory
end

function shared.findTableDifference(table1, table2)
    for k,v in pairs(table1) do
        if table2[k] ~= v then
            return k
        end
    end
end

-- Parse plots and organize by plot address and room type
function shared.parsePlotString(plotString)
    local neighborhood, plotAddress, roomType = plotString:match("([^,]+),%s([^,]+),%s([^,]+)")
    local room = roomType:find("Room") and "Room" or (roomType:find("Crate") and "Crate" or nil)
    return neighborhood, plotAddress, room
end

-- Function to pick up items from the plot
function shared.pickUpItemsFromPlot(tbl, qty)
    local totalGrabbed = 0 -- Track total grabbed in this function

    while not mq.TLO.Window('RealEstateItemsWnd').Open() do
        mq.TLO.Window('RealEstateItemsWnd').DoOpen()
        mq.delay(100)
    end

    local listSize = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').Items()

    -- Iterate list backwards so order isn't modified
    for i = listSize, 1, -1 do
        local row = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i, 2)()
        local loc = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i, 5)()
        local stackSize = tonumber(mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i, 4)())

        mq.cmdf('/notify RealEstateItemsWnd REIW_ItemList listselect %s', i)

        for item, _ in pairs(tbl) do
            if row == item then

                local qtyToGrab = qty and (qty - totalGrabbed) or nil

                if mq.TLO.Me.FreeInventory() > 0 then
                    print('\at[TsC]\ao Found \ay'..item..'\ao in row '..i)

                    repeat
                        if mq.TLO.Me.FreeInventory() <= 0 then
                            print('\at[TsC]\ao No free inventory space!!! Ending early.')
                            return totalGrabbed -- Return total grabbed so far
                        end

                        local beforeInventory = shared.getInventory() -- Scan inventory

                        if qtyToGrab and qtyToGrab <= stackSize then

                            mq.cmd('/notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')

                            repeat
                                mq.cmdf('/notify QuantityWnd QTYW_slider newvalue %s', qtyToGrab)
                                mq.delay(100)
                            until mq.TLO.Window('QuantityWnd').Child('QTYW_SliderInput').Text() == tostring(qtyToGrab)

                            mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')

                            mq.delay(1000)

                            shared.autoinv()
                            totalGrabbed = totalGrabbed + qtyToGrab
                            qtyToGrab = 0 -- All required quantity grabbed
                        else
                            local grabAmount = math.min(stackSize, qtyToGrab or stackSize)
                            mq.cmd('/notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')

                            repeat
                                mq.cmdf('/notify QuantityWnd QTYW_slider newvalue %s', grabAmount)
                                mq.delay(100)
                            until mq.TLO.Window('QuantityWnd').Child('QTYW_SliderInput').Text() == tostring(grabAmount)

                            mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')

                            mq.delay(1000)
                            totalGrabbed = totalGrabbed + grabAmount
                            if qtyToGrab then
                                qtyToGrab = qtyToGrab - grabAmount
                            end
                        end

                        local skip = false

                        local afterInventory = shared.getInventory() -- Scan inventory again after grabbing an item
                        local invLoc = shared.findTableDifference(beforeInventory, afterInventory) -- See if there are any new items

                        if invLoc then -- If there are new items, do some checks
                            local bag, slot = string.match(invLoc, "(%d+)-(%d+)")
                            if slot then
                                bag = tonumber(bag) - 22
                                bag = tostring(bag)
                                local item = mq.TLO.InvSlot('pack'..bag).Item.Item(slot)
                                if item.NoDrop() or item.Lore() or item.Container() > 0 or not item.Stackable() then
                                    skip = true
                                end
                            else
                                local item = mq.TLO.InvSlot(invLoc).Item
                                if item.NoDrop() or item.Lore() or item.Container() > 0 or not item.Stackable() then
                                    skip = true
                                end
                            end
                        end

                        if skip == true then -- Wrong item, put it back where it came from
                            print('\at[TsC]\ao That\'s not right... Putting \ay'..item..'\ao back in your plot.')
                            if invLoc then
                                local bag, slot = string.match(invLoc, "(%d+)-(%d+)")
                                if slot then
                                    mq.cmdf('/itemnotify in pack%s %s leftmouseup', bag, slot)
                                else
                                    mq.cmdf('/itemnotify %s leftmouseup', invLoc)
                                end
                            end
                            if string.match(loc, 'Crate') then
                                mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup')
                            else
                                mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup')
                            end
                        end

                    until mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i, 2)() ~= item or skip == true or (qtyToGrab and qtyToGrab <= 0)

                else
                    print('\at[TsC]\ao Found \ay'..item..'\ao in row '..i..'\ay but my inventory is full!')
                    return totalGrabbed
                end
            end
        end
        mq.delay(10)
    end
    shared.cleanup()
    return totalGrabbed -- Return total grabbed
end

-- Function to deposit items into a plot
function shared.depositItemsToPlot(tbl, neigh, plotAddress)
    shared.cleanup()
    while not mq.TLO.Window('RealEstateItemsWnd').Open() do
        mq.TLO.Window('RealEstateItemsWnd').DoOpen()
        mq.delay(100)
    end

    mq.cmd('/keypress OPEN_INV_BAGS') -- Doesn't work without bags open

    for item, destination in pairs(tbl) do
        local neighborhood, plot, room = shared.parsePlotString(destination)
        if plot == plotAddress and neighborhood == neigh and mq.TLO.FindItemCount('='..item)() > 0 then
            print('\at[TsC]\ao Putting \ay'..item..' \aoin your '..room..'.')
            shared.autoinv()
            local id = mq.TLO.FindItem('='..item).ID() or 0
            local full = false

            repeat
                if mq.TLO.FindItemCount('='..item)() > 0 then
                    mq.cmdf('/itemnotify #%d leftmouseup', id)
                    if room == 'Crate' then
                        local tries = 0
                        while mq.TLO.Window('RealEstateItemsWnd').Child('REIW_Move_Crate_Button').Enabled() == false and tries < 6 do
                            tries = tries + 1
                            mq.delay(1000)
                        end

                        if mq.TLO.Window('RealEstateItemsWnd').Child('REIW_Move_Crate_Button').Enabled() == true then
                            mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup')
                        else
                            print('\at[TsC]\ao Uh oh, it appears your\ar '..room..' \ao is full!')
                            full = true
                        end
                    else
                        local tries = 0
                        while mq.TLO.Window('RealEstateItemsWnd').Child('REIW_Move_Closet_Button').Enabled() == false and tries < 6 do
                            tries = tries + 1
                            mq.delay(1000)
                        end

                        if mq.TLO.Window('RealEstateItemsWnd').Child('REIW_Move_Closet_Button').Enabled() == true then
                            mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup')
                        else
                            print('\at[TsC]\ao Uh oh, it appears your\ar '..room..' \ao is full!')
                            full = true
                        end
                    end
                end
                mq.delay(500)
            until mq.TLO.FindItemCount('='..item)() == 0 or full == true
        end
    end
    shared.cleanup()
end

function shared.putInDepot(depotList, checkSize)
    shared.cleanup()
    shared.banker()

    local mouseLocX = mq.TLO.Window('TradeskillDepotWnd').X() + (mq.TLO.Window('TradeskillDepotWnd').Width() / 2)
    local mouseLocY = mq.TLO.Window('TradeskillDepotWnd').Y() + (mq.TLO.Window('TradeskillDepotWnd').Height() / 2)

    for item in pairs(depotList) do

        shared.autoinv()

        if mq.TLO.FindItemCount('='..item)() and mq.TLO.FindItemCount('='..item)() > 0 then
            print('\at[TsC]\ao Putting \ay'..item..' \aoin your depot.')
            if checkSize == false or mq.TLO.TradeskillDepot.Count() < mq.TLO.TradeskillDepot.Capacity() then
                local skip = false
                repeat
                    if mq.TLO.TradeskillDepot.FindItemCount('='..item)() >= 99999 then
                        print('\at[TsC]\ao Your depot can\'t hold any more \ay'..item..'.')
                        break
                    end

                    local id = mq.TLO.FindItem('='..item).ID()
                    repeat
                        mq.cmdf('/shift /itemnotify #%d leftmouseup', id)
                        mq.delay(100)
                        if mq.TLO.Cursor() and not mq.TLO.Cursor.ID() == id then
                            shared.autoinv()
                        end
                        if mq.TLO.FindItemCount(id)() == 0 then
                            skip = true
                            break
                        end
                    until mq.TLO.Cursor.ID() == id

                    if not skip and mq.TLO.Cursor.Tradeskills() and mq.TLO.Cursor.Stackable() and not mq.TLO.Cursor.Lore() and not mq.TLO.Cursor.NoDrop() and not mq.TLO.Cursor.Attuneable() then

                        mq.cmd('/foreground self.Name')

                        local attempts = 0
                        while mq.TLO.Cursor() do
                            while not mq.TLO.TradeskillDepot.ItemsReceived() do mq.delay(1000) end
                            mq.cmdf('/mouseto %s %s', mouseLocX, mouseLocY)
                            mq.delay(100)
                            mq.cmd('/click left')
                            if mq.TLO.Window('ConfirmationDialogBox')() then
                                mq.cmd('/no') --Avoid accidentally dropping items on the ground
                            end
                            mq.delay(1000)

                            attempts = attempts + 1
                            if attempts > 9 then
                                shared.tryAgain = false
                                while shared.tryAgain == false do
                                    mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \aycan\'t depost. Be sure no Lua windows are obstructing their depot window.', mq.TLO.Me.Name())
                                    mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Type \ag/tsresume\ay from the stuck toon\'s EQ window to try again.')
                                    local function stop()
                                        return shared.tryAgain
                                    end
                                    mq.delay(10000, stop)
                                    if shared.tryAgain == true then attempts = 0 end
                                end
                            end
                        end

                    else
                        skip = true
                        shared.autoinv()
                    end

                until mq.TLO.FindItemCount('='..item)() == 0 or skip == true
            else
                print('\at[TsC]\ao Tradeskill depot is full!.')
                shared.cleanup()
                return true -- Depot is full
            end
        end
        mq.delay(500)
    end
    shared.cleanup()
end

function shared.putInBank(tbl, tbl2, itemType)
    if tbl and shared.tableLength(tbl) > 0 then
        print('\at[TsC]\ao Putting items in the bank.')

        --Go to banker and open bank window
        shared.banker()
        shared.autoinv()

        local full = false
        local function bankFull()
            full = true
        end
        mq.event('fullbank', '#*#You have no room left in the bank#*#', bankFull)

        --Put inventory items into bank
        for item in pairs(tbl) do
            if mq.TLO.FindItemCount('='..item)() and mq.TLO.FindItemCount('='..item)() > 0 then
                local id = mq.TLO.FindItem(item).ID()
                print('\at[TsC]\ao Putting \ay'..item..'\ao in the bank.')
                repeat
                    mq.cmdf('/shift /itemnotify #%d leftmouseup', id)
                    mq.delay(100)
                    mq.cmd('/notify BigBankWnd BNK_AutoButton leftmouseup')
                    mq.delay(100)
                    mq.doevents()
                    if full == true then
                        shared.cleanup()
                        shared.autoinv()
                        print('\at[TsC]\ao Bank is full! Stopping.')
                        return true -- Bank is full
                    end
                until not mq.TLO.FindItem('='..item).ID()
            end
        end
    end

    --If there are items to move from the bank to the depot, pick them up now
    if tbl2 and shared.tableLength(tbl2) > 0 then
        print('\at[TsC]\ao Grabbing items from bank that belong in depot.')
        mq.cmd('/invoke ${Window[FindItemWnd].DoOpen}')
        mq.delay(100)
        --Reset defaults
        mq.cmd('/notify FindItemWnd FIW_Default leftmouseup')
        mq.delay(100)
        --UNCHECK the depot checkbox
        if mq.TLO.Window('FindItemWnd').Child('FIW_SearchDepotButton').Checked() then
            mq.cmd('/notify FindItemWnd FIW_SearchDepotButton leftmouseup')
        end
        mq.delay(100)
        --Set item type
        mq.cmdf('/notify FindItemWnd FIW_ItemTypeCombobox listselect %s', itemType)
        mq.delay(100)
        --Set location to everywhere
        mq.cmdf('/notify FindItemWnd FIW_ItemLocationCombobox listselect %s', 2) --1 is everywhere, 2 is bank/depot
        mq.delay(100)
        --Click search
        mq.cmd('/notify FindItemWnd FIW_QueryButton leftmouseup')
        mq.delay(1000)

        local skippedItems = {} -- Track items that were put back
        for item, v in pairs(tbl2) do

            repeat
                if mq.TLO.Me.FreeInventory() <= 0 then
                    print('\at[TsC]\ao No free inventory space!!! Ending early.')
                    return true
                end

                local row = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('=' .. item, 2)()
                if not row or skippedItems[item] then break end

                print('\at[TsC]\ao Grabbing \ay'..item..'\ao from row '..row..' from the bank.')

                repeat
                    mq.cmdf('/notify FindItemWnd FIW_ItemList listselect %s', row)
                    mq.delay(100)
                    mq.cmd('/shift /notify FindItemWnd FIW_GrabButton leftmouseup')
                    mq.delay(200)
                until mq.TLO.Cursor() == item or not row

                mq.delay(100)

                if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                    print('\at[TsC]\ao That\'s not right... Putting \ay'..v..'\ao back in the bank.') -- Item with same name, but is not what I'm looking for
                    mq.cmd('/notify BigBankWnd BNK_AutoButton leftmouseup')
                    skippedItems[item] = true -- Mark the item as skipped to avoid infinite loop
                else
                    shared.autoinv()
                end

                mq.delay(200)
                row = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('=' .. item, 2)()
            until not row
        end
    end
    shared.cleanup()
end

function shared.tradeItems(tbl, dest, qty)
    local countTo8 = 0
    mq.cmdf('/dobserve %s -q Me.FreeInventory', dest)
    mq.delay(500)
    for item in pairs(tbl) do
        if mq.TLO.FindItemCount('='..item)() and mq.TLO.FindItemCount('='..item)() > 0 then
            mq.cmd('/keypress OPEN_INV_BAGS')
            mq.cmd('/squelch /lua parse mq.TLO.Window("InventoryWindow").DoOpen()')

            local id = mq.TLO.FindItem('='..item).ID()
            local totalGiven = 0
            local qtyToGive = qty and (qty - totalGiven) or nil
            local inv = mq.TLO.FindItemCount('='..item)()
            local stackSize = mq.TLO.FindItem('='..item).StackSize()

            if qtyToGive and qtyToGive <= stackSize then
                print('\at[TsC]\ao Giving \ay'..item..' \aoto \ar'..dest)
                while not mq.TLO.Cursor() do
                    mq.cmdf('/itemnotify #%s leftmouseup', id)
                    mq.delay(200)

                    mq.cmdf('/notify QuantityWnd QTYW_slider newvalue %s', qty)
                    mq.delay(200)

                    mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')
                    mq.delay(200)

                    if mq.TLO.Cursor() and not mq.TLO.Cursor.ID() == id then
                        shared.autoinv()
                        mq.delay(200)
                    end
                    if not mq.TLO.FindItemCount('='..item)() then
                        break
                    end
                    if mq.TLO.Cursor() and mq.TLO.Cursor.ID() == id then
                        break
                    end
                end
                mq.delay(200)
                if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                    shared.autoinv()
                    mq.delay(200)
                    shared.cleanup()
                    break
                else
                    while mq.TLO.Cursor() do
                        if mq.TLO.Target.Name() ~= dest then
                            while not mq.TLO.Target.Name() do
                                mq.cmdf('/target "=%s"', dest)
                                mq.delay(200)
                                if mq.TLO.Target.Name() == dest then
                                    break
                                end
                            end
                        end
                        mq.cmd('/usetarget')
                        mq.delay(500)
                    end
                    mq.delay(300)
                end
                repeat
                    mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                    mq.delay(100)
                    mq.cmdf('/dex %s /squelch /notify TradeWnd TRDW_Trade_Button leftmouseup', dest)
                    mq.delay(300)
                until not mq.TLO.Window('TradeWnd').Open()
                shared.cleanup()
                return
            else
                repeat
                    if mq.TLO.FindItemCount('='..item)() and mq.TLO.FindItemCount('='..item)() > 0 then
                        if countTo8 == 0 then
                            if not mq.TLO.DanNet(dest).O('Me.FreeInventory')() then
                                mq.cmdf('/dobserve %s -q Me.FreeInventory', dest)
                                mq.delay(500)
                            end
                            if tonumber(mq.TLO.DanNet(dest).O('Me.FreeInventory')()) < 8 then
                                print('\at[TsC]\ao Uh oh, it appears \ar'..dest..' \ay is low on inventory space!')
                                return true
                            end
                        end
                        print('\at[TsC]\ao Giving \ay'..item..' \aoto \ar'..dest)
                        local grabAmount = math.min(stackSize, qtyToGive or stackSize)
                        grabAmount = math.min(grabAmount, inv)

                        while not mq.TLO.Cursor() do
                            mq.cmdf('/itemnotify #%s leftmouseup', id)
                            mq.delay(200)
                            if mq.TLO.Cursor() and not mq.TLO.Cursor.ID() == id then
                                shared.autoinv()
                                mq.delay(200)
                            end
                            if mq.TLO.Window('QuantityWnd')() then
                                mq.cmdf('/notify QuantityWnd QTYW_slider newvalue %s', grabAmount)
                                mq.delay(200)
                                mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')
                                mq.delay(200)
                            end
                            if mq.TLO.Cursor() and not mq.TLO.Cursor.ID() == id then
                                shared.autoinv()
                                mq.delay(200)
                            end
                            if not mq.TLO.FindItemCount('='..item)() then
                                break
                            end
                            if mq.TLO.Cursor() and mq.TLO.Cursor.ID() == id then
                                break
                            end
                        end

                        local given = mq.TLO.CursorAttachment.Quantity()
                        totalGiven = totalGiven + given
                        qtyToGive = qty and (qtyToGive - given) or nil

                        mq.delay(200)
                        if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                            shared.autoinv()
                            mq.delay(200)
                            shared.cleanup()
                            break
                        else
                            while mq.TLO.Cursor() do
                                if mq.TLO.Target.Name() ~= dest then
                                    while not mq.TLO.Target.Name() do
                                        mq.cmdf('/target "=%s"', dest)
                                        mq.delay(200)
                                        if mq.TLO.Target.Name() == dest then
                                            break
                                        end
                                    end
                                end
                                mq.cmd('/usetarget')
                                mq.delay(500)
                            end
                            mq.delay(300)
                        end
                        mq.delay(300)
                        countTo8 = countTo8 + 1
                        if countTo8 == 8 then --if tradewindow is full, give
                            repeat
                                mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                                mq.delay(100)
                                mq.cmdf('/dex %s /squelch /notify TradeWnd TRDW_Trade_Button leftmouseup', dest)
                                mq.delay(500)
                            until not mq.TLO.Window('TradeWnd').Open()
                            countTo8 = 0
                        end
                    end
                until (totalGiven and qtyToGive and totalGiven >= qty) or totalGiven >= inv
            end
        end
    end

    repeat
        mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
        mq.delay(100)
        mq.cmdf('/dex %s /squelch /notify TradeWnd TRDW_Trade_Button leftmouseup', dest)
        mq.delay(500)
    until not mq.TLO.Window('TradeWnd').Open()
    shared.cleanup()
end

return shared