--- @type Mq
local mq = require('mq')
local utils = require('utils')

local resultPath = 'TSC/tmp/search.lua'
local toonPath = 'TSC/toons.lua'
local toons = {}

local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
if toonError then
    print('\at[TsC]\ao Error loading toons.lua')
    mq.exit()
elseif loadToons then
    toons = loadToons()
end

local allitems = {}
for _,toon in pairs(toons) do
    if mq.TLO.Spawn('PC ='..toon.name)() then --Only load results of toons in-zone
        local path = 'TSC/tmp/allitems_'..toon.name..'.lua'
        local table, error = loadfile(mq.configDir..'/'..path)
        if error then
            --nothing
        elseif table then
            allitems[toon.name] = table()
        end
    end
end

local search = {}
for toon,items in pairs(allitems) do
    for item,details in pairs(items) do
        local exists = false
        for _,v in pairs(search) do
            if v['item'] == item then
                exists = true
                v[toon] = details
            end
        end
        if exists == false then
            local x = {
                ['item'] = item,
                [toon] = details
            }
            table.insert(search, x)
        end
    end
end

mq.pickle(resultPath, search)

mq.cmd('/tsc donesearching')

