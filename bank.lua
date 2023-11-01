--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local consolPath = 'TSC/tmp/consolidate.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'

local settings = {}
local consol = {}
local items = {}


local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local consollist, consolError = loadfile(mq.configDir..'/'..consolPath)
    if consolError then
        print('\at[TsC]\ao Error loading consolidate.lua')
    elseif consollist then
        consol = consollist()
    end

    local allitems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('\at[TsC]\ao Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to bank...')

local bankList = {}
local restackList = {}
if consol[me] then
    for item,dest in pairs(consol[me]) do
        if dest == 'Bank' then
            table.insert(bankList, item)
            if utils.listSize(items[item]['bank']) > 1 then
                local max = mq.TLO.FindItemBank('='..item).StackSize() or 0
                local x = 0
                for _,qty in pairs(items[item]['bank']) do
                    if qty < max then x = x + 1 end
                end
                if x > 1 then
                    table.insert(restackList, item)
                end
            end
        elseif dest == 'BankRestack' then
            table.insert(bankList, item)
            table.insert(restackList, item)
        end
    end
end
mq.delay(1000)

if utils.listSize(restackList) > 0 then
    print('\at[TsC]\ao Grabbing items to restack...')
    utils.grab(restackList)
end

local count = 0
if utils.listSize(bankList) > 0 or utils.listSize(restackList) > 0 then
    count = count + utils.bank(bankList)
end

if count > 0 then
    mq.cmdf('/dt %s \awDone banking. Banked \ay%s \awunique items.', settings.driver, count)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donebanking')
else
    mq.cmdf('/dex %s /tsc donebanking', settings.driver)
end