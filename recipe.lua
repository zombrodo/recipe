--[[
MIT License

Copyright (c) 2023 Jack Robinson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local Recipe = {}

-- =============================================================================
-- Actions
-- =============================================================================

local Action = {}
Action.__index = Action

function Action:new()
  local action = setmetatable({}, self)
  action.__finished = false
  return action
end

function Action:extend()
  local sub = {}
  sub.__index = sub
  sub.super = self
  return setmetatable(sub, self)
end

function Action:onEnter()
end

function Action:update(dt)
end

function Action:onExit()
end

function Action:complete()
  self.__finished = true
end

function Action:enter()
  self:onEnter()
  while not self.__finished do
    local dt = coroutine.yield()
    self:update(dt)
  end
  self:onComplete()
end

Recipe.Action = Action

-- =============================================================================
-- Scheduler
-- =============================================================================

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
  local self = setmetatable({}, Scheduler)
  self.items = {}
  return self
end

function Scheduler:submit(fn, ...)
  local co = coroutine.create(fn)
  local ok, message = coroutine.resume(co, ...)
  if not ok then
    print(message)
    return
  end
  table.insert(self.items, co)
end

function Scheduler:update(dt)
  for i = #self.items, 1, -1 do
    local co = self.items[i]
    local ok, message = coroutine.yield(co, dt)
    if not ok then
      print(message)
    end

    if coroutine.status(co) == "dead" then
      table.remove(self.items, i)
    end
  end
end

Recipe.Scheduler = Scheduler

-- =============================================================================
-- Recipe
-- =============================================================================

function Recipe.newScheduler()
  return Scheduler.new()
end

function Recipe.createAction()
  return Action:extend()
end

return Recipe
