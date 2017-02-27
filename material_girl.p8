pico-8 cartridge // http://www.pico-8.com
version 8
__lua__

-- start ext ./sprites.p8
--credit: matt+charlie_says http://www.lexaloffle.com/bbs/?tid=2429
function zspr(n,w,h,dx,dy,dz,zflp,stretch_x,stretch_y)
 stretch_x = stretch_x or dz
 stretch_y = stretch_y or dz
 local sx = (n%16)*8 --corrected from: 8 * flr(n / 32)
 local sy = flr(n/16)*8 --corrected from: 16 * (n % 32)
 local sw = 8 * w
 local sh = 8 * h
 local dw = sw * stretch_x
 local dh = sh * stretch_y

 sspr(sx,sy,sw,sh, dx,dy,dw,dh, zflp)
end

cam = {
 x = 0,
 y = 0,
 alive = true,
 apply = function()
  camera(cam.x,cam.y)
 end
}

-- adapted from http://www.lexaloffle.com/bbs/?pid=18374#p18374
function heapsort(t, cmp)
 local n = #t
 if n <= 1 then
  return
 end
 local i, j, temp
 local lower = flr(n / 2) + 1
 local upper = n
 cmp = cmp or function(a,b)
  if a < b then
   return -1
  elseif a == b then
   return 0
  else
   return 1
  end
 end
 while 1 do
  if lower > 1 then
   lower -= 1
   temp = t[lower]
  else
   temp = t[upper]
   t[upper] = t[1]
   upper -= 1
   if upper == 1 then
    t[1] = temp
    return
   end
  end

  i = lower
  j = lower * 2
  while j <= upper do
   if j < upper and cmp(t[j], t[j+1]) < 0 then
    j += 1
   end
   if cmp(temp, t[j]) < 0 then
    t[i] = t[j]
    i = j
    j += i
   else
    j = upper + 1
   end
  end
  t[i] = temp
 end
end

-- sprite stuffs
make_pool = function()
 local store = {}
 local id_counter = 0
 local each = function(f)
  for v in all(store) do
   if v.alive then
    f(v)
   end
  end
 end
 return {
  each = each,
  each_in_order = function(key, default, f)
   local sorted = {}
   each(function(v)
    add(sorted,v)
   end)
   heapsort(sorted,function(a,b)
    a = a[key] or default
    b = b[key] or default
    if a < b then
     return -1
    elseif a == b then
     return 0
    else
     return 1
    end
   end)
   for _,val in pairs(sorted) do
    f(val)
   end
  end,
  store = store,
  make = function(obj)
   obj = obj or {}
   obj.alive = true
   local id = false

   for k,v in pairs(store) do
    if not v.alive then
     id = k
    end
   end

   if not id then
    id_counter+= 1
    id = id_counter
   end
   store[id] = obj
   obj.kill = function()
    obj.alive = false
   end
  end
 }
end

sprites = {
 pool = make_pool(),
 make = function(sprite_id, properties)
  properties = properties or {}
  properties.sprite_id = sprite_id
  properties.scale = properties.scale or 1
  if properties.flip == nil then
   properties.flip = false
  end
  if properties.rounded_position != nil then
   properties.rounded_position = true
  end
  if properties.rounded_scale != nil then
   properties.rounded_scale = true
  end
  if properties.walking_scale == nil then
   properties.walking_scale = 1
  end
  sprites.pool.make(properties)
  return properties
 end,
 draw = function(min_z,max_z)
  sprites.pool.each_in_order('z',0,function(s)
   if s.hide then
    return
   end

   if min_z and s.z and s.z < min_z then
    return
   end

   if max_z and s.z and s.z > max_z then
    return
   end

   if s.before_draw then
    s.before_draw()
   end

   local x = s.x
   local y = s.y
   local scale_x = s.scale_x or s.scale
   local scale_y = s.scale_y or s.scale
   local sprite_id = s.sprite_id

   if s.rounded_scale then
    s.scale_x = flr(scale_x+0.5)
    s.scale_y = flr(scale_y+0.5)
   end
   if s.centered then
    local anchor_x = s.anchor_x or 0.5
    local anchor_y = s.anchor_y or 0.5
    if s.flip then
     anchor_x = 1-anchor_x
     anchor_y = 1-anchor_y
    end
    x-= anchor_x*8*scale_x
    y-= anchor_y*8*scale_y
   end
   if s.relative_to_cam then
    x+= cam.x
    y+= cam.y
   end
   if s.rounded_position then
    x = flr(x+0.5)
    y = flr(y+0.5)
   end
   if s.walking then
    local frame_index = ((flr(x)+flr(y)) % (s.walking_scale * #s.walking_frames))/s.walking_scale
    --local frame_index = (flr(x)+flr(y)) % #s.walking_frames
    sprite_id = s.walking_frames[flr(frame_index)+1]
   end

   zspr(sprite_id,1,1,x,y,nil,s.flip,scale_x,scale_y)

   pal()
  end)
 end
}

tweens = {
 easings = {
  linear = function(k)
   return k
  end,
  quadratic = function(k)
   return k*k
  end,
  cubic = function(k)
   return k*k*k
  end,
  circular = function(k) -- this might technically be "sine"
   return 1-cos(k/4)
  end,
  bounce_out = function(k) -- from https://github.com/photonstorm/phaser/blob/v2.4.6/src/tween/Easing.js
   if k < ( 1 / 2.75 ) then
    return(7.5625 * k * k)
   elseif k < ( 2 / 2.75 ) then
    k -=  1.5 / 2.75
    return(7.5625 * k * k + 0.75)
   elseif k < ( 2.5 / 2.75 ) then
    k -= 2.25 / 2.75
    return(7.5625 * k * k + 0.9375)
   else
    k -= 2.625 / 2.75
    return(7.5625 * k * k + 0.984375)
   end
  end,
  merge = function(ease_in,ease_out)
   return function(k)
    return 1 - ease_out(1-ease_in(k))
   end
  end
 },
 pool = make_pool(),
 make = function(sprite,property,final,tim,easing)
  local time=tim
  local initial = sprite[property]
  local diff = final - initial
  local count = 0
  local easing = easing or function(k)
   return k
  end
  local tween = {}
  tween.advance = function()
   if not sprite.alive then
    tween.kill()
    return
   end
   count+= 1
   local out
   if tween.ease_in_and_out then
    out = initial + diff*(1-(easing(1-easing(count/time))))
   elseif tween.ease_out then
    out = initial + diff*(1-(easing(1-count/time)))
   else
    out = initial + diff*easing(count/time)
   end
   if tween.rounding then
    out = flr(out+0.5)
   end
   sprite[property] = out
   if count >= time then
    tween.kill()
    if tween.on_complete then
     tween.on_complete()
    end
   end
  end
  tweens.pool.make(tween)
  return tween
 end,
 advance = function()
  tweens.pool.each(function(t)
   t.advance()
  end)
 end
}
-- end ext

-- start ext inventory.lua
function make_inventory()
 local dress_light_color_map = {11,14,10,13}
 local dress_dark_color_map = {3,2,9,1}
 local lipstick_color_map = {8,14,13,2}
 local ring_color_map = {14,13,9,8}
 local shoes_color_map = {4,5,7,8}
 local equipped_items = {1,1,1,1}
 local owned_hearts = {}
 local obj = {
  store_sprite_map = {41,39,40,38},
  dress_light_color = 11,
  dress_dark_color = 3,
  ring_color = 14,
  lipstick_color = 8,
  shoes_color = 4,
  hearts_count = 0,
  equipped_items = equipped_items
 }

 obj.add_heart = function()
  local heart = sprites.make(10,{x=5+9*obj.hearts_count,y=-12,z=200})
  heart.relative_to_cam=true
  heart.centered=true
  tweens.make(heart,'y',5,30,tweens.easings.bounce_out)
  add(owned_hearts,heart)
  obj.hearts_count += 1
 end

 obj.remove_heart = function()
  local heart = owned_hearts[obj.hearts_count]
  owned_hearts[obj.hearts_count] = nil
  obj.hearts_count-= 1
  heart.before_draw = function()
   pal(8,1)
  end
  heart.z = 220
  tweens.make(heart,'scale',3,10).on_complete = heart.kill
 end

 obj.ring_strength = function()
  return equipped_items[3]
 end

 obj.dress_strength = function()
  return equipped_items[1]
 end

 obj.shoes_strength = function()
  return equipped_items[4]
 end

 obj.lipstick_strength = function()
  return equipped_items[2]
 end

 obj.all_max = function()
  return obj.ring_strength() == 4 and obj.dress_strength() == 4 and obj.shoes_strength() == 4 and obj.lipstick_strength() == 4
 end

 -- obj.destroy_hearts = function()
 --  for _,h in pairs(owned_hearts) do
 --   tweens.make(h,'y',4)
 -- end

 for i=1,4,1 do
  obj.add_heart()
 end

 local function update_ring(index)
  obj.ring_color = ring_color_map[index]
 end

 local function update_dress(index)
  obj.dress_light_color = dress_light_color_map[index]
  obj.dress_dark_color = dress_dark_color_map[index]
 end

 local function update_shoes(index)
  obj.shoes_color = shoes_color_map[index]
 end

 local function update_lipstick(index)
  obj.lipstick_color = lipstick_color_map[index]
 end

 obj.update_item = function(store_index, item_index)
  local price = obj.price_by_store_and_selection(store_index,item_index)
  if price < 0 then
   for i=0,price+1,-1 do
    obj.add_heart()
   end
  elseif price > 0 then
   for i=0,price-1,1 do
    obj.remove_heart()
   end
  end

  equipped_items[store_index] = item_index
  if store_index == 1 then
   update_dress(item_index)
  elseif store_index == 2 then
   update_lipstick(item_index)
  elseif store_index == 3 then
   update_ring(item_index)
  elseif store_index == 4 then
   update_shoes(item_index)
  end
 end

 obj.remap_girl_colors = function()
  pal(14,obj.ring_color)
  pal(8,obj.lipstick_color)
  pal(11,obj.dress_light_color)
  pal(3,obj.dress_dark_color)
  pal(4,obj.shoes_color)
 end

 obj.remap_store_colors = function(store_index, item_index)
  if store_index == 1 then
   pal(14,dress_light_color_map[item_index]) --pink
   pal(2,dress_dark_color_map[item_index]) --purple
  elseif store_index == 2 then
   pal(8,lipstick_color_map[item_index]) --red
  elseif store_index == 3 then
   pal(7,ring_color_map[item_index])
  elseif store_index == 4 then
   pal(8,shoes_color_map[item_index]) --red
  end
 end

 obj.remap_kiss = function()
  pal(8,obj.lipstick_color)
 end

 obj.remap_hearts = function()
  pal(8,obj.ring_color)
 end

 obj.price_by_store_and_selection = function(store_i,selection_i)
  local selection = equipped_items[store_i]
  if selection == selection_i then
   return 0
  else
   return selection_i - selection + 1
  end
 end

 obj.number_of_affordable_by_store = function(store_i)
  local net_funds = equipped_items[store_i] + obj.hearts_count - 1
  if net_funds > 4 then
   return 4
  else
   return net_funds
  end
 end

 return obj
end
-- end ext

-- start ext store.lua
-- depends on:
-- store - global var to store current store
-- exit_door() - walkabout method
-- zspr - sprite helper function
-- player - global
function make_menu(item_length)
 local obj
 local move_pressed=true
 local select_pressed=false

 local function check_buttons()
  if move_pressed then
   if not btn(0) and not btn(1) and not btn(2) and not btn(3) then
    move_pressed=false
   end
  else
   if (btn(0) or btn(2)) and not (btn(1) or btn(3)) then
    obj.selection_index-=1
    move_pressed=true
   end
   if (btn(1) or btn(3)) and not (btn(0) or btn(2)) then
    obj.selection_index+=1
    move_pressed=true
   end
  end
  if obj.selection_index<0 then obj.selection_index=item_length-1 end
  if obj.selection_index>=item_length then obj.selection_index=0 end

  if select_pressed then
   obj.selected = false
   if not btn(4) then
    select_pressed = false
   end
  elseif btn(4) then
    select_pressed = true
    obj.selected = true
  end
 end

 obj = {
  check_buttons = check_buttons,
  selection_index = 0,
  selected = false
 }

 return obj
end

function make_store(inv)
 local obj
 local menu
 local started
 local store_index
 local store_sprite_index

 local function update_store()
  if not started then
   return false
  end

  menu.check_buttons()

  if menu.selected then
   inv.update_item(store_index, menu.selection_index+1)
   player.y=exit_door_y(player.x,player.y)
   store=make_store(inv)
   return false
  end

  return true
 end

 local function draw_hearts(y, selection_index)
  if inv.equipped_items[store_index] == selection_index then
   cursor(54,y+1)
   color(7)
   print("owned")
  else
   price = inv.price_by_store_and_selection(store_index,selection_index)
   if price == 0 then
    cursor(56,y+1)
    color(7)
    print("free")
   else
    pal()
    if price < 0 then
     price = 0-price
     pal(8,11)
    end
    for i=0,price-1,1 do
     zspr(10,1,1,60-8*(price-1)/2+8*i,y-1,1,false)
    end
   end
  end
 end

 local function draw_store()
  if started then
   local colors={6,6,6,6}
   colors[menu.selection_index+1]=14
   rectfill(8,22,119,105,0)
   rectfill(9,23,118,104,7)
   rectfill(10,24,117,103,0)
   rectfill(13,27,46,60,colors[1])
   rectfill(47,28,79,40,colors[1])

   rectfill(81,27,114,60,colors[2])
   rectfill(48,47,80,59,colors[2])

   rectfill(13,67,46,100,colors[3])
   rectfill(47,68,79,80,colors[3])

   rectfill(81,67,114,100,colors[4])
   rectfill(48,87,80,99,colors[4])
   inv.remap_store_colors(store_index,1)
   zspr(store_sprite_index,1,1,14,28,4,false)
   inv.remap_store_colors(store_index,2)
   zspr(store_sprite_index,1,1,82,28,4,false)
   inv.remap_store_colors(store_index,3)
   zspr(store_sprite_index,1,1,14,68,4,false)
   inv.remap_store_colors(store_index,4)
   zspr(store_sprite_index,1,1,82,68,4,false)
   pal()
   draw_hearts(32,1)
   draw_hearts(51,2)
   draw_hearts(72,3)
   draw_hearts(91,4)
   return true
  else
   return false
  end
 end

 obj = {
  update = update_store,
  draw = draw_store,
  start = function(store_i)
   menu = make_menu(inv.number_of_affordable_by_store(store_i))
   store_index = store_i
   store_sprite_index = inv.store_sprite_map[store_index]
   started = true
  end
 }

 return obj
end
-- end ext


-- start ext fight.lua
-- depends on:
-- zspr - sprite helper function
----
-- Fight factory - call this to generate a new fight
----
-- starts as inactive, calls to update/draw will noop
-- start() - activates the fight
-- update() - update step logic, returns false if inactive
-- draw() - perform draw step, returns false if inactive
-- when the fight is finished it will deactivate itself
-- when you want a new fight, discard the old object and create a new one
function make_fight()
 local obj, fanim, first_draw, kiss --misc fight state
 local ofpx, ofpy, cfpx --player state
 local fighter, enemy --sprites
 local enemy_data
 local text_needs_clearing
 local intro_slide
 local intro_textbox
 local game_over
 local clouds = make_pool()
 local sun

 ----
 -- fighting animation update logic
 ----
 -- designed to be called each update loop
 -- start_fanim() kicks off the animation state and initializes
 -- must set fanim=false on completion to indicate no longer in animation state
 ----
 local function start_fanim()
  if fanim then
   return false
  else
   fanim=true
   return true
  end
 end

 local function reset_combat_cursor()
  cursor(128+24+2,73)
 end

 local function clear_text()
  palt(0,false)
  map(19,9,128+24,72,16,7)
  palt()
  reset_combat_cursor()
 end

 local function index_to_action(index)
  if index == 0 then
   return "attack"
  elseif index == 1 then
   return "magic"
  elseif index == 2 then
   return "run"
  end
 end

 local function exit_battle()
  clouds.each(function(c)
   c.kill()
  end)
  sun.kill()
  enemy.kill()
  fighter.kill()
  cam.x = 0
  cam.y = 0
  sprites.make(player.sprite_id,player).flip = true
  player.x-=4
  obj.active = false
 end

 local function jump_to_closeness(on_complete)
  cfpx = flr(enemy_data.closeness*(enemy_data.base_x-ofpx-16)+ofpx+0.5)

  fighter.sprite_id = 1

  tweens.make(fighter,'x',cfpx,10)
  local jump_up = tweens.make(fighter,'y',fighter.y-10,5,tweens.easings.quadratic)
  jump_up.ease_out = true
  jump_up.on_complete = function()
   tweens.make(fighter,'y',ofpy,5,tweens.easings.quadratic).on_complete = function()
    fighter.sprite_id = 0
    on_complete()
   end
  end
 end

 local function fenemy_attack()
  enemy_data.current_action.start()
  enemy.sprite_id=5

  fanim = function()
  end

  tweens.make(enemy,'x',fighter.x+24,10,tweens.easings.quadratic).on_complete = function()
   enemy.sprite_id = 6
   --local attack_result = enemy_data.attack_player()
   if true then --attack_result.success then
    enemy_data.current_action.middle()

    if enemy_data.current_action.lose then
     enemy.sprite_id = 4
     fighter.sprite_id = 2
     local falling = tweens.make(fighter,'x',fighter.x-8,40,tweens.easings.quadratic)
     falling.ease_out = true
     falling.on_complete = function()
      fanim = false
     end
    else
     jump_to_closeness(function()
     end)

     local rising = tweens.make(enemy,'y',enemy_data.base_y-10,7,tweens.easings.quadratic)
     rising.ease_out = true
     rising.on_complete = function()
      tweens.make(enemy,'y',enemy_data.base_y,7,tweens.easings.quadratic)
     end
     local pull_back = tweens.make(enemy,'x',enemy_data.base_x,14,tweens.easings.quadratic)
     pull_back.ease_out=true
     pull_back.on_complete = function()
      enemy.sprite_id = 4
      fanim = false
     end
    end
   else
    color(14)
    print "not interested..."
    fighter.flip=true
    fighter.x -= 8
    local pull_back = tweens.make(enemy,'x',enemy_data.base_x,14)
    pull_back.ease_in_and_out = true
    pull_back.on_complete = function()
     enemy.sprite_id = 4
     fighter.flip = false
     fighter.x = cfpx
     fanim=false
    end
   end
  end
 end


 function make_cloud(x)
  local prox = rnd()
  local cloud = sprites.make(flr(64+rnd()*3),{
   x=(x or rnd()*128),
   y=(rnd()*16),
   z=9+prox,
   centered=true,
   scale_x=prox*6+2,
   scale_y=2, --rnd()+1,
   rounded_scale=true,
   --scale=prox+1,
   relative_to_cam=true
  })
  clouds.make(cloud)
  tweens.make(cloud,'x',0-cloud.scale_x*4,(cloud.x+20)*10/(0.5+3*prox*prox)).on_complete = cloud.kill
 end

 function fintro()
  fighter = sprites.make(0,{x=player.x+4,y=player.y+4,z=100,walking_scale=2}) -- +4 because centered
  cam.player_x = fighter.x
  player.kill()

  fighter.before_draw = function()
   inventory.remap_girl_colors()
  end
  fighter.centered = true

  for i=1,4 do make_cloud() end

  sun = sprites.make(51,{x=116,y=5,z=1,relative_to_cam=true,centered=true,rounded_position=true})

  local after_fighter = nil

  fanim=function()
  end

  tweens.make(intro_textbox,'y',48,60,tweens.easings.quadratic).ease_in_and_out=true

  fighter.walking_frames = {0,1,0,2}
  fighter.walking = true

  tweens.make(cam,'x',24,20).rounding=true
  tweens.make(fighter,'x',128+4,5).on_complete = function()
   tweens.make(fighter,'y',fighter.y+8,10)
   tweens.make(fighter,'x',128+13,15).on_complete = function()
    tweens.make(fighter,'y',coastline_y,50).on_complete = function()
     tweens.make(cam,'x',128+24,60).rounding=true
     tweens.make(fighter,'x',ofpx-24,20).on_complete = function()
      tweens.make(fighter,'x',ofpx,20)
      tweens.make(fighter,'y',ofpy,40,tweens.easings.quadratic)
      tweens.make(fighter,'scale',4,40,tweens.easings.quadratic).on_complete = function()
       fighter.walking = false
       after_fighter()
      end
     end
    end
   end
  end

  after_fighter = function()
   enemy.hide = false
   enemy.walking=true
   --tweens.make(enemy,'scale',4,20,tweens.easings.quadratic).ease_out = true
   local e_slide_in = tweens.make(enemy,'x',enemy_data.base_x,40,tweens.easings.quadratic)
   e_slide_in.ease_out = true
   e_slide_in.on_complete = function()
    --enemy_data.intro_speech()
    fanim = false
    intro_slide = false
    enemy.walking=false
   end
  end
 end

 local function flose()
  fanim = function()
  end

  fighter.sprite_id = 48

  enemy_data.current_action.start()
  enemy.flip = true
  enemy.walking=true
  tweens.make(enemy,'x',cam.x+128+16,30,tweens.easings.cubic).on_complete = function()
    enemy_data.current_action.middle()
    game_over = true
    fighter.before_draw = function()
      pal(7,14)
      pal(11,14)
      pal(10,14)
      pal(4,14)
      pal(12,14)
      pal(15,2)
      pal(14,2)
      pal(3,2)
      pal(8,2)
    end
  end
 end

 local function fwin()
  if inventory.all_max() then
   queue_text(function()
    color(11)
    print("you win! probably...")
    print("i havne't gotten this far")
    print("with the programming but")
    print("good job! :D")
    print("(sorry haha)")
   end)
  end

  local winwait=60
  local win_heart = sprites.make(10,{x=fighter.x+16,y=enemy.y+8,scale=8,centered=true,z=40})
  local tweening = false
  fanim = function()
   if winwait>0 then
    if flr(((80-winwait)/20)^2) % 2 == 0 then
     enemy.z = 20
    else
     enemy.z = 50
    end
    winwait-=1
   end
  end
  local float = tweens.make(enemy,'y',enemy.y-4,50,tweens.easings.quadratic)
  float.on_complete = function()
   fighter.sprite_id = 0
   enemy.kill()
   kiss=false
   local slide_out = tweens.make(win_heart,'x',fighter.x-32,12,tweens.easings.circular)
   slide_out.ease_out = true
   slide_out.on_complete = function()
    win_heart.z = 120
    tweens.make(win_heart,'x',fighter.x,12,tweens.easings.circular)
   end
   local slide_down = tweens.make(win_heart,'y',fighter.y+20,12,tweens.easings.circular)
   slide_down.ease_out = true
   slide_down.on_complete = function()
    tweens.make(win_heart,'y',fighter.y,12,tweens.easings.circular)
   end
   tweens.make(win_heart,'scale',1,24,tweens.easings.quadratic).on_complete = function()
    inventory.add_heart()
    win_heart.kill()
    fighter.sprite_id = 2
    local jump = tweens.make(fighter,'y',fighter.y-5,14,tweens.easings.cubic)
    jump.ease_out = true
    jump.on_complete = exit_battle
   end
  end
 end

 local function fmove()
  enemy_data.current_action.start()

  fanim = function()
  end

  jump_to_closeness(function()
    enemy_data.current_action.middle()
    fanim = false
  end)
 end

 local function fattack()
  enemy_data.current_action.start()

  fanim = function()
  end

  fighter.walking = true

  approach_easing = tweens.easings.merge(tweens.easings.quadratic,tweens.easings.cubic)
  local approach = tweens.make(fighter,'x',enemy.x-16,20,approach_easing)
  --approach.ease_in_and_out = true
  approach.on_complete = function()
   fighter.walking = false
   fanim = function()
   end

   enemy_data.current_action.middle()
   kiss=flr(rnd()*5+11)
   enemy.x+=8
   enemy.sprite_id=6

   if enemy_data.current_action.win then
    fanim = false
   else
    local recede = tweens.make(fighter,'x',cfpx,12,tweens.easings.quadratic)
    fighter.sprite_id = 2
    recede.ease_in_and_out=true
    recede.on_complete = function()
     fighter.sprite_id=0
     kiss=false
     enemy.sprite_id=4
     enemy.x=enemy_data.base_x
     fanim=false
    end
   end
  end
 end

 local function fattack_fail()
  enemy_data.current_action.start()

  fanim = function()
    fighter.sprite_id = flr(fighter.x/6)%3
  end

  approach_easing = tweens.easings.merge(tweens.easings.quadratic,tweens.easings.cubic)
  local approach = tweens.make(fighter,'x',enemy.x-16,20,approach_easing)
  --approach.ease_in_and_out = true
  approach.on_complete = function()
   enemy_data.current_action.middle()

   fanim = function()
   end
   enemy.flip=true
   enemy.x+=8
   if enemy_data.hp <= 0 then
    fwin()
   else
    local recede = tweens.make(fighter,'x',cfpx,12,tweens.easings.quadratic)
    fighter.sprite_id = 2
    recede.ease_in_and_out=true
    recede.on_complete = function()
     fighter.sprite_id=0
     kiss=false
     enemy.sprite_id=4
     enemy.x=enemy_data.base_x
     fanim=false
     enemy.flip=false
    end
   end
  end
 end

 local function fmagic()
  local spinx = fighter.x
  fighter.sprite_id = 1

  fanim = function()
  end

  local rising = tweens.make(fighter,'y',ofpy-10,5)
  rising.ease_out = true
  rising.on_complete = function()
   tweens.make(fighter,'y',ofpy,5)
  end
  tweens.make(fighter,'scale',5,10).on_complete = function()
   enemy_data.current_action.start()
   fighter.sprite_id=2
   magwait=30
   --magwaitx=fpx
   local counter=0
   local hearts = {}


    fighter.scale_x = 4
    fighter.anchor_x = 0.68
    local spinning = {delay=5,alive=true,tween=nil}
    local delay_tween = tweens.make(spinning,'delay',1,40+8*inventory.hearts_count,tweens.easings.quadratic)
    delay_tween.ease_out = true
    delay_tween.on_complete = function()
     spinning.tween.kill()
     enemy.x = enemy_data.base_x
     enemy.sprite_id=4
     fighter.flip = false
     fighter.scale_x = nil
     fighter.anchor_x = nil
     enemy_data.current_action.middle()
     tweens.make(fighter,'scale',4,10).on_complete = function()
      fighter.sprite_id = 0
      fanim=false
     end
    end

    do_spin = function()
     spinning.tween = tweens.make(fighter,'scale_x',1,spinning.delay,tweens.easings.circular)
     spinning.tween.on_complete = function()
      fighter.flip = not fighter.flip
      spinning.tween = tweens.make(fighter,'scale_x',4,spinning.delay,tweens.easings.circular)
      spinning.tween.ease_out = true
      spinning.tween.on_complete = function()
       do_spin()
      end
     end
    end
    do_spin()

   local hearts_to_make = inventory.hearts_count

   fanim = function()
    magwait-=1

    if magwait <= 20 and magwait%5 == 0 and hearts_to_make > 0 then
      hearts_to_make-=1
      counter+=2
      local h = sprites.make(10,{x=fighter.x+9+counter,y=fighter.y-10+20*rnd(),z=100+counter})
      h.before_draw = function()
       pal(8,inventory.ring_color)
      end
      h.centered = true
      h.flight_tween = tweens.make(h,'x',cam.x+131,10+5*(4-inventory.ring_strength()),tweens.easings.cubic)
      add(hearts,h)
    end

    for _,h in pairs(hearts) do
     if h.alive and h.z > 100 and h.x > enemy.x then
      enemy.x+=4
      enemy.sprite_id = 6
      h.flight_tween.kill()
      tweens.make(h,'x',enemy.x+20,5)
      tweens.make(h,'scale',4,5).on_complete = h.kill
      h.z-= 60
     end
    end
   end
  end
 end

 local function frun()
  enemy_data.current_action.start()
  fighter.walking = true
  fanim = function()
  end
  enemy.walking=true
  enemy_approach = tweens.make(enemy,'x',enemy.x-10,6,tweens.easings.quadratic)
  enemy_approach.ease_in_and_out = true
  enemy_approach.on_complete = function()
   enemy.walking=false
   enemy_data.current_action.middle()
   enemy.flip = true
   tweens.make(fighter,'y',fighter.y-24,60)
   tweens.make(fighter,'x',-16,60,tweens.easings.quadratic).on_complete = function()
    fighter.walking=false
    exit_battle()
   end
   tweens.make(fighter,'scale',1,60,tweens.easings.quadratic)
  end
 end

 local function fflee()
  enemy_data.current_action.start()
  enemy.walking = true
  fanim = function()
  end
  enemy.flip=true
  enemy_data.current_action.middle()
  tweens.make(enemy,'x',cam.x+140,60,tweens.easings.quadratic).on_complete = function()
   enemy.walking=false
   exit_battle()
  end
 end

 local function frun_fail()
  clear_text()
  color(14)
  print "screw this!"
  fighter.sprite_id = 2
  fanim = function()
  end
  fighter.x-=4
  local tw_in = tweens.make(enemy,'x',fighter.x+30,10,tweens.easings.cubic)
  tw_in.ease_in_and_out = true
  tw_in.on_complete = function()
   local tw_out = tweens.make(enemy,'x',enemy_data.base_x,20,tweens.easings.quadratic)
   tw_out.ease_in_and_out = true
   tw_out.on_complete = function()
    fighter.x = cfpx
    fighter.sprite_id = 0
    fanim=false
   end
  end
 end

 local function press_key(sprite_id,left_x,top_y)
  local key = sprites.make(sprite_id,{x=left_x+4,y=top_y+4})
  key.centered = true
  key.relative_to_cam = true
  tweens.make(key,'scale',2,5).on_complete = key.kill
  queue_text(clear_text)
 end

 local function detect_keys()
  if btn(0) and not btn(1) and not btn(2) then
   press_key(43,25,61)
   enemy_data.withdraw()
   return true
  end
  if btn(1) and not btn(0) and not btn(2) then
   press_key(44,67,61)
   enemy_data.advance()
   return true
  end
  if btn(2) and not btn(0) and not btn(1) then
   press_key(42,46,53)
   enemy_data.dazzle(inventory.hearts_count)
   return true
  end

  return false
 end

 local function update_fight()
  if not obj.active then
   return false
  end

  if rnd() < 0.005 then
   make_cloud(128+32)
  end

  if rnd() < 0.01 then
   sun.scale_x = 1+rnd()*0.2
   sun.scale_y = 1+rnd()*0.2
  end

  if fanim then
   fanim()
   return true
  end

  local next_action = enemy_data.advance_action()

  if next_action or detect_keys() then
   if enemy_data.current_action.name == 'run' then
    frun()
   elseif enemy_data.current_action.name == 'attack' then
    fattack()
   elseif enemy_data.current_action.name == 'magic' then
    fmagic()
   elseif enemy_data.current_action.name == 'attack_fail' then
    fattack_fail()
   elseif enemy_data.current_action.name == 'counterattack' then
    fenemy_attack()
   elseif enemy_data.current_action.name == 'lose' then
    flose()
   elseif enemy_data.current_action.name == 'win' then
    fwin()
   elseif enemy_data.current_action.name == 'move' then
    fmove()
   elseif enemy_data.current_action.name == 'flee' then
    fflee()
   end
  end

  return true
 end

 -----------------------
 --Drawing fighting code
 -----------------------
 local function draw_fui()
  if not fanim then
   color(7)
   spr(43,cam.x+25,cam.y+61)
   print("withdraw",cam.x+34,cam.y+63)
   spr(42,cam.x+46,cam.y+53)
   print("dazzle",cam.x+55,cam.y+55)
   spr(44,cam.x+67,cam.y+61)
   print("advance",cam.x+76,cam.y+63)

   reset_combat_cursor()
  end
 end

 function draw_kiss()
  if kiss then
   if not kissx then
    kissx=enemy.x-6+rnd()*10
    kissy=enemy.y-14+rnd()*10
   end

   inventory.remap_kiss()
   spr(kiss,kissx,kissy)
   pal()
  else
   kissx=false
   kissy=false
  end
 end

 local function draw_stat(percentage, left_x, top_y, color)
  local bar_width
  if percentage > 1 then
   bar_width = 20
  elseif percentage < 0 then
   bar_width = 0
  else
   bar_width = flr(20*percentage)
  end
  rectfill(cam.x+left_x,cam.y+top_y,cam.x+left_x+21,cam.y+top_y+2,5)
  if bar_width > 0 then
   rectfill(cam.x+left_x+21-bar_width,cam.y+top_y+1,cam.x+left_x+20,cam.y+top_y+1,color)
  end
  if bar_width < 20 then
   rectfill(cam.x+left_x+1,cam.y+top_y+1,cam.x+left_x+20-bar_width,cam.y+top_y+1,0)
  end
 end

 local function draw_enemy_stats()
  draw_stat(enemy_data.closeness,105,58,8)
  draw_stat(enemy_data.patience,105,62,9)
  draw_stat(enemy_data.attraction,105,66,10)
 end

 local function draw_fight()
  if obj.active then
   draw_text()
   if game_over then
    rectfill(128+24,0,127+128+24,71,8)
    sprites.draw(20,nil)
   elseif intro_slide then
    --clear above text

    map(16+3,0,cam.x,0,16,2) --sky
    sprites.draw(nil,19)

    palt(0,false)
    map(0,6,0,48,19,10) --bottom half of town
    --transition+beach

    map(16,2,128,16,32,4) --beach

    palt()

    palt(0,false)
    map(0,0,0,0,16,8) --top half of town
    map(19,6,cam.x,intro_textbox.y,16,10) --textbox
    palt()

    sprites.draw(20,nil)
   else
    --clear above text
    --rectfill(0,0,127,69,0)
    map(16+3,0,cam.x,0,16,2)
    sprites.draw(nil,10)
    palt(0,false)
    map(19,2,cam.x,16,16,7)
    palt()
    draw_fui()
    --draw_enemy_stats()
    sprites.draw(11,nil)
    draw_kiss()
   end
   return true
  else
   return false
  end
 end

 --object initialization and return
 obj = {
  update = update_fight,
  draw = draw_fight,
  start = function()
   --queue_text(cls)

   intro_slide = true
   intro_textbox = {
    alive=true,
    y=128
   }

   ofpx=128+24+26
   cfpx=ofpx
   ofpy=26
   coastline_y=ofpy-8

   enemy_data = make_enemy(fighter,{x=256+128,y=ofpy,z=50,hide=true,scale=4,walking_scale=2})
   enemy = enemy_data.sprite

   obj.active = true
   fintro()
  end,
  active = false
 }

 return obj
end
-- end ext

-- start ext enemy.p8
make_enemy = function(player,attributes)
 local sprite = sprites.make(4,attributes)
 sprite.centered = true
 sprite.walking_frames = {4,5,4,6}
 local player_def = inventory.equipped_items[1]-1
 local action_index = 1
 local obj
 local deferred_action = nil

 local stat_speech = {
  closeness={
   high=function()
    color(14)
    print("we draw apart")
    print("but i still feel close to him")
   end,
   mid=function()
    color(14)
    print("there's a divide between us but")
    print("we're closer than we once were")
   end,
   low=function()
    color(14)
    print("he feels so far away")
   end
  },
  patience={
   high=function()
    color(12)
    print("hah, such a goofball")
   end,
   mid=function()
    color(12)
    print("your quirks test my patience")
   end,
   low=function()
    color(12)
    print("if you can't respect my time")
    print("then i can't respect you")
   end
  },
  attraction={
   high=function()
    color(12)
    print("your beauty defies words")
    print("my life begins today")
   end,
   med=function()
    color(12)
    print("you're rather fetching")
   end,
   low=function()
    color(12)
    print("i'm sorry but")
    print("i think i need space")
   end
  }
 }

 local raise_multipliers = {
  closeness=function()
   return 1+inventory.shoes_strength()/2
  end,
  patience=inventory.lipstick_strength,
  attraction=function()
   return (4*inventory.ring_strength()+inventory.hearts_count)/3
  end
 }

 local lower_multipliers = {
  closeness=function()
   return 1+inventory.shoes_strength()/2
  end,
  patience=function()
   return inventory.shoes_strength()/4
  end,
  attraction=function()
  return inventory.lipstick_strength()*1.5-inventory.dress_strength()
  end
 }

 local function lower_stat(stat, multiplier)
  multiplier = multiplier or lower_multipliers[stat]()
  obj[stat]*= 1 - 0.2*(0.5+multiplier/2)
  if obj[stat] < 0.33 then
   queue_text(stat_speech[stat].low)
  elseif obj[stat] < 0.66 then
   queue_text(stat_speech[stat].mid)
  else
   queue_text(stat_speech[stat].high)
  end
 end

 local function raise_stat(stat, multiplier)
  multiplier = multiplier or raise_multipliers[stat]()
  obj[stat]+= (1-obj[stat])*0.1*(1+multiplier)
 end

 local function dazzle_check()
  return obj.closeness > 0.9 - inventory.ring_strength()/10
 end

 local function withdraw_check()
  return obj.closeness > 0.3
 end

 local function advance_check()
  return obj.closeness < 0.7
 end

 local function attack_check()
  return inventory.hearts_count/obj.attraction < (0.5+inventory.dress_strength()/2)*rnd()*10
 end

 local function counterattack_check()
  return obj.attraction < 0.5 and obj.attraction*obj.attraction < rnd()*0.25*(inventory.dress_strength()/2+0.5)
 end

 local function flee_check()
  return obj.patience < 0.5 and obj.patience*obj.patience < rnd()*0.25*(inventory.dress_strength()/2+0.5)
 end

 local function failed_withdraw_speech()
  color(12)
  print("i can't let go...")
  print("not yet")
 end

 local function withdraw_speech()
  color(12)
  print("i don't need you anyway")
 end

 local function reset_actions()
  deferred_action = nil
 end

 local function lose()
  obj.current_action = {
   name = 'lose',
   start = function()
    queue_text(function()
     color(14)
     print "i guess this is the end..."
    end)
   end,
   middle = function()
    queue_text(function()
     color(14)
     print "left forever to wonder"
     print "where things went wrong"
     color(8)
     print "game over"
     print "ctrl+r to retry"
    end)
   end
  }
 end

 local function win()
  obj.current_action = {
   name = 'win',
   start = function()
   end,
   middle = function()
   end
  }
 end

 local function counterattack()
  obj.current_action = {
   name = 'counterattack',
   start = function()
    queue_text(function()
     color(12)
     print "aint got nothin on this!"
    end)
   end,
   middle = function()
    queue_text(function()
     color(14)
     print "so hurtful.."
    end)
    inventory.remove_heart()
    if inventory.hearts_count <= 0 then
     obj.current_action.lose = true
     deferred_action = lose
    else
     lower_stat('closeness',1)
    end
   end
  }
 end

 local function flee()
  obj.current_action = {
   name = 'flee',
   start = function()
    queue_text(function()
     color(12)
     print "i have obligations elsewhere"
    end)
   end,
   middle = function()
    queue_text(function()
     color(12)
     print "perhaps another time"
    end)
   end
  }
 end

 local function attempt_counterattack()
  if counterattack_check() then
   deferred_action = counterattack
  elseif flee_check() then
   deferred_action = flee
  end
 end

 obj =  {
  sprite = sprite,
  hp = 5,
  def = 1,

  closeness = 0.2,
  attraction = 0.5,
  patience = 1.0,
  base_x = 128+24+96,
  base_y = 26,
  advance_action = function()
   local todo
   if deferred_action then
    todo = deferred_action
    deferred_action = nil
    todo()
    return true
   else
    obj.current_action = nil
    return nil
   end
  end,
  take_damage = function(damage)
   obj.hp -= damage
  end,
  withdraw = function()
   reset_actions()

   if withdraw_check() then
    lower_stat('closeness')

    obj.current_action = {
     name="move",
     start=function()
     end,
     middle=function()

      lower_stat('patience')
     end
    }
    attempt_counterattack()
   else
    obj.current_action = {
     name = 'run',
     start = function()
      queue_text(function()
       color(12)
       local picker = rnd()
       if picker < 0.6 then
        print "what of the time we shared?"
       elseif picker < 0.9 then
        print "do i mean nothing to you?"
       else
        print "i knew you were a mistake."
       end
      end)
     end,
     middle = function()
     queue_text(withdraw_speech)
    end
    }
   end
  end,
  dazzle = function(hearts_count)
   reset_actions()

   if dazzle_check() then
    obj.current_action = {
     name = 'move',
     start = function()
     end,
     middle = function()
     end
    }
    deferred_action = function()
     obj.current_action = {
      name = 'move',
      start = function()
      end,
      middle = function()
       lower_stat('patience')
       queue_text(function()
        color(14)
        print("we've grown too close")
        print("his eyes no longer twinkle")
       end)
      end
     }
    end
    attempt_counterattack()
   else
    obj.current_action = {
     name = 'magic',
     start = function()
      queue_text(function()
       color(14)
       print("behold the power...")
      end)
     end,
     middle = function()
      raise_stat('attraction')
      queue_text(function()
       color(14)
       print("of my loveliness!")
      end)
     end
    }
    attempt_counterattack()
   end
  end,
  advance = function()
   reset_actions()

   if advance_check() then
    raise_stat('closeness')
    lower_stat('patience')

    obj.current_action = {
     name="move",
     start=function()
     end,
     middle=function()
     end
    }
   elseif attack_check() then
    obj.current_action = {
     name = 'attack',
     start = function()
      queue_text(function()
       color(14)
       print "*whistles*"
      end)
     end,
     middle = function()
      queue_text(function()
       color(14)
       print "mwa! :*"
      end)
      raise_stat('patience')
      lower_stat('attraction')
      obj.hp-=1+inventory.lipstick_strength()
      if obj.hp <= 0 then --TODO: if all 4 final items, he recovers
       obj.current_action.win = true
       deferred_action = win
      end
     end
    }
   else
    obj.current_action = {
     name = 'attack_fail',
     start = function()
      queue_text(function()
       color(14)
       print "*whistle*"
      end)
     end,
     middle = function()
      lower_stat('attraction')
      queue_text(function()
       color(14)
       print "hm, he's hesitating"
      end)
     end
    }
    attempt_counterattack()
   end
  end,
  intro_speech = intro_speech
 }
 return obj
end
-- end ext

---------------------------------------------------------------
------------ end external code
---------------------------------------------------------------


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
__gfx__
0aaeaa0000aaeaa00aaeaa0000000000000444000044400000044400000000000000000000000000088188100000000000000000008880000000000000000000
0a0acf000a00acf00a0acf0000000000000fc50000fc5000000fc50f000000000000000000000000888888810008888000000080888888000080080000000000
0000f80000000f8f00f0f800000000000f6e466ff6e46600006e466f000000000000000000000000888888810088880800088808088888880888888000888800
000f3bb0000f3bb0000f3bb0000000000f56655ff56655f00f56655f000000000000000000000000888888810888008000880080800088888888888808880080
00f0ff0f00f0ff000000ff0f0000000000066500006650f00f066500000000000000000000000000088888100800888000800880880008880800008008008880
0003bb000003bbf00003bb0000000000000ccc1004ccc10000ccccf0000000000000000000000000008881008088880000808800888000888880088800888800
000f0f00000f004000004f0000000000000f0f0005f0ccf000f10440000000000000000000000000000810000888800008088000088888080888888000000000
00040400000400000000040000000000004545000000045004400000000000000000000000000000000000000000000000800000000888800088880000000000
44443b3b45443443454344443335f3434b35f33bbb35fbb45438c5539f949f949f949f9400200020433453549f949f949777777949999994333bbb3333bbbbb3
4cb33f3b3f355f3b3f3b3844353f4b33433f4f3b3f3f4333437c87359f949f949dddddd412221222455435349f949f9497777779967777693bbb33b33bbb33b3
44b3f443f443f443f4433b3435bf433434bff443f44f432b57b8cb739f949f949dc7c7d4122e02ee343533449f949f949767767997677679bb3338333b33333b
c335f445444544f544453b344b354b538335f44544454344397bb7939f949f949d7c7cd402200e003eee3eee9f949f949eee9eee97777779b83333333b333933
b3c5f445f4454445f445f33b34b5f4534b35f445f4454b34594774959f949f949dc7c7d40ee02002200020009f949f942000200097777779b3383333b3933333
34bf4443f443f44bf44f4343543f43b343bff443f44f4335354994359f949f949d7c7cd420022212221222219f949f9422122221977777793333383533339335
333f4f43ff4bf443fb4f43b333bf433545b3f44bff43b444334994539f949f949dddddd42e122212221222e149454945221222e1966776693383333535333353
3b3543bb535434353b3f43b343b54b334445b34334344454445993359f949f949f949f94e00ee00eee0eee0033533533ee0eee00977777793533535335335353
3535534454544532455353545655565500000000f555550499999999222222221111111133333333777777767777777677777776121112110000000044553554
543315453455345354353444656565650f000f00f64455049aaaaaa92eeeeee21cc77cc13b2bbb237775777677757776777577762121212100000000435ff534
54435343535353445443535456505650f440f440f44445049aaaaaa9288eeee21c7777c13b2bbb2377555776775577767775577612101210000000003335f453
44354544553545533453544505000500444444f4f44445049aa8a8892888aee21aa77aa132e2b2e375555576755555767555557601000100000000005333f435
35344445432343353535344456555655f4444444f44445049aaa88892e899ae21acccca13eee2ee377757776775577767775577612111211000000005353f453
d33453545355453d34453d3565656565f440f440f64440049a8888092e9999a21aaccaa13bbbbbb377757776777577767775777621212121000000003533f433
45455344455445435544534456505650ff40f440f440000598888a092ee999921caaaac13bbbbbb37777777677777776777777761210121000000000433bf455
54445445354534454545335405000500000000002220222099999999222222221111111133333333666666666666666666666666010001000000000043bff445
000000000000000000000000cc9ccc9c0000000011111111ccccccccaaaaaaaa66656665aa565565001221222212212222aafaaaaaaaaaaaaaaaaa7a00000000
0000000000000000000000009cca99cc4444444411111c11ccccccccaaaaaafa66655555a6655666001221222212212222aaaaaaaaaaaaaaaaaaa66600000000
000000000000000000000000c9aaaac9444444441c111111ccccccccaafaaaaa66656665a5566657001221222212212222122aafaaaaaaaaaaaa665700000000
400000000000000000000000c9aa7aac44444444111aa11cccccccccaaaaaaaa55556665a6665565000001222212212222122aaaaaaaafaaaaa6556500000000
0fb0f0ae0000000000000000caa7aa9c44444444aaaaaaaaccccccccaaaafaaa66656665a5555766000001222212212222122faaaaaaaaaaaa65576600000000
00bbbfca00000000000000009caaaa9c44444444afaaaaaaccccccccaaaaaaaa66655555aa566656000000002212212222122122aafaaaaaaa65665600000000
4f3b38fa0000000000000000cc99acc944444444aaaaafaaccccccccafaaaaaa66656665a6665555000000002212212222122122aaaaaaaaa656555500000000
000000000000000000000000c9ccc9cc00000000aaaaaaaaccccccccaaaaaaaf55556665a5557666afaaaafa2212212222122122aaaaaaaaa565766600000000
00077770060067700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06777600007777000777760700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67607770677077707677777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77677677777777677776077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777070077077767777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60767700667006706776677700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000770006677000677776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee2888888888222772228888888882ee700000007777777700000007700000000000000000000007000000000000000000000000000000000000000000000000
eeeee8888222277777722228888eeeee700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
8eeeeee827777700007777728eeeeee8700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
2eeeeee277000000000000772eeeeee2700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
2eee882770000000000000077288eee2700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
22ee877700000000000000007778ee22700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
22ee270000000000000000000072ee22700000000000000000000007700000000000000000000007000000000000000000000000000000000000000000000000
22287700000000000000000000778222700000000000000000000007777777777777777777777777000000000000000000000000000000000000000000000000
22877000000000000000000000077822000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28770000000000000000000000007782000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28700000000000000000000000000782000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28700000000000000000000000000782000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88700000000000000000000000000788000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87700000000000000000000000000778000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87000000000000000000000000000078000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000000000000000000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
000000000000000000000000000000000303030303030303030303030c040404010101010009030303030000000100030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011111111111111111111111111111236363636363636363636363636363636363636363636363636363636363636360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131a1a1a1a1a1a1a1f1e201a1a1a201336363636363636363636363636363636363636363636363636363636363636360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13191919191919192f2f21191919211335353535353535353535353535353535353535353535353535353636363636360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13181818291818181e1f20181818201337373e37373737373737373737373737373737373737373737373636363636360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131b1b1b251b1b1b2f2f2118281821133d3d393d3d3d3d3d3d3d3d3d3d3d3d3d373737373d3d373737373535353535350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132122212d2221222222201b251b221337373937373737373737373737373737373737373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1321202023162323231622202d22201637373950515555555555555555555555555253373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132221232323232d232323232323232d3c3739603f3f3f3f3f3f3f3f3f3f3f3f3f3f63373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13202223221623232316222d2216232d3b3739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1321212d212220222022201d212022163a3739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1322201d202122221a1a1a1c1a1a1a13373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131a1a1c1a1a1e1f1919191919191913373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1319191919192f2f1818181718181813373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1318172717181f1e1718172617181713373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131b1b1b1b1b2f2f1b1b1b1b1b1b1b13373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1411111111111111111111111111111537373957585858585858585858585858585859373737373737373737373737370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002837428305283442832029334293052b3242b3102b3242b3052933429310283442830526344263202434424305243442432026354263052836428305283642834028365263442633426330263251a304
011000002836428305283442832029344293052b3242b3102b3242b3052933429320283442830526344263202434424305243442432026354263052835428305263642634026325243742436424330243251a304
01100000283742830528324283302a3442a305263242633028344283052a3242b3342a3242a305263242633028344283052a3242b3342a3242a3052632426330283442830526354263051f3541f3401f3250d305
0110000018214182101821018210182101821018210182151d2141d2101d2101d2101d2101d2101d2101d21518214182101821018210182101821018210182151721417210172152a2051821418210182152a205
011000001724417240172401724023240172402324017245172441724017240172401724017240172401724517244172401724017240172401724017240172451724417240172401724017240172401724500200
0110001025734257452372021722217122c7151f7321f7122c71521722217122c715217422c71521722187402b7032b7032b7032b7032b7032b7032b7032b7032b7032b7032b7032b7032b7032b7032b70324705
0110000830644306241860518614306440c4040062000615104041040410404104040e40410404104040e4042b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b603
0110000809646133043962621646094153962623302300012b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b6032b603
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 01470644
00 02070644
00 03080644
02 02074644
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

