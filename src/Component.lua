-- Collection of utilities for handling Components
local Component = {}

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

Component.all = {}

-- Create a Component class with the specified name and fields
-- which will automatically get a constructor accepting the fields as arguments
---@return Component
function Component.create(name, fields, defaults)
    ---@class Component
    ---@field public entity Entity
    ---@field public inst Entity @alias for entity
    local component = require(folderOfThisFile .. 'namespace').class(name)

    function component:onAddEntity() end
    function component:onRemoveEntity() end

    ---@param entity Entity
    component.setEntity = function(self, entity)
        if not entity then return end
        if self.entity then
            lovetoys.debug("Cannot add one Component instance to diffrent Entities!!")
        else
            self.entity = entity
            self.inst = entity
        end
        ---@type fun()
        if self.onAddEntity then
            self:onAddEntity()
        end
    end

    component.unsetEntity = function(self)
        self.entity = nil
        if self.onRemoveEntity then
            self:onRemoveEntity()
        end
    end

    if fields then
        defaults = defaults or {}
        component.init = function(self, ...)
            local args = {...}
            for index, field in ipairs(fields) do
                self[field] = args[index] or defaults[field]
            end
        end
    end

    Component.register(component)

    return component
end

-- Register a Component to make it available to Component.load
function Component.register(componentClass)
    Component.all[componentClass.name] = componentClass
end

-- Load multiple components and populate the calling functions namespace with them
-- This should only be called from the top level of a file!
function Component.load(names)
    if type(names) == "string" then
        return Component.all[names]
    end

    local components = {}

    for _, name in pairs(names) do
        components[#components+1] = Component.all[name]
    end
    return unpack(components)
end

return Component
