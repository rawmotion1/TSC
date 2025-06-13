---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

local args = {...}

--If QTY arg is passed, assume we have just 1 item to grab QTY of
local qty = args[1] or nil
if qty then qty = tonumber(qty) end

--Load data
local lists = cm.loadData('lists')

local function tradeToons()
    local list = lists['totrade'][me]
    local itemList = {}

    --Arange items by destination
    for item, dest in pairs(list) do
        if dest ~= me and not dest:find('skipped') then
            itemList[dest] = itemList[dest] or {}
            itemList[dest][item] = ''
        end
    end

    for dest in pairs(itemList) do
        --Get the destination toon's free inventory
        mq.cmdf('/dobserve %s -q Me.FreeInventory', dest)

        --Close all windows
        shared.cleanup()

        mq.delay(200)

        --If the destination toon has free inventory, navigate to them and target them
        if tonumber(mq.TLO.DanNet(dest).O('Me.FreeInventory')()) > 7 then
            local target = mq.TLO.Spawn('PC ='..dest)()
            if target == nil then
                print('\at[TsC]\ao Target not found in zone. Stopping')
                break
            end
            if mq.TLO.Spawn('PC ='..dest).Distance() > 20 then
                mq.cmdf('/squelch /nav spawn PC =%s', dest)
            end
            while mq.TLO.Navigation.Active() do
                if mq.TLO.Spawn('PC ='..dest).Distance() <= 20 then
                    mq.cmd('/squelch /nav stop')
                    break
                end
            end

            while mq.TLO.Target.Name() ~= target do
                mq.cmdf('/target PC =%s', dest)
                mq.delay(100)
            end
            mq.delay(500)
            shared.tradeItems(itemList[dest], dest, qty)
        else
            printf('\at[TsC]\ao %s is low on inventory. Skipping.', dest)
        end
    end
end
tradeToons()

shared.execute(cm.settings.driver, '/tsc donetrading')

shared.cleanup()