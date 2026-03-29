--- @type Mq
local mq = require('mq')
local paths = require('TSC.filemanager')

---@class ConfigManager
local config = {
    settings = {},
    toons = {},
    ignore = {},
    pignore = {},
    hoard = {},
    mules = {},
    version = '4.1.6',
    driver = '',
}

--Load all files on initialization
config.settings = paths:load('settings')
config.toons = paths:load('toons')
config.ignore = paths:load('ignore')
config.pignore = paths:load('pignore')
config.mules = paths:load('mules')
config.hoard = paths:load('hoard')

--Check for missing settings
function config:checkSettings()
    self.settings.preferPlots = self.settings.preferPlots or false
    self.settings.includePlots = self.settings.includePlots or false
    self.settings.stats = self.settings.stats == nil and true or self.settings.stats
    self.settings.tiebreaker = self.settings.tiebreaker or mq.TLO.Me.Name()
    self.settings.fullAuto = self.settings.fullAuto or false
    self.settings.driver = mq.TLO.Me.Name()
    config:save('settings')
end

--Save a a config table to a file
function config:save(file)
    paths:save(file, self[file])
end

function config.saveData(file, data)
    paths:save(file, data)
end

function config.loadData(file)
    return paths:load(file)
end

--Save an individual toon's item table to a file
function config:saveTmp(file, name, data)
    paths:saveTmp(file, name, data)
end

--Load an individual toon's item table from a file
function config:loadTmp(file, name)
    return paths:loadTmp(file, name)
end

--Force reload of a file (not used)
function config:reload(file)
    self[file] = paths:load(file)
end

--Add an item to the global ignore
function config:addIgnoreItem(item)
    for toon, items in pairs(self.hoard) do
        for k in pairs(items) do
            if k == item then
                print('\at[TsC]\ao \ay'..item..'\ao is in \ar'..config.fname(toon)..'\'s\ao hoard list... Can\'t ignore.')
                return
            end
        end
    end
    if not self.ignore[item] then
        self.ignore[item] = true
        self:save('ignore')
        print('\at[TsC]\ao \ay'..item..'\ao has been added to the ignore list.')
    else
        print('\at[TsC]\ao \ay'..item..'\ao is already in the ignore list.')
    end
end

--Remove an item from the global ignore
function config:removeIgnoreItem(item)
    if self.ignore[item] then
        self.ignore[item] = nil
        self:save('ignore')
        print('\at[TsC]\ao \ay'..item..'\ao has been removed from the ignore list.')
    else
        print('\at[TsC]\ao \ay'..item..'\ao is not in the ignore list.')
    end
end

--Add an item to the personal ignore list of a specific toon
function config:addPersonalIgnoreItem(name, item)
    if not self.pignore[name][item] then
        self.pignore[name][item] = true
        if self.hoard[name][item] then
            self.hoard[name][item] = nil
            print('\at[TsC]\ao \ay'..item..'\ao has been removed from the hoard list of \ar'..config.fname(name)..'.')
            self:save('hoard')
        end
        self:save('pignore')
        print('\at[TsC]\ao \ay'..item..'\ao has been added to the personal ignore list of \ar'..config.fname(name)..'.')
    else
        print('\at[TsC]\ao \ay'..item..'\ao is already in the personal ignore list of \ar'..config.fname(name)..'.')
    end
end

--Remove an item from the personal ignore list of a specific toon
function config:removePersonalIgnoreItem(name, item)
    if self.pignore[name][item] then
        self.pignore[name][item] = nil
        self:save('pignore')
        print('\at[TsC]\ao \ay'..item..'\ao has been removed from the personal ignore list of \ar'..config.fname(name)..'.')
    else
        print('\at[TsC]\ao \ay'..item..'\ao is not in the personal ignore list of \ar'..config.fname(name)..'.')
    end
end

--Add/move an item to the personal hoard list of a specific toon
function config:addhoardItem(name, item)
    if not self.hoard[name][item] then
        for k in pairs(self.hoard) do
            if self.hoard[k][item] then
                self.hoard[k][item] = nil
                print('\at[TsC]\ao \ay'..item..'\ao has been removed from the hoard list of \ar'..config.fname(k)..'.')
                break
            end
        end
        self.hoard[name][item] = true
        if self.ignore[item] then
            self.ignore[item] = nil
            print('\at[TsC]\ao \ay'..item..'\ao has been removed from the global ignore list.')
            self:save('ignore')
        end
        if self.pignore[name][item] then
            self.pignore[name][item] = nil
            print('\at[TsC]\ao \ay'..item..'\ao has been removed from the personal ignore list of \ar'..config.fname(name)..'.')
            self:save('pignore')
        end
        self:save('hoard')
        print('\at[TsC]\ao \ay'..item..'\ao has been added to the hoard list of \ar'..config.fname(name)..'.')
    else
        print('\at[TsC]\ao \ay'..item..'\ao is already in the hoard list of \ar'..config.fname(name)..'.')
    end
end

--Remove an item from the personal hoard list of a specific toon
function config:removehoardItem(name, item)
    self.hoard[name][item] = nil
    self:save('hoard')
    print('\at[TsC]\ao \ay'..item..'\ao has been removed from the hoard list of \ar'..config.fname(name)..'.')
end

function config.fname(name)
    return name
end

return config