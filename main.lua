-- START LIB
-- walkabout update logic

--check if tile with the min corner at x,y is overlapping with a solid tile
--useful for checking if a not-yet-moved-to tile will be problematic
function sprite_collided(x,y)
  return solid_px(x,y) or
                solid_px(x+7,y) or
                solid_px(x,y+7) or
                solid_px(x+7,y+7)
end

--check solidity by pixel
--true if pixel within a solid tile
function solid_px(x,y)
  return check_px(x,y,1)
end

--check tile bit by pixel
--true if pixel within a tile of a certain bit
function check_px(x,y,bit)
  return check_tile(flr(x/8),flr(y/8),bit)
end

--check tile for bit
function check_tile (x,y,bit)
  if x < 0 or x >= 16 then
    return true end
  if y < 0 or y >= 16 then
    return true end

  val = mget(x,y)
  return fget(val,bit)
end

--check if tile with min corner at x,y is sufficiently overlapped with door tile to count as entered
--assumes only able to enter door from top or bottom
function entered_door(x,y)
  if check_px(x,y+7,3) and check_px(x,y+1,3) then
    -- figure out which door it is by which quadrant the player is in
    if x > 64 then
      if y > 64 then
        return 4 --shoes
      else
        return 3 --ring
      end
    else
      if y > 64 then
        return 2 --lipstick
      else
        return 1 --dress
      end
    end
  else
    return false
  end
end

--exit door to previous tile
--assumes only enter from top or bottom
--returns exit y value
function exit_door_y(x,y)
  -- 12 because 8 is tile width + 4 of buffer to allow for high movement speeds
  if solid_px(x,y+12) then --low door
    return flr(y/8)*8-8
  else --high door
    return flr(y/8)*8+8
  end
end

function update_walkabout()
  local x = player.x
  local y = player.y
  local moved = false
  local nflp
  if btn(0) then
    nflp=true
    x=x-spd
  end
  if btn(1) then
    nflp=false
    x=x+spd
  end
  if player.x != x and not sprite_collided(x,player.y) then
    moved=true
    player.x=x
    player.flip=nflp
  end
  if btn(2) then y=y-spd end
  if btn(3) then y=y+spd end

  local store_index = entered_door(player.x,y)
  if store_index then
    moved=false
    store.start(store_index)
    return true
  elseif player.y != y and not sprite_collided(player.x,y) then
    moved=true
    player.y=y
  end

  if moved then
    player.walking=true
    if player.x > 119 then
      fighting=make_fight(inventory)
      fighting.start()
      return true
    end
  else
    player.walking=false
  end
  return true
end

function _init()
  player = sprites.make(0,{x=56,y=56})
  player.walking_frames = {0,1,0,2}
  player.walking_scale = 2
  player.before_draw = function()
    inventory.remap_girl_colors()
  end
  spd=2
  anim_t=0
  inventory = make_inventory()
  fighting = make_fight(inventory)
  store = make_store(inventory)
  --fighting.start() --uncomment to start in a fight

  --music(o,0,15)
  -- most init code is above the function it relates to
  -- also some init code at the top
  -- subject to change, but makes things a bit easier for now
end

function _update()
  tweens.advance()

  return fighting.update() or store.update() or update_walkabout()
end

-----
-- drawing
--
-- keep logic to a minimum
-- no game behavior or state changes here
-- assume frames will be missed
-----

queued_fns = {}

draw_text = function()
  foreach(queued_fns,function(fn)
    fn()
  end)
  queued_fns = {}
end

function queue_text(fn)
  add(queued_fns,fn)
end

function _draw()
  cam.apply()

  if fighting.draw() or store.draw() then
    return
  end

  --walkabout
  palt(0,false)
  map(0,0,0,0,128,128,1)
  palt()
  sprites.draw()
  palt(0,false)
  map(0,0,0,0,128,128,4)
  palt()
end
-- END LIB
