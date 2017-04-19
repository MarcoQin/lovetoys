-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
local Entity = lovetoys.class("Entity")

function Entity:init(parent, name)
    self.components = {}
    self.eventManager = nil
    self.alive = false
    if parent then
        self:setParent(parent)
    else
        parent = nil
    end
    self.name = name
    self.children = {}
end

-- Sets the entities component of this type to the given component.
-- An entity can only have one Component of each type.
function Entity:add(component)
    local name = component.class.name
    if self.components[name] then
        lovetoys.debug("Entity: Trying to add Component '" .. name .. "', but it's already existing. Please use Entity:set to overwrite a component in an entity.")
    else
        self.components[name] = component
        component:setEntity(self)
        if self.eventManager then
            self.eventManager:fireEvent(ComponentAdded(self, name))
        end
    end
end

function Entity:set(component)
    local name = component.class.name
    if self.components[name] == nil then
        self:add(component)
    else
        self.components[name] = component
        component:setEntity(self)
    end
end

function Entity:addMultiple(componentList)
    for _, component in  pairs(componentList) do
        self:add(component)
    end
end

-- Removes a component from the entity.
function Entity:remove(name)
    if self.components[name] then
        self.components[name]:unsetEntity()
        self.components[name] = nil
    else
        lovetoys.debug("Entity: Trying to remove unexisting component " .. name .. " from Entity. Please fix this")
    end
    if self.eventManager then
        self.eventManager:fireEvent(ComponentRemoved(self, name))
    end
end

function Entity:setParent(parent)
    if self.parent then self.parent.children[self.id] = nil end
    self.parent = parent
    self:registerAsChild()
end

function Entity:getParent()
    return self.parent
end

function Entity:registerAsChild()
    if self.id then self.parent.children[self.id] = self end
end

function Entity:get(name)
    return self.components[name]
end

function Entity:has(name)
    return not not self.components[name]
end

function Entity:getComponents()
    return self.components
end

function Entity:pushEvent(event, data)
    if self.sg then
        if self.sg:isListeningForEvent(event) then
            if SGManager:onPushEvent(self.sg) then
                self.sg:pushEvent(event, data)
            end
        end
    end
end

local StateGraphs = {}

local function LoadStateGraph(name)

    if StateGraphs[name] == nil then
        local fn = require("stategraphs/"..name)
        assert(fn, "could not load stategraph "..name)
        StateGraphs[name] = fn
    end

    local sg = StateGraphs[name]

    assert(sg, "stategraph "..name.." is not valid")
    return sg
end

function Entity:setStateGraph(name)
    if self.sg then
        SGManager:removeInstance(self.sg)
    end
    local sg = LoadStateGraph(name)
    assert(sg)
    if sg then
        self.sg = StateGraphInstance(sg)
        self:add(self.sg)
        SGManager:addInstance(self.sg)
        self.sg:goToState(self.sg.sg.defaultstate)
        return self.sg
    end
end


function Entity:clearStateGraph()
    if self.sg then
        SGManager:removeInstance(self.sg)
        self.sg = nil
    end
end

return Entity
