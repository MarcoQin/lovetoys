-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
---@class Entity
---@field public id number
local Entity = lovetoys.class("Entity")

function Entity:init(parent, name)
    ---@type table<string, Component>
    self.components = {}
    self.eventManager = nil
    self.alive = true
    if parent then
        self:setParent(parent)
    else
        parent = nil
    end
    self.name = name
    self.children = {}
    self.tags = {}
    ---@type Engine
    self.engine = nil
end

function Entity:addTag(tag)
    self.tags[tag] = true
end

function Entity:removeTag(tag)
    self.tags[tag] = nil
end

function Entity:hasTag(tag)
    if self.tags[tag] then
        return true
    end
    return false
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

function Entity:AddChild(inst)
    self.children[inst.id] = inst
end

function Entity:RemoveChild(inst)
    self.children[inst.id] = nil
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
    if self.event_listeners then
        local listeners = self.event_listeners[event]
        if listeners then
            --make a copy list of all callbacks first in case
            --listener tables become altered in some handlers
            local tocall = {}
            for entity, fns in pairs(listeners) do
                for i, fn in ipairs(fns) do
                    table.insert(tocall, fn)
                end
            end
            for i, fn in ipairs(tocall) do
                fn(self, data)
            end
        end
    end

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

function Entity:onRemovedFromEngine()
    self:clearStateGraph()
    self:removeAllEventCallbacks()
end

function Entity:onAddedToEngine()
end

function Entity:removeSelf()
    self.engine:removeEntity(self, true)
end

local function AddListener(t, event, inst, fn)
    local listeners = t[event]
    if not listeners then
        listeners = {}
        t[event] = listeners
    end

    local listener_fns = listeners[inst]
    if not listener_fns then
        listener_fns = {}
        listeners[inst] = listener_fns
    end

    --source.event_listeners[event][self][1]

    table.insert(listener_fns, fn)
end

function Entity:ListenForEvent(event, fn, source)
    --print ("Listen for event", self, event, source)
    source = source or self

    if not source.event_listeners then
        source.event_listeners = {}
    end

    AddListener(source.event_listeners, event, self, fn)


    if not self.event_listening then
        self.event_listening = {}
    end

    AddListener(self.event_listening, event, source, fn)

end

local function RemoveByValue(t, value)
    if t then
        for i,v in ipairs(t) do
            while v == value do
                table.remove(t, i)
                v = t[i]
            end
        end
    end
end

local function RemoveListener(t, event, inst, fn)
    if t then
        local listeners = t[event]
        if listeners then
            local listener_fns = listeners[inst]
            if listener_fns then
                RemoveByValue(listener_fns, fn)
                if next(listener_fns) == nil then
                    listeners[inst] = nil
                end
            end
            if next(listeners) == nil then
                t[event] = nil
            end
        end
    end
end


function Entity:removeEventCallback(event, fn, source)
    assert(type(fn) == "function") -- signature change, fn is new parameter and is required

    source = source or self

    RemoveListener(source.event_listeners, event, self, fn)
    RemoveListener(self.event_listening, event, source, fn)

end

function Entity:removeAllEventCallbacks()

    --self.event_listening[event][source][1]

    --tell others that we are no longer listening for them
    if self.event_listening then
        for event, sources  in pairs(self.event_listening) do
            for source, fns in pairs(sources) do
                if source.event_listeners then
                    local listeners = source.event_listeners[event]
                    if listeners then
                        listeners[self] = nil
                    end
                end
            end
        end
        self.event_listening = nil
    end

    --tell others who are listening to us to stop
    if self.event_listeners then
        for event, listeners in pairs(self.event_listeners) do
            for listener, fns in pairs(listeners) do
                if listener.event_listening then
                    local sources = listener.event_listening[event]
                    if sources then
                        sources[self] = nil
                    end
                end
            end
        end
        self.event_listeners = nil
    end
end

function Entity.__eq(self, other)
    return self.id == other.id
end

return Entity
