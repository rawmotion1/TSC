--- @type Mq
local mq = require('mq')

--- @class FileManager
local paths = {
    settings = mq.configDir..'/TSC/settings.lua',
    toons = mq.configDir..'/TSC/toons.lua',
    ignore = mq.configDir..'/TSC/ignore.lua',
    mules = mq.configDir..'/TSC/mules.lua',
    pignore = mq.configDir..'/TSC/pignore.lua',
    hoard = mq.configDir..'/TSC/hoard.lua',
    items = mq.configDir..'/TSC/tmp/items_',
    combined = mq.configDir..'/TSC/tmp/combined.lua',
    lists = mq.configDir..'/TSC/tmp/lists.lua',
}

local defaultTables = {
    settings = {['tiebreaker'] = mq.TLO.Me.Name(), ['stats'] = true, ['includePlots'] = false, ['preferPlots'] = false, ['fullAuto'] = false },
    toons = { [mq.TLO.Me.Name()] = {['mode'] = 'Default', ['leftovers'] = 'Off'} },
    ignore = { ['Loaf of Bread'] = true, ['Water Flask'] = true, ['Round Cut Tool'] = true, ['Half-Moon Cut Tool'] = true, ['Oval Cut Tool'] = true, ['Trillion Cut Tool'] = true, ['Square Cut Tool'] = true, ['Marquise Cut Tool'] = true, ['Pear Cut Tool'] = true, ['Jewelers Glass'] = true, ['Sharpening Stone'] = true,},
    artisan = {},
    mules = {},
    pignore = {},
    hoard = {},
}

function paths:getPath(path)
    return self[path] or nil
end

function paths:load(path)
    local filePath = self:getPath(path)
    if filePath then
        local file, error = loadfile(filePath)
        if file then
            local content = file()
            return content
        elseif error then
            print('\at[TsC]\ao Creating \ayTSC/'..path..'.lua \aoin your config folder.')
            self:createFiles(path)
            file, error = loadfile(filePath)
            if file then
                local content = file()
                return content
            end
        end
    else
        print('Error: Path not found for ' .. path)
    end
end

function paths:createFiles(file)
    local table = defaultTables[file]
    local filePath = self:getPath(file)
    if filePath then
        mq.pickle(filePath, table)
    end
end

function paths:save(path, data)
    local filePath = self:getPath(path)
    if filePath then
        mq.pickle(filePath, data)
    else
        print('Error: Path not found for ' .. path)
    end
end

function paths:saveTmp(path, name, data)
    local filePath = self:getPath(path)..name..'.lua'
    if filePath then
        mq.pickle(filePath, data)
    else
        print('Error: Path not found for ' .. path)
    end
end

function paths:loadTmp(path, name)
    local filePath = self:getPath(path)..name..'.lua'
    if filePath then
        local file, error = loadfile(filePath)
        if file then
            local content = file()
            return content
        elseif error then
            print('Error loading file: ' .. error)
        end
    else
        print('Error: Path not found for ' .. path)
    end
end

return paths