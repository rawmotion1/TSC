--- @type Mq
local mq = require('mq')
local utils = require('utils')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'

local settings = {}
local items = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local allitems, itemerror = loadfile(mq.configDir..'/'..itemsPath)
    if itemerror then
        print('Error loading allitems_'..me..'.lua')
        mq.exit()
    elseif allitems then
        items = allitems()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to bank...')
mq.delay(1000)

local shouldBank
local bankList = {}

--Create list from items in inventory and bank, but that are not in depot
local function toMove()
    for item,_ in pairs(items) do
        local bank = false
        local inventory = false
        local depot = false
        for _,v in pairs(items[item]['locations']) do
            if string.match(v, "Bank") then
                bank = true
            end
            if string.match(v, "General") then
                inventory = true
            end
            if string.match(v, "Personal") then
                depot = true
            end
        end
        if inventory == true and bank == true and depot == false then
            table.insert(bankList, item)
            shouldBank = true
        end
    end
end
toMove()

local count = 0
if shouldBank == true then
    count = count + utils.bank(bankList)
end

mq.cmdf('/dgt \ar%s \awdone banking. Banked \ay%s \awunique items.', me, count)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donebanking')
else
    mq.cmdf('/dex %s /tsc donebanking', settings.driver)
end