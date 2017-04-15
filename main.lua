-- START LIB
function sprite_collided(x,y)
  return solid_px(x,y) or
    solid_px(x+7,y) or
    solid_px(x,y+7) or
    solid_px(x+7,y+7)
end

function solid_px(x,y)
  return check_tile(flr(x/8),flr(y/8),1)
end

local door_data
local doors, gate

function fancy_print(string,x,y,col1,col2)
  for xi=x-1,x+1 do
    for yi=y-1,y+1 do
      print(string,xi,yi,col1)
    end
  end
  print(string,x,y,col2)
end

function calc_doors()
  if door_data then
    return door_data
  end
  local store_id = inventory.current_store_index
  door_data = {
    {
      x=4,
      y=4,
      open=store_id==4
    },
    {
      x=12,
      y=5,
      open=store_id==2
    },
    {
      x=3,
      y=11,
      open=store_id==1
    },
    {
      x=11,
      y=10,
      open=store_id==3
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

  val = mget(x,y)
  return fget(val,bit)
end

--check if overlapped with door
function entered_door(x,y)
  local door = open_door()
  if not door then
    return false
  end
  if door.x*8 <= x+3 and door.x*8 >= x-3 and y <= door.y*8+11 and y >= door.y*8-11 then
    return inventory.current_store_index
  end
  return false
end

function reset_doors()
  door_data = nil
  doors.each(function(d)
    d.kill()
  end)
  doors = nil
  if gate then
    gate.each(function(g)
      g.kill()
    end)
    gate = nil
  end
end

function end_walkabout()
  sale.counter=0
  if inventory.current_store_index < 5 then
    sfx(-1,0)
  end
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
    if not player.walking then
      player.walking=true
      sfx(12,0)
    end
    if inventory.current_store_index > 4 and player.x > 119 then
      end_walkabout()
      fighting=make_fight(inventory)
      fighting.start()
      return true
    end
  else
    sfx(-1,0)
    player.walking=false
  end
  return true
end

function place_sale()
  if not sale then
    sale = {
      alive=true,
      counter=1,
      text="sale"
    }
  end
  sale.counter-=1
  sale.color = ({7,8,10,11,12,14})[flr(sale.counter/4)%6+1] --[flr(rnd(6))+1]
  if sale.counter <= 0 then
    local door = open_door()
    if not door then
      return
    end
    sale.x = door.x*8-18+rnd(30)
    sale.y = door.y*8-10+rnd(20)
    sale.counter = flr(15+rnd(5))
    sale.text = ({"sale","omg","wow","oooh"})[flr(rnd(4))+1]
  end
end

function _init()
  cam.y=-128
  player = sprites.make(0,{x=24,y=cam.y+32,z=250,scale=8})
  player.walking_frames = {0,1,0,2}
  player.walking_scale = 2
  player.before_draw = function()
    inventory.remap_girl_colors()
  end
  spd=2
  inventory = make_inventory()
  fighting = make_fight(inventory)
  intro_screen = true
  start_tile=sprites.make(45,{x=32,y=cam.y+64,scale=8,z=200})
  start_tile.before_draw = function()
    palt(0,false)
  end

  local turnloop
  turnloop=function()
    if not intro_screen then
      return
    end
    if player.flip then
      player.flip = false
      player.x-=8
    else
      player.flip = true
      player.x+=8
    end
    return delays.make(rnd()*100+200).next(turnloop)
  end
  turnloop()
end

--local flicker_count = 1
local intro_landing = false
function _update()
  delays.process(function()
    tweens.advance()
  end)
  if intro_screen then
    sprites.draw()

    if not intro_landing and (btn(0) or btn(1) or btn(2) or btn(3)) then
      sfx(10)
      intro_landing=true
      player.sprite_id=2
      local faketile=sprites.make(90,{x=50,y=75-128,z=5})

      promises.all({
        tweens.make(faketile,'x',0,50),
        tweens.make(faketile,'y',-128,50),
        tweens.make(faketile,'scale',16,50),
        tweens.make(stars_obj,'y',55,50),
        tweens.make(stars_obj,'speed',10,50),
        tweens.make(stars_obj,'spread',12,50,'quadratic'),
        tweens.make(start_tile,'y',-128+56,50),
        tweens.make(start_tile,'x',56,50),
        tweens.make(start_tile,'scale',1,50),
        tweens.make(player,'scale',1,50),
        tweens.make(player,'x',56,50),
        tweens.make(player,'y',-128+56,50)
      }).next(function()
        cam.y+=128
        player.y+=128
        intro_screen=false
        faketile.kill()
        start_tile.kill()
        player.sprite_id=0
        player.z=100
      end)
    end
  else
    return fighting.update() or update_walkabout()
  end
end

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

staroffset = 0
stars_obj={
  alive=true,
  spread=1,
  speed=1,
  y=112
}
function _draw()
  cam.apply()

  if intro_screen then
    rectfill(0,-128,127,-1,0)
    sprites.draw(nil,9)
    staroffset+=.1846*stars_obj.speed
    local scale=200
    local x
    local y
    local colormap = {8,5,2,6,7,14}
    --local colormap = {1,5,2,6,14}
    local color
    local step = .63
    for starn=5+staroffset/100,200+staroffset/100,step do
      --pset(64+cos(starn/5)*starn,-1-abs(sin(starn))*starn*2,flr(starn%14)+1)
      x = 58+cos(starn)*starn*stars_obj.spread
      y = -128+stars_obj.y+sin(starn)*starn*stars_obj.spread
      if x < 136 and x > -8 and y < 8 and y > -136 then
        --color = flr((starn-staroffset/100)/step)%14+1
        color = colormap[flr((starn-staroffset/100)/step)%#colormap+1]
        --rectfill(x,y,x+31,y+31,color)

        --pset(x,y,color)
        pal(8,color)
        spr(10,x-4,y-4)
        --zspr(10,1,1,x,y,false,false,2,2)
      end
    end
    pal()
    fancy_print("mATERIAL gIRL", 15,-122,1,8)
    fancy_print("BY jOHN wILKINSON", 45,-110,1,8)
  end

  if fighting.draw() then
    return
  end

  if inventory.current_store_index < 5 and not gate then
    gate = make_pool()
    gate.make(sprites.make(8,{x=120,y=64,z=60}))
    gate.make(sprites.make(8,{x=120,y=56,z=60}))
  end

  if not doors then
    doors = make_pool()
    for door in all(calc_doors()) do
      if door.y > 8 then
        if door.open then
          doors.make(sprites.make(28,{x=door.x*8,y=door.y*8,z=120}))
          doors.make(sprites.make(29,{x=door.x*8,y=door.y*8-8,z=120}))
        end
      else
        local sprite_id
        if door.open then
          sprite_id = 37
        else
          sprite_id = 46
        end
        doors.make(sprites.make(sprite_id,{x=door.x*8,y=door.y*8,z=60}))
      end
    end
  end

  --walkabout
  palt(0,false)
  map(0,0,0,0,128,128,1)
  palt()
  sprites.draw(10,150)
  palt(0,false)
  map(0,0,0,0,128,128,4)
  palt()
  sprites.draw(151,nil)
  if open_door() and sale then
    fancy_print(sale.text,sale.x,sale.y,1,sale.color)
  end
end
-- END LIB
