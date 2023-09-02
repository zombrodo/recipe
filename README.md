# Recipe

A super simple action scheduler, designed for use with Love2d.

## Motivation

Sometimes you would like to queue actions in your game to occur after one
another, for example:

1. Move from Lumberyard to Tree
2. Cut down Tree
3. Collect Logs
4. Deposit Logs at Lumberyard

If you have some `Lumberjack` entity, then you could probably concoct some
assortment of `if else` statements to ensure these happen in order.

```lua
function Lumberjack:update(dt)
  if self.state == "available":
    self:moveToNearestTree()
    self.state = "headingToTree"
  elseif self.state == "headingToTree" and self:nearTree(self.x, self.y) then
    self.state = "cuttingTree"
  elseif self.state == "cuttingTree" and not self:nearTree(self.x, self.y) then
    -- and so on, and so forth
  end
end
```

Instead, what if you could essentially queue these actions, one after another?

```lua
local function work(worker, tree)
  moveTo(tree)
  cutTree()
  collect()
  moveTo(worker.lumberyard)
  deposit(worker.lumberyard)
end
```

This is what `recipe` aims to aid with.

## Usage

Put `recipe.lua` somewhere into your project, and import it the usual way

```lua
local Recipe = require "path.to.libs.recipe"
```

In order to perform an action, you first off need an `Action`. Actions are the
base class for something you can submit to the scheduler - we'll create one of
those later.

For now, lets create an action called `MoveAction` that takes some object with
a position and speed, and a `goalX` and `goalY` value of where we'd like it to
move to.

While we're here, we'll set up a couple of variables for `dx` and `dy` which is
the change in position at each step that we'll calculate next.

```lua
local MoveAction = Recipe.createAction()

function MoveAction:new(entity, goalX, goalY)
  local action = MoveAction.super.new(self)
  action.entity = entity
  action.goalX = goalX
  action.goalY = goalY
  action.dx = 0
  action.dy = 0
  return action
end
```

`Action` exposes the following callbacks:

* `onEnter()` which is fired when this action is begun
* `onExit()` which is fired when this action is completed
* `update(dt)` which is fired for every `love.update` call while this action is
  being run.

And the following functions:

* `complete()` which ends the action on the next `update` call.
* `enter()` which starts the action.

We'll want to hook into `onEnter` to calculate the `dx` and `dy` values required
to get to `goalX` and `goalY`. We'll also hook into `update(dt)` to update our
entity's position every loop, or complete the action if we've reached our
destination.

```lua
local function distance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function MoveAction:onEnter()
  local dist = distance(self.entity.x, self.entity.y, self.goalX, self.goalY)

  self.dx = (self.x - self.entity.x) / dist * self.entity.speed
  self.dy = (self.y - self.entity.y) / dist * self.entity.speed
end

-- 'roughly' equals to account for floating point shenanigans
local function almostEquals(a, b, eps)
  return math.abs(a - b) < eps
end

function MoveAction:update(dt)
  self.entity.x = self.entity.x + self.dx * dt
  self.entity.y = self.entity.y + self.dy * dt

  -- if we're within a couple pixels of where we want to go, we're done
  if almostEquals(self.entity.x, self.goalX, 2)
    and almostEquals(self.entity.y, self.goalY, 2) then
    self:complete()
  end
end
```

We now have an action which when given an entity and a goal, will start moving
our entity towards the desired location. But! It's no good if it's got no
harness to run - thats we're our `Scheduler` comes in.

A `Scheduler` essentially handles all the coroutine shenanigans under the hood
with an easy to use API.

Lets say we have a `Villager` object that we want to give a series of movement
commands to using our `MoveAction` action. I often create a scheduler per
entity, so the constructor might look something like this:

```lua
-- Assuming you're using a class library like classic or batteries.class?
function Villager:new(x, y)
  self.x = x
  self.y = y
  self.speed = 200

  self.scheduler = Recipe.createScheduler()
end

function Villager:update(dt)
  self.scheduler:update(dt)
end

-- and whatever other functions you have (drawing etc.)
```

The general pattern I use when creating Action Lists for entities is define
two types of functions. It's a little verbose, and it's definitely possible to
make it tidier.

The first function is the abstraction over the `Action`:

```lua
function Villager:moveTo(x, y)
  local action = MoveAction.new(self, x, y)
  -- Update any state you might have on Villager for drawing (ie. animations)
  action:enter()
end
```

Then, the `Scheduler` takes a function to execute. This will look like the first
example. I often make it a local function:

```lua
local function movement(villager)
  villager:moveTo(100, 100)
  villager:moveTo(200, 100)
  villager:moveTo(200, 200)
  villager:moveTo(100, 200)
  villager:moveTo(100, 100)
end
```

This'll send our villager into a square, once we pass this to the scheduler

```lua
function Villager:patrol()
  self.scheduler:submit(movement, self)
end
```

Our villager should now be walking in a square! Once it moves to 100, 100, it
should  then move to the right, then down, the left, then back up - in that
order.

This synchronous way of writing actions out, for me at least, ends up being
_so easy_ to queue up actions one after another.

There's an almost endless number of ways to utilise the Action List pattern -
in-game cutscenes, a set of animations that need to occur one after another etc.
This pattern makes it easy that you can set it up in your code, submit it to the
scheduler, and know that they'll always happen one after another - it's kinda
neat.

## API

### `Recipe.createAction(): Recipe.Action`

Extends the `Recipe.Action` object, allowing you to define your own `Action`.

### `Recipe.Action:new(): Recipe.Action`

Constructor for the `Action`. When extending, it's recommended to use the
following setup

```lua
local MyAction = Recipe.createAction()

function MyAction:new()
  local action = MyAction.super.new(self)
  return action
end
```

Where `MyAction.super.new` is the constructor for the base `Recipe.Action`
object.

### `Recipe.Action:onEnter(): void`

Callback fired when the action is begun

### `Recipe.Action:onExit(): void`

Callback fired when the action is completed

### `Recipe.Action:update(dt: number): void`

Callback fired for every `update` while the action is running.

### `Recipe.Action:complete(): void`

Calling this function marks the action as complete, which will fire at the _end_
of the current update. It's recommended to call this at the very end of your
`update` function when you're ready to complete, or at least exit-early, so you
don't have a final set of updates before its completed.

### `Recipe.Action:enter(): void`

Begins the Action. Call this from within the scheduler function.

### `Recipe.createScheduler(): Recipe.Scheduler`

Creates a new Scheduler. Action lists are passed to this, and run in order.

### `Recipe.Scheduler:submit(fn: Function): void`

Executes the Action list defined in `fn` one after another.

### `Recipe.Scheduler:update(dt): void`

Updates the current action, while also handling moving onto the next action.

## Contributions

The library is tiny, but contributions and feature requests are welcome :)
