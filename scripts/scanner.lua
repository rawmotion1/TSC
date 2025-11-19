---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

local args = {...}
local itemType
if args[1] == 'Tradeskill' then
    itemType = shared.TS
else
    itemType = shared.CL
end

if args[2] == 'all' then
    --Load items in the find window
    shared.initFindWindow(itemType, 1) -- 1 is everywhere
elseif args[2] == 'inventory' then
    --Load items in the find window
    shared.initFindWindow(itemType, 4) -- 4 is inventory only
end



--Combine cm.ignore and cm.pignore[me] tables into one table
local combinedIgnore = {}
local globalIgnore = cm.ignore
local personalIgnore = cm.pignore[me]
for k in pairs(globalIgnore) do
    combinedIgnore[k] = 'the global ignore list'
end
for k in pairs(personalIgnore) do
    combinedIgnore[k] = 'your personal ignore list'
end

local countSlots = 0
local countItems = 0

local items = {}

local give = false
--If an item argument is passed, we will only scan for that item
if args[3] == 'give' then
    give = true
elseif args[3] then
    args[3] = string.gsub(args[3], '^"(.*)"$', '%1') --Remove quotes if they exist
    print(args[3])
    items = cm:loadTmp('items', me)
    items[args[3]] = nil --remove current item info
    mq.TLO.Window("FindItemWnd").Child("FIW_ItemNameInput").SetText(args[3])
    mq.delay(100)
    --Click search
    mq.cmd('/notify FindItemWnd FIW_QueryButton leftmouseup')
end

--Scan items in find window
local listSize = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').Items()
for i=1, listSize do
    local name = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,2)()
    local qty = tonumber(mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,3)())
    local location = mq.TLO.Window('FindItemWnd').Child('FIW_ItemList').List(i,5)()

    local skip = false
    for k in pairs(combinedIgnore) do
        if name == k then
            skip = true
            --print('\at[TsC]\ao Skipping \ay'..name..'\ao because it\'s on ' .. combinedIgnore[k] .. '.')
            break
        end
    end

    if not skip then
        local item
        if string.match(location, "General") then
            item = mq.TLO.FindItem('='..name)
        elseif string.match(location, "Bank") then
            item = mq.TLO.FindItemBank('='..name)
        elseif string.match(location, "Personal") then
            item = mq.TLO.TradeskillDepot.FindItem('='..name)
        -- Ignore keychain items
        elseif string.match(location, "Parcel") or string.match(location, "Mount") or string.match(location, "Illusion") or string.match(location, "Familiar") or string.match(location, "Teleportation") or string.match(location, "Activated") then
            skip = true
        elseif string.match(location, ",") then
            --Item is in a plot location and we can't get info
            if cm.settings.includePlots == false or give then
                skip = true
                --print('\at[TsC]\ao Skipping \ay'..name..'\ao because include plots is off.')
            end
        end
        if item then
            if item.NoDrop() or item.Container() ~= 0 or not item.Stackable() or item.Lore() or item.NoRent() then
                skip = true
                --print('\at[TsC]\ao Skipping \ay'..name..'\ao because it\'s nodrop, lore, etc.')
            end
        end
    end

    if not skip then
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
            local add = true
            if string.match(location, "General") then
                items[name]['inventory'][location] = qty
            elseif string.match(location, "Bank") then
                items[name]['bank'][location] = qty
                local stackSize = mq.TLO.FindItemBank('='..name).StackSize() or 0
                items[name]['stacksize'] = stackSize
            elseif string.match(location, ",") then
                 if items[name]['plots'][location] then --Another stack in existing plot location
                    items[name]['plots'][location] = items[name]['plots'][location] + qty
                    items[name]['total'] = items[name]['total'] + qty
                    add = false
                 else --New plot location
                    items[name]['plots'][location] = qty
                    items[name]['total'] = items[name]['total'] + qty
                 end
            end
            countSlots = countSlots + 1
            if add == true then
                items[name]['locations'] = items[name]['locations'] + 1
            end
        end
        --print('\at[TsC]\ao Found \ay'..name)
    end
end


--Restack incomplete stacks in bags
print('\at[TsC]\ao Checking for items to restack...')
for item in pairs(items) do
    if shared.tableLength(items[item]['inventory']) > 1 then
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
                    shared.autoinv()
                else
                    slot = tonumber(string.match(location, "%s%d+")) + 22
                    mq.cmdf('/shift /itemnotify %s leftmouseup', slot)
                    mq.delay(500)
                    shared.autoinv()
                end
                if y == x - 1 then break end
            end
        end
    end
end
print('\at[TsC]\ao Done with restacking.')

cm:saveTmp('items', me, items)

shared.cleanup()

--Tell init that this script is done
shared.execute(cm.settings.driver, '/tsc donescanning '..me..' '..countItems..' '..countSlots)
