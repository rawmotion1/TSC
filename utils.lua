--- @type Mq
local mq = require('mq')

local utils = {}

function utils.loadFindWindow(where, what) --Where: 1=all 2=bank 4=inventory, what: 41 is ts mats 19 is collectibles
    mq.cmd('/invoke ${Window[FindItemWnd].DoOpen}')
    mq.delay(300)
    mq.cmd('/notify FindItemWnd FIW_Default leftmouseup')
    mq.delay(300)
    mq.cmdf('/notify FindItemWnd FIW_ItemLocationCombobox listselect %s', where)
    mq.delay(300)
    mq.cmdf('/notify FindItemWnd FIW_ItemTypeCombobox listselect %s', what)
    mq.delay(300)
    if not mq.TLO.Window('FindItemWnd').Child('FIW_SearchDepotButton').Checked() then
        mq.cmd('/notify FindItemWnd FIW_SearchDepotButton leftmouseup')
        mq.delay(300)
    end
    mq.cmd('/notify FindItemWnd FIW_QueryButton leftmouseup')
    mq.delay(3500)
end

function utils.cleanup()
    mq.cmd('/cleanup')
end

function utils.autoinv()
    while mq.TLO.Cursor() do
        mq.cmd('/autoinv')
        mq.delay(200)
    end
end

--Loc: fw=find window, inv=inventory
function utils.pickup(item, loc)
    repeat
        if loc == 'fw' then mq.cmd('/shift /notify FindItemWnd FIW_GrabButton leftmouseup') else mq.cmdf('/shift /itemnotify \"%s\" leftmouseup', item) end
        mq.delay(100)
    until mq.TLO.Cursor() == item or mq.TLO.Window('QuantityWnd').Open()
    if mq.TLO.Window('QuantityWnd').Open() then
        repeat
            mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')
            mq.delay(100)
        until mq.TLO.Cursor() == item
    end
end

function utils.navTarget(name)
    utils.cleanup()
    local target = mq.TLO.NearestSpawn(name)()
    if target == nil then
        print('\at[TsC]\ao Target not found in zone. Stopping.')
        return
    end
    if mq.TLO.Spawn(target).Distance() > 20 then
        mq.cmdf('/squelch /nav spawn %s', target)
    end
    mq.delay(100)
    while mq.TLO.Spawn(target).Distance() > 20 do
        if mq.TLO.Spawn(target).Distance() <= 20 then
            mq.cmd('/squelch /nav stop')
            break
        end
    end
    while mq.TLO.Target.Name() ~= target do
        mq.cmdf('/target %s', target)
        mq.delay(100)
    end
end

function utils.banker()
    local banker = mq.TLO.NearestSpawn('npc banker').Name()
    if banker == nil then
        banker = mq.TLO.NearestSpawn('banker').Name() --Look for personal bankers
        if banker == nil then
            print('\at[TsC]\ao No banker found in zone. Stopping.')
            return
        end
    end

    utils.navTarget(banker)

    while not mq.TLO.Window('BigBankWnd').Open() do
        mq.cmd('/usetarget')
        mq.delay(100)
    end

    while not mq.TLO.Window('TradeskillDepotWnd').Open() do
        mq.cmd('/notify BigBankWnd BIGB_TradeskillDepot leftmouseup')
        mq.delay(100)
    end
end

--where: 1=all 2=bank 4=inventory, ignore: ignorelist, items: results to be returned, what mats or collectibles
function utils.scan(where, ignore, items, what)
    utils.cleanup()
    utils.loadFindWindow(where, what)

    local listSize = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').Items()

    local countSlots = 0
    local countItems = 0

    for i=1, listSize do
        local name = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)()
        local location = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,4)()

        local skip = false
        for _,v in pairs(ignore) do
            if v == name then skip = true end
        end

        local item
        if string.match(location, "General") then item = mq.TLO.FindItem('='..name)
        elseif string.match(location, "Bank") then item = mq.TLO.FindItemBank('='..name)
        elseif string.match(location, "Personal") then item = mq.TLO.TradeskillDepot.FindItem('='..name)
        else skip = true
        end

        if skip == false then
            if item.NoDrop() or item.Container() ~= 0 or not item.Stackable() then
                skip = true
            end
        end

        if skip == false then
            local inv = mq.TLO.FindItemCount('='..name)() or 0
            local bnk = mq.TLO.FindItemBankCount('='..name)() or 0
            local dpt = mq.TLO.TradeskillDepot.FindItemCount('='..name)() or 0
            local total = inv + bnk + dpt
                if not items[name] then
                    items[name] = {}
                    items[name].totalQty = total
                    items[name]['locations'] = {}
                    table.insert(items[name]['locations'], location)
                    countSlots = countSlots + 1
                    countItems = countItems + 1
                else
                    table.insert(items[name]['locations'], location)
                    countSlots = countSlots + 1
                end
            print('\at[TsC]\ao Found \ay'..name)
        else
            print('\at[TsC]\ar Skipping \ay'..name)
        end
    end
    utils.cleanup()
    return countSlots, countItems
end


function utils.restack(item)
    print('\at[TsC]\ao Restacking \ay'..item)

    utils.autoinv()

    utils.pickup(item)

    utils.autoinv()
end


function utils.sortBags(items)
    utils.cleanup()
    local inv = {}

    print('\at[TsC]\ao Checking for items to restack...')

    --If multiple inventory stacks are less than max stack size, add it to inv table
    for item,_ in pairs(items) do
        for _,location in pairs(items[item]['locations']) do
            if string.match(location, "General") then
                local stacks = mq.TLO.FindItem('='..item).Stacks()
                if stacks > 1 then
                    local max = mq.TLO.FindItem('='..item).StackSize()
                    local qty
                    local dash = string.match(location, "-")
                    local bag = 0
                    local slot
                    if dash then
                        bag = tonumber(string.match(location, "%s%d+")) or 0
                        slot = tonumber(string.match(location, "%d+$"))
                        qty = mq.TLO.Me.Inventory(bag+22).Item(slot).Stack()
                    else
                        slot = tonumber(string.match(location, "%s%d+"))
                        qty = mq.TLO.Me.Inventory(slot+22).Stack()
                    end

                    if not inv[item] then
                        if qty < max then
                            inv[item] = stacks
                        else
                            inv[item] = 0
                        end
                    else
                        if qty == max then
                            inv[item] = 0
                        end
                    end
                end
            end
        end
    end

    --Checks inv table for places where the same item is in more than one spot
    for item, stacks in pairs(inv) do
        if stacks > 0 then
            for i=1, stacks-1 do
                utils.restack(item)
                --rescan = true
            end
        end
    end
    print('\at[TsC]\ao Done with restacking.')
    utils.cleanup()
end


function utils.grab(grabList, mode, what)
    utils.cleanup()
    utils.banker()
    utils.loadFindWindow(2, what) --2 is bank/depot only

    while not mq.TLO.Window('TradeskillDepotWnd').Open() do
        mq.cmd('/notify BigBankWnd BIGB_TradeskillDepot leftmouseup')
        mq.delay(100)
    end

    local listSize = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').Items()
    local count = 0

    --Iterate list backwards so order isn't modified
    for i=listSize, 1, -1 do
        local row = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)()
        mq.cmdf('/notify FindItemWnd FIW_ItemList listselect %s', i)
        for k,v in pairs(grabList) do
            if row == v then
                if mq.TLO.Me.FreeInventory() > 0 then
                    print('\at[TsC]\ao Found \ay'..v..'\ao in row '..i)

                    repeat

                        utils.autoinv()
                        mq.delay(100)

                        utils.pickup(v, 'fw')
                        mq.delay(100)

                        while mq.TLO.Cursor() == v do
                            utils.autoinv()
                        end

                    until mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)() ~= v

                    if mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('='..v,2)() == nil then
                        count = count + 1
                        if mode == 2 then
                            grabList[k] = nil
                        end
                    end

                else
                    print('\at[TsC]\ao Found \ay'..v..'\ao in row '..i..'\ay but my inventory is full!')
                    return count, grabList
                end
            end
        end
    end
    utils.cleanup()
    return count, grabList
end


function utils.tradeNew(receiver, list, override)
    mq.cmdf('/dobserve %s -q Me.FreeInventory', receiver)
    utils.cleanup()
    utils.navTarget(receiver)

    local tradeCount = 0
    local countTo8 = 0
    local full = false

    for item,_ in pairs(list) do

        if mq.TLO.FindItemCount('='..item)() > 0 then

            if tonumber(mq.TLO.DanNet(receiver).O('Me.FreeInventory')()) > 7 or override == true then

                if mq.TLO.Spawn(receiver).Distance() > 20 then
                    utils.navTarget(receiver)
                end

                repeat --repeat for multiple stacks of the same item
                    if countTo8 == 0 then print('\at[TsC]\ar '..receiver..' \ao has \ar'..mq.TLO.DanNet(receiver).O('Me.FreeInventory')()..' \ao slots left') end

                    print('\at[TsC]\ao Giving \ay'..item..' \aoto \ar'..receiver)

                    repeat
                        utils.pickup(item)
                        mq.delay(100)
                    until mq.TLO.Cursor() == item
                    repeat
                        if mq.TLO.Target.Name() ~= receiver then mq.cmdf('/target %s', receiver) mq.delay(100) end
                        mq.cmd('/usetarget')
                        mq.delay(1000)
                    until mq.TLO.Cursor() == nil

                    countTo8 = countTo8 + 1

                until mq.TLO.FindItemCount('='..item)() == 0 or countTo8 == 8

                tradeCount = tradeCount + 1
                list[item] = nil

                if countTo8 == 8 then --if tradewindow is full, give
                    repeat
                        mq.cmd('/yes')
                        mq.delay(100)
                        mq.cmdf('/dex %s /yes', receiver)
                        mq.delay(1000)
                    until not mq.TLO.Window('TradeWnd').Open()
                    countTo8 = 0
                end
                
            else
                print('\at[TsC]\ao Uh oh, it appears \ar'..receiver..' \ay is low on inventory space!')
                full = true
                repeat
                    mq.cmd('/yes')
                    mq.delay(100)
                    mq.cmdf('/dex %s /yes', receiver)
                    mq.delay(1000)
                until not mq.TLO.Window('TradeWnd').Open()
                utils.cleanup()
                return tradeCount, list, full
            end
        end
    end
    repeat
        mq.cmd('/yes')
        mq.delay(100)
        mq.cmdf('/dex %s /yes', receiver)
        mq.delay(1000)
    until not mq.TLO.Window('TradeWnd').Open()
    mq.cmdf('/dobserve %s -drop', receiver)
    utils.cleanup()
    return tradeCount, list, full
end


function utils.bank(bankList)
    utils.cleanup()
    utils.banker()
    local count = 0
    local full = false
    local function bankFull()
        full = true
    end

    mq.event('fullbank', '#*#You have no room left in the bank#*#', bankFull)

    for index,item in pairs(bankList) do
        print('\at[TsC]\ao Putting \ay'..item..' \aoin the bank.')
        utils.autoinv()

        if mq.TLO.FindItemCount('='..item)() > 0 then
            repeat

                utils.pickup(item)

                while mq.TLO.Cursor() do
                    mq.cmd('/notify BigBankWnd BIGB_AutoButton leftmouseup')
                    mq.doevents()
                    if full == true then
                        utils.cleanup()
                        utils.autoinv()
                        return count, bankList
                    end
                    mq.delay(100)
                end

            until mq.TLO.FindItemCount('='..item)() == 0
            count = count + 1
            bankList[index] = nil
        end
        mq.delay(200)
    end
    utils.cleanup()
    return count, bankList
end


function utils.depot(depotList, checkSize)
    utils.cleanup()
    utils.banker()
    local count = 0

    local mouseLocX = mq.TLO.Window('TradeskillDepotWnd').X() + (mq.TLO.Window('TradeskillDepotWnd').Width() / 2)
    local mouseLocY = mq.TLO.Window('TradeskillDepotWnd').Y() + (mq.TLO.Window('TradeskillDepotWnd').Height() / 2)

    for index,item in pairs(depotList) do
        print('\at[TsC]\ao Putting \ay'..item..' \aoin your depot.')
        utils.autoinv()

        if mq.TLO.FindItemCount('='..item)() > 0 then

            if checkSize == false or mq.TLO.TradeskillDepot.Count() < mq.TLO.TradeskillDepot.Capacity() then
                repeat

                    utils.pickup(item)

                    mq.cmd('/foreground self.Name')

                    while mq.TLO.Cursor() do
                        mq.cmdf('/mouseto %s %s', mouseLocX, mouseLocY)
                        mq.delay(100)
                        mq.cmd('/click left')
                        if mq.TLO.Window('ConfirmationDialogBox')() then
                            mq.cmd('/no') --Avoid accidentally dropping items on the ground
                        end
                        mq.delay(300)
                    end
                until mq.TLO.FindItemCount('='..item)() == 0
            else
                print('\at[TsC]\ao Tradeskill depot is full!.')
                utils.cleanup()
                return count, depotList
            end
            count = count + 1
            depotList[index] = nil
        end
        mq.delay(200)
    end
    utils.cleanup()
    return count, depotList
end


function utils.bankToDepot(bankToDepotList)
    utils.cleanup()
    print('\at[TsC]\ao Moving items from the bank to your depot.')
    utils.grab(bankToDepotList, 1, 41)

    local move = utils.depot(bankToDepotList, false)
    utils.cleanup()
    return move
end

return utils