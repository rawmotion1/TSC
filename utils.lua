--- @type Mq
local mq = require('mq')

local utils = {}

--Emergency stop
function utils.stopAll(restart)
    print('\at[TsC]\ay Stopping all processes and restarting.')
    mq.cmd('/dgae /squelch /lua stop TSC/scan.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/match.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/grab.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/trade.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/bank.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/depot.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/leftover.lua')
    mq.cmd('/dgae /squelch /lua stop TSC/give.lua')
    if restart == true then
        mq.cmd('/lua run TSC/restart')
    end
    mq.exit()
end

--Toggle
function utils.switch(v)
    v = not v
end

--Make sure banker is in zone
function utils.checkBanker()
    if mq.TLO.NearestSpawn('banker').Name() == nil then
        print('\at[TsC]\ao There is no banker in this zone. Stopping.')
        return false
    end
    return true
end

--Alphabetize toons
function utils.sortToons(a, b)
    local delta = 0
    if a and b then
        if a.name < b.name then
            delta = -1
        elseif b.name < a.name then
            delta = 1
        else
            delta = 0
        end
        if delta ~= 0 then
            return delta < 0
        end
        return a.name < b.name
    end
    return false
end

--Determine lize of given list
function utils.listSize(who)
    local count = 0
    for _,v in pairs(who) do
        count = count + 1
    end
    return count
end

function utils.loadFindWindow(what) --what: 41 is ts mats 19 is collectibles
    mq.cmd('/invoke ${Window[FindItemWnd].DoOpen}')
    mq.delay(300)
    mq.cmd('/notify FindItemWnd FIW_Default leftmouseup')
    mq.delay(300)
    mq.cmd('/notify FindItemWnd FIW_ItemLocationCombobox listselect 1')
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

function utils.navTarget(name, bank)
    utils.cleanup()
    local target
    if bank == true then
        target = mq.TLO.NearestSpawn(name)()
    else
        target = mq.TLO.NearestSpawn('"='..name..'"')()
    end
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
        if bank == true then
            mq.cmdf('/target %s', target)
        else
            mq.cmdf('/target "=%s"', target)
        end
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

    utils.navTarget(banker, true)

    while not mq.TLO.Window('BigBankWnd').Open() do
        mq.cmd('/usetarget')
        mq.delay(100)
    end

    while not mq.TLO.Window('TradeskillDepotWnd').Open() do
        mq.cmd('/notify BigBankWnd BIGB_TradeskillDepot leftmouseup')
        mq.delay(100)
    end
end

--where: 1=all 2=bank 4=inventory, ignore: ignorelist, items: results to be returned, what: mats or collectibles, realestate: include real estate
function utils.scan(where, ignore, items, what, realestate)
    utils.cleanup()
    utils.loadFindWindow(what)

    local listSize = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').Items()

    local countSlots = 0
    local countItems = 0

    for i=1, listSize do
        local name = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)()
        local qty = tonumber(mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,3)())
        local location = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,4)()

        local real
        local skip = false
        for _,v in pairs(ignore) do
            if v == name then skip = true real = false end
        end

        local item
        if string.match(location, "General") then item = mq.TLO.FindItem('='..name)
        elseif string.match(location, "Bank") then item = mq.TLO.FindItemBank('='..name)
        elseif string.match(location, "Personal") then item = mq.TLO.TradeskillDepot.FindItem('='..name)
            --this is a good place to enable/disable real estate
        elseif string.match(location, ",") and skip == false and realestate == true then real = true skip = true --Item is in real estate so we can't get info on it
        else skip = true
        end

        if skip == false then
            if item.NoDrop() or item.Container() ~= 0 or not item.Stackable() or item.Lore() then
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
                items[name].totalQty = qty
                items[name]['locations'] = {}
                table.insert(items[name]['locations'], location)
                countSlots = countSlots + 1
                countItems = countItems + 1
            else
                table.insert(items[name]['locations'], location)
                items[name].totalQty = items[name].totalQty + qty
                countSlots = countSlots + 1
            end
            print('\at[TsC]\ao Found \ay'..name)
        elseif real == true then
            
            if not items[name] then
                items[name] = {}
                items[name].totalQty = qty
                items[name]['locations'] = {}
                table.insert(items[name]['locations'], location)
                countSlots = countSlots + 1
                countItems = countItems + 1
            else
                table.insert(items[name]['locations'], location)
                items[name].totalQty = items[name].totalQty + qty
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

function utils.scantwo(items, ignore, what, realestate)
    utils.cleanup()
    utils.loadFindWindow(what)

    local listSize = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').Items()

    local countSlots = 0
    local countItems = 0

    for i=1, listSize do
        local name = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)()
        local qty = tonumber(mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,3)())
        local location = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,4)()

        local real = false
        local skip = false
        for _,v in pairs(ignore) do
            if v == name then
                skip = true
                real = false
            end
        end

        local item
        if string.match(location, "General") then
            item = mq.TLO.FindItem('='..name)
        elseif string.match(location, "Bank") then
            item = mq.TLO.FindItemBank('='..name)
        elseif string.match(location, "Personal") then
            item = mq.TLO.TradeskillDepot.FindItem('='..name)
        elseif string.match(location, ",") and skip == false and realestate == true then
            --Item is in real estate so we can't get info on it
            real = true
            skip = true
        else skip = true
        end

        if skip == false then
            if item.NoDrop() or item.Container() ~= 0 or not item.Stackable() or item.Lore() then
                skip = true
            end
        end

        if skip == false or real == true then
            local inv = mq.TLO.FindItemCount('='..name)() or 0
            local bnk = mq.TLO.FindItemBankCount('='..name)() or 0
            local dpt = mq.TLO.TradeskillDepot.FindItemCount('='..name)() or 0

            if not items[name] then --New item
                items[name] = {
                    inventory = {},
                    bank = {},
                    plots = {},
                    depot = dpt,
                    total = inv + bnk + dpt,
                    locations = 1,
                    destination = ""
                }
                if string.match(location, "General") then
                    items[name]['inventory'][location] = qty
                elseif string.match(location, "Bank") then
                    items[name]['bank'][location] = qty
                elseif string.match(location, ",") then
                    items[name]['plots'][location] = qty
                    items[name]['total'] = items[name]['total'] + qty
                end
                countSlots = countSlots + 1
                countItems = countItems + 1
            else --Already exists
                if string.match(location, "General") then
                    items[name]['inventory'][location] = qty
                elseif string.match(location, "Bank") then
                    items[name]['bank'][location] = qty
                elseif string.match(location, ",") then
                     if items[name]['plots'][location] then --Another stack in existing plot location
                        items[name]['plots'][location] = items[name]['plots'][location] + qty
                        items[name]['total'] = items[name]['total'] + qty
                     else --New plot location
                        items[name]['plots'][location] = qty
                        items[name]['total'] = items[name]['total'] + qty
                     end
                end
                countSlots = countSlots + 1
                items[name]['locations'] = items[name]['locations'] + 1
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

    print('\at[TsC]\ao Checking for items to restack...')

    for item,_ in pairs(items) do
        if utils.listSize(items[item]['inventory']) > 1 then

            local max = mq.TLO.FindItem('='..item).StackSize()

            local x = 0 --Number of incomplete stacks
            local inv = {}
            for location,qty in pairs(items[item]['inventory']) do
                if qty < max then
                    x = x + 1
                    table.insert(inv, location)
                end
            end

            if x > 1 then --There's more than 1 incomplete stack
                local y = 0
                for _,location in pairs(inv) do
                    y = y + 1
                    local dash = string.match(location, "-")
                    local bag = 0
                    local slot
                    if dash then
                        bag = tonumber(string.match(location, "%s%d+")) or 0
                        slot = tonumber(string.match(location, "%d+$"))
                        mq.cmdf('/shift /itemnotify in pack%s %s leftmouseup', bag, slot)
                        mq.delay(500)
                        utils.autoinv()
                    else
                        slot = tonumber(string.match(location, "%s%d+")) + 22
                        mq.cmdf('/shift /itemnotify %s leftmouseup', slot)
                        mq.delay(500)
                        utils.autoinv()
                    end
                    if y == x - 1 then break end
                end
            end
        end
    end
    print('\at[TsC]\ao Done with restacking.')
    utils.cleanup()
end

function utils.getInventory()
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

function utils.grab(grabList, what)
    utils.cleanup()
    utils.banker()
    utils.loadFindWindow(what)

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

                        local skip = false
                        while mq.TLO.Cursor() == v do
                            if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                                print('\at[TsC]\ao That\'s not right... Putting \ay'..v..'\ao back in the bank.') --Item with same name, but is not what I'm looking for
                                mq.cmd('/notify BigBankWnd BIGB_AutoButton leftmouseup')
                                skip = true
                            end
                            utils.autoinv()
                            mq.delay(500)
                        end

                    until mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)() ~= v or skip == true

                    if mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List('='..v,2)() == nil then
                        count = count + 1
                        grabList[k] = nil
                    end

                else
                    print('\at[TsC]\ao Found \ay'..v..'\ao in row '..i..'\ay but my inventory is full!')
                    return count
                end
            end
        end
    end
    utils.cleanup()
    return count
end

function utils.findTableDifference(table1, table2)
    for k,v in pairs(table1) do
        if table2[k] ~= v then
            return k
        end
    end
end


function utils.grabReal(realList)

    while not mq.TLO.Window('RealEstateItemsWnd').Open() do
        mq.TLO.Window('RealEstateItemsWnd').DoOpen()
        mq.delay(100)
    end

    local listSize = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').Items()
    local count = 0

    --Iterate list backwards so order isn't modified
    for i=listSize, 1, -1 do
        local row = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i,2)()
        local loc = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i,5)()
        mq.cmdf('/notify RealEstateItemsWnd REIW_ItemList listselect %s', i)
        for k,v in pairs(realList) do
            if row == v then
                if mq.TLO.Me.FreeInventory() > 0 then
                    print('\at[TsC]\ao Found \ay'..v..'\ao in row '..i)

                    repeat

                        utils.autoinv()
                        mq.delay(100)

                        local beforeInventory = utils.getInventory() --Scan inventory

                        mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
                        mq.delay(100)

                        local afterInventory = utils.getInventory() --Scan inventory again after grabbing an item

                        local invLoc = utils.findTableDifference(beforeInventory, afterInventory) --See if there are any new items
                        local bag
                        local slot

                        local skip = false
                        if invLoc then -- if there are new items, do some checks

                            bag, slot = string.match(invLoc, "(%d+)-(%d+)")

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

                        if skip == true then --Wrong item, put it back where it came from
                            print('\at[TsC]\ao That\'s not right... Putting \ay'..v..'\ao back in your plot.')
                            if slot then
                                mq.cmdf('/itemnotify in pack%s %s leftmouseup', bag, slot)
                            else
                                mq.cmdf('/itemnotify %s leftmouseup', invLoc)
                            end
                            if string.match(loc,'Crate') then
                                mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup')
                            else
                                mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup')
                            end
                        end

                    until mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List(i,2)() ~= v or skip == true

                    if mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList').List('='..v,2)() == nil then
                        count = count + 1
                        realList[k] = nil
                    end

                else
                    print('\at[TsC]\ao Found \ay'..v..'\ao in row '..i..'\ay but my inventory is full!')
                    return count
                end
            end
        end
    end
    utils.cleanup()
    return count
end



function utils.tradeNewest(receiver, list)
    mq.cmdf('/dobserve %s -q Me.FreeInventory', receiver)
    utils.cleanup()
    utils.navTarget(receiver)

    local inventory = utils.getInventory()

    local tradeCount = 0
    local countTo8 = 0

    local tradedItems = {}

    for item,_ in pairs(list) do

        if mq.TLO.FindItemCount('='..item)() > 0 then

            if tonumber(mq.TLO.DanNet(receiver).O('Me.FreeInventory')()) > 7 then

                if mq.TLO.Spawn(receiver).Distance() > 20 then
                    utils.navTarget(receiver)
                end

                for loc, name in pairs(inventory) do
                    if name == item then
                        if countTo8 == 0 then print('\at[TsC]\ar '..receiver..' \ao has \ar'..mq.TLO.DanNet(receiver).O('Me.FreeInventory')()..' \ao slots left') end

                        if countTo8 == 8 then --if tradewindow is full, give
                            repeat
                                mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                                mq.delay(100)
                                mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', receiver)
                                mq.delay(1000)
                            until not mq.TLO.Window('TradeWnd').Open()
                            countTo8 = 0
                        end

                        print('\at[TsC]\ao Giving \ay'..item..' \aoto \ar'..receiver)

                        local bag, slot = string.match(loc, "(%d+)-(%d+)")
                        
                        if slot then
                            bag = tonumber(bag) - 22
                            repeat
                                mq.cmdf('/shift /itemnotify in pack%s %s leftmouseup', bag, slot)
                                mq.delay(100)
                            until mq.TLO.Cursor() ~= nil
                        else
                            repeat
                                mq.cmdf('/shift /itemnotify %s leftmouseup', loc)
                                mq.delay(100)
                            until mq.TLO.Cursor() ~= nil
                        end

                        if mq.TLO.Cursor.NoDrop() or mq.TLO.Cursor.Lore() or mq.TLO.Cursor.Container() > 0 or not mq.TLO.Cursor.Stackable() then
                            utils.autoinv()
                            mq.delay(100)
                        else
                            repeat
                                if mq.TLO.Target.Name() ~= receiver then mq.cmdf('/target "=%s"', receiver) mq.delay(100) end
                                mq.cmd('/usetarget')
                                mq.delay(1000)
                            until mq.TLO.Cursor() == nil
                            countTo8 = countTo8 + 1
                        end
                    end
                end

                table.insert(tradedItems, item)
                tradeCount = tradeCount + 1
                list[item] = nil

                if countTo8 == 8 then --if tradewindow is full, give
                    repeat
                        mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                        mq.delay(100)
                        mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', receiver)
                        mq.delay(1000)
                    until not mq.TLO.Window('TradeWnd').Open()
                    countTo8 = 0
                end
                
            else
                print('\at[TsC]\ao Uh oh, it appears \ar'..receiver..' \ay is low on inventory space!')
                repeat
                    mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                    mq.delay(100)
                    mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', receiver)
                    mq.delay(1000)
                until not mq.TLO.Window('TradeWnd').Open()
                mq.cmdf('/dobserve %s -drop Me.FreeInventory', receiver)
                utils.cleanup()
                return tradeCount, tradedItems
            end
        end
    end
    repeat
        mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
        mq.delay(100)
        mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', receiver)
        mq.delay(1000)
    until not mq.TLO.Window('TradeWnd').Open()
    mq.cmdf('/dobserve %s -drop Me.FreeInventory', receiver)
    utils.cleanup()
    return tradeCount, tradedItems
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
        
        utils.autoinv()

        if mq.TLO.FindItemCount('='..item)() > 0 then
            print('\at[TsC]\ao Putting \ay'..item..' \aoin the bank.')
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

function utils.putReal(realList, room)
    while not mq.TLO.Window('RealEstateItemsWnd').Open() do
        mq.TLO.Window('RealEstateItemsWnd').DoOpen()
        mq.delay(100)
    end

    local count = 0

    for _,item in pairs(realList) do
        if mq.TLO.FindItemCount('='..item)() > 0 then
            print('\at[TsC]\ao Putting \ay'..item..' \aoin your plot.')
            repeat

                mq.cmdf('/itemnotify %s leftmouseup', item)
                mq.delay(300)

                if string.match(room,'Crate') then
                    mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup')
                else
                    if mq.TLO.Window('RealEstateItemsWnd').Child('REIW_Move_Closet_Button').Enabled() == true then
                        mq.cmd('/shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup')
                    else
                        --full
                    end
                end
                mq.delay(300)

            until mq.TLO.FindItemCount('='..item)() == 0
            count = count + 1
        end
    end
end

utils.resume = true
function utils.depot(depotList, checkSize)
    utils.cleanup()
    utils.banker()
    local count = 0

    local mouseLocX = mq.TLO.Window('TradeskillDepotWnd').X() + (mq.TLO.Window('TradeskillDepotWnd').Width() / 2)
    local mouseLocY = mq.TLO.Window('TradeskillDepotWnd').Y() + (mq.TLO.Window('TradeskillDepotWnd').Height() / 2)

    for index,item in pairs(depotList) do
        
        utils.autoinv()

        if mq.TLO.FindItemCount('='..item)() > 0 then
            print('\at[TsC]\ao Putting \ay'..item..' \aoin your depot.')
            if checkSize == false or mq.TLO.TradeskillDepot.Count() < mq.TLO.TradeskillDepot.Capacity() then
                repeat

                    utils.pickup(item)

                    local skip = false
                    if mq.TLO.Cursor.Tradeskills() and mq.TLO.Cursor.Stackable() and not mq.TLO.Cursor.Lore() and not mq.TLO.Cursor.NoDrop() then

                        mq.cmd('/foreground self.Name')

                        local attempts = 0
                        while mq.TLO.Cursor() do
                            mq.cmdf('/mouseto %s %s', mouseLocX, mouseLocY)
                            mq.delay(100)
                            mq.cmd('/click left')
                            if mq.TLO.Window('ConfirmationDialogBox')() then
                                mq.cmd('/no') --Avoid accidentally dropping items on the ground
                            end
                            mq.delay(300)

                            attempts = attempts + 1
                            if attempts > 9 then
                                utils.resume = false
                                while utils.resume == false do
                                    mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \aycan\'t depost. Be sure no Lua windows are obstructing their depot window.', mq.TLO.Me.Name())
                                    mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Type \ag/tsresume\ay from the stuck toon\'s EQ window to try again.')
                                    local function stop()
                                        return utils.resume
                                    end
                                    mq.delay(10000, stop)
                                    if utils.resume == true then attempts = 0 end
                                end
                            end
                        end

                    else
                        skip = true
                        utils.autoinv()
                    end

                until mq.TLO.FindItemCount('='..item)() == 0 or skip == true
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