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

local door_data
local doors

function calc_doors()
  if door_data then
    return door_data
  end
  local store_id = inventory.current_store()
  door_data = {
    {
      x=4,
      y=4,
      open=store_id==1
    },
    {
      x=12,
      y=5,
      open=store_id==3
    },
    {
      x=3,
      y=11,
      open=store_id==2
    },
    {
      x=11,
      y=10,
      open=store_id==4
    }
  }
  return door_data
end

function open_door()
  for door in all(calc_doors()) do
    if door.open then
      return door
    end
  end
end

--check tile for bit
function check_tile (x,y,bit)
  if x < 0 or x >= 16 then
    return true
  end
  if y < 0 or y >= 16 then
    return true
  end

  for door in all(calc_doors()) do
    if door.x == x and door.y == y and not door.open then
      return true
    end
  end

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

function end_walkabout()
  door_data = nil
  doors.each(function(d)
    d.kill()
  end)
  doors = nil
  sale.counter=0
end

function update_walkabout()
  local x = player.x
  local y = player.y
  local moved = false
  local nflp


  place_sale()


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
    end_walkabout()
    fighting=make_fight(inventory)
    fighting.start_store(store_index)
    return true
  elseif player.y != y and not sprite_collided(player.x,y) then
    moved=true
    player.y=y
  end

  if moved then
    player.walking=true
    if player.x > 119 then
      end_walkabout()
      fighting=make_fight(inventory)
      fighting.start()
      return true
    end
  else
    player.walking=false
  end
  return true
end

sale = {
  alive=true,
  counter=1,
  text="sale"
}

function place_sale()
  sale.counter-=1
  sale.color = ({7,8,10,11,12,14})[flr(sale.counter/4)%6+1] --[flr(rnd(6))+1]
  if sale.counter <= 0 then
    local door = open_door()
    if not door then
      return
    end
    sale.x = door.x*8-18+rnd(30)
    sale.y = door.y*8-10+rnd(20)
    --sale.color = ({7,8,10,11,12,14})[flr(rnd(6))+1]
    sale.counter = flr(15+rnd(5))
    sale.text = ({"sale","omg","wow","oooh"})[flr(rnd(4))+1]
  end
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

  place_sale()

  --fighting.start() --uncomment to start in a fight

  --music(o,0,15)
  -- most init code is above the function it relates to
  -- also some init code at the top
  -- subject to change, but makes things a bit easier for now
end

function _update()
  delays.process(function()
    tweens.advance()
  end)
  return fighting.update() or update_walkabout()
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

  if fighting.draw() then
    return
  end

  if not doors then
    doors = make_pool()
    for door in all(calc_doors()) do
      if door.y > 8 then
        if door.open then
          doors.make(sprites.make(28,{x=door.x*8,y=door.y*8}))
          doors.make(sprites.make(29,{x=door.x*8,y=door.y*8-8}))
        end
      else
        local sprite_id
        if door.open then
          sprite_id = 37
        else
          sprite_id = 46
        end
        doors.make(sprites.make(sprite_id,{x=door.x*8,y=door.y*8}))
      end
    end
  end

  --walkabout
  palt(0,false)
  map(0,0,0,0,128,128,1)
  palt()
  sprites.draw()
  palt(0,false)
  map(0,0,0,0,128,128,4)
  palt()
  if open_door() then
    print(sale.text,sale.x,sale.y,sale.color)
  end
end
-- END LIB
