pico-8 cartridge // http://www.pico-8.com
version 8
__lua__

local inventory

-- start ext ./utils.p8
noop_f = function()
end

id_f = function(val)
 return val
end

--all4tehtokens
function bubble_sort(t, field, default)
 if #t > 1 then
  local do_pass = function()
   local swp
   for i=1,(#t-1) do
    if (t[i][field] or default) > (t[i+1][field] or default) then
     swp = t[i+1]
     t[i+1] = t[i]
     t[i] = swp
    end
   end
   return swp
  end
  while do_pass() do
  end
 end
end

make_pool = function()
 local store = {}
 local id_counter = 0
 local each = function(f,wrap_around)
  local all_items = all(store)
  if wrap_around then
   wrap_around()
  end
  for v in all_items do
   if v.alive then
    f(v)
   end
  end
 end
 return {
  each = each,
  each_in_order = function(key, default, f)
   bubble_sort(store,key,default)
   each(f)
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
   return obj
  end
 }
end


cam = {
 x = 0,
 y = 0,
 alive = true,
 apply = function()
  camera(cam.x,cam.y)
 end
}

promises = {
 make = function(on_success)
  local queued_promises = {}
  local resolved = false
  local value = nil

  -- https://promisesaplus.com/#point-45
  local promise_resolution = function(promise,x)
   if type(x) == 'table' and type(x.next) == 'function' then
    x.next(function(v)
     promise.resolve(v)
    end)
   else
    promise.resolve(x)
   end
  end

  local obj
  obj = {
   on_success = on_success or id_f,
   resolve=function(v)
    if not resolved then
     resolved = true
     value = obj.on_success(v)
     foreach(queued_promises,function(p)
      promise_resolution(p,value)
     end)
    end
   end,
   next=function(on_s)
    local new_promise = promises.make(on_s)
    if resolved then
     promise_resolution(new_promise,value)
    else
     add(queued_promises,new_promise)
    end
    return new_promise
   end
  }
  return obj
 end,
 all = function(promise_table)
  local remaining = #promise_table
  local promise = promises.make()
  for p in all(promise_table) do
   p.next(function()
    remaining-=1
    if remaining == 0 then
     promise.resolve()
    end
   end)
  end
  return promise
 end
}

local delays
delays = {
 pool=make_pool(),
 process=function(wrap_around)
  delays.pool.each(function(o)
   o.process()
  end,wrap_around)
 end,
 make=function(count,promise_f,promise_val)
  local promise = promises.make(promise_f)
  local obj = delays.pool.make()
  obj.process = function()
   if count <= 0 then
    del(delays.pool,process)
    promise.resolve(promise_val)
    obj.kill()
   else
    count-=1
   end
  end
  return promise
 end
}

-- end ext

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
    local frame_index = ((x+y)/s.walking_scale) % #s.walking_frames
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
  merge = function(ease_in,ease_out)
   return function(k)
    return 1 - ease_out(1-ease_in(k))
   end
  end
 },
 pool = make_pool(),
 make = function(sprite,property,final,time,easing,options)
  local initial = sprite[property]
  local diff = final - initial
  local count = 0
  if not easing then
   easing = id_f
  elseif type(easing) == 'string' then
   easing = tweens.easings[easing]
  end
  local tween = options or {}
  tween.promise = promises.make()
  tween.next = tween.promise.next
  local finished=false
  tween.advance = function()
   if not sprite.alive then
    tween.kill()
   end
   if finished or not tween.alive then
    return
   end

   local time_factor
   count+= 1
   if time < 2 or count >= time then
    finished=true
    time_factor = 1
    -- delay is added so a 0 duration tween won't immediately resolve
    -- an infinitely looping 0 duration tween can't be terminated without this
    delays.make(0,function()
     -- alive is checked last so it gets a chance to be terminated
     if tween.alive then
      tween.kill()
      if tween.on_complete then
       tween.next(tween.on_complete)
      end
      tween.promise.resolve(sprite)
     end
    end)
   else
    time_factor = count/time
   end

   local out
   if tween.ease_in_and_out then
    out = initial + diff*(1-(easing(1-easing(time_factor))))
   elseif tween.ease_out then
    out = initial + diff*(1-(easing(1-time_factor)))
   else
    out = initial + diff*easing(time_factor)
   end
   if tween.rounding then
    out = flr(out+0.5)
   end
   sprite[property] = out
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
function make_inventory(is_for_enemy)
 local owned_hearts = {}
 local obj
 local choose = function(map,min_index)
  return function()
   if min_index < obj.current_store_index then
    return map[4]
   else
    return map[1]
   end
  end
 end
 obj = {
  store_sprite_map = {41,39,40,38},
  hearts_count = 0,
  current_store_index = 1
 }

 obj.current_store = function()
  -- lipstick, ring, shoes, dress
  return ({2,3,4,1})[obj.current_store_index]
 end

 obj.increment_store = function()
  obj.current_store_index+=1
 end

 obj.add_heart = function()
  local heart
  if is_for_enemy then
   heart = sprites.make(10,{x=123-9*obj.hearts_count,y=-12,z=200})
   heart.before_draw = function()
    pal(8,5)
    --pal(1,5)
   end
  else
   heart = sprites.make(10,{x=5+9*obj.hearts_count,y=-12,z=200})
  end
  heart.relative_to_cam=true
  heart.centered=true
  tweens.make(heart,'y',5,30,'quadratic',{ease_out=true})
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

 obj.clear_hearts = function()
  for h in all(owned_hearts) do
   h.kill()
  end
  owned_hearts = {}
  obj.hearts_count = 0
 end

 obj.remap_girl_colors = function()
  if obj.current_store_index > 1 then --lipstick
   pal(8,2)
  end
  if obj.current_store_index > 2 then --ring
   pal(14,8)
  end
  if obj.current_store_index > 3 then --shoes
   pal(4,8)
  end
  if obj.current_store_index > 4 then --dress
   pal(11,13)
   pal(3,1)
  end
 end

 obj.remap_kiss = function()
  if obj.current_store_index > 1 then
   pal(8,2)
  end
 end

 obj.remap_hearts = function()
  if obj.current_store_index < 3 then
   pal(8,14)
  end
 end

 return obj
end
-- end ext

-- start ext fight.lua
function make_fight()
 local obj, fanim, first_draw, kiss --misc fight state
 local ofpx, ofpy, cfpx --player state
 local fighter, enemy --sprites
 local enemy_data
 local text_needs_clearing
 local intro_slide
 local intro_textbox, intro_store
 local game_over
 local clouds = make_pool()
 local sun
 local just_jumped = false --fancy bounce animation
 local sliding_store = false
 local night=false
 local dusk=false
 local store_id

 local function calc_fighter_x()
  return flr(enemy_data.closeness*(enemy_data.base_x-ofpx-16)+ofpx+0.5)
 end

 local function reset_combat_cursor()
  cursor(cam.x+2,73)
 end

 local function clear_text()
  palt(0,false)
  map(19,9,cam.x,72,16,7)
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

 local function kill_clouds()
  clouds.each(function(c)
   c.kill()
  end)
 end

 local function exit_battle()
  kill_clouds()
  if sun then
   sun.kill()
  end
  fighter.kill()
  inventory.clear_hearts()
  enemy_data.kill()
  cam.x = 0
  cam.y = 0
  sprites.make(player.sprite_id,player).flip = true
  obj.active = false
 end

 local function jump_to(sprite,to_x,jump_sprites,skip_jump_anticipation,airtime)
  airtime = airtime or 10
  sprite.scale_x=sprite.scale
  sprite.scale_y=sprite.scale
  sprite.anchor_y=1
  sprite.y+=sprite.scale*4

  local jump = function()
   sfx(9)
   sprite.anchor_y=0
   sprite.y-=sprite.scale*8
   tweens.make(sprite,'x',to_x,airtime)
   tweens.make(sprite,'scale_x',sprite.scale*.875,airtime/10*3).next(function()
    return tweens.make(sprite,'scale_x',sprite.scale,airtime/10*3)
   end)

   local smooshing = tweens.make(sprite,'scale_y',sprite.scale*1.25,airtime/10*3).next(function()
    return tweens.make(sprite,'scale_y',sprite.scale*.875,airtime/10*3,'cubic',{
     ease_out=true
    })
   end).next(function()
    return tweens.make(sprite,'scale_y',sprite.scale,airtime/10*4,'cubic')
   end)

   local jumping = tweens.make(sprite,'y',sprite.y-airtime,airtime/10*5,'quadratic',{
    ease_out=true
   }).next(function()
    sprite.sprite_id = jump_sprites[2]
    return tweens.make(sprite,'y',ofpy-sprite.scale*4,airtime/10*5,'quadratic')
   end).next(function()
    sprite.anchor_y=1
    sprite.y+=sprite.scale*8
    tweens.make(sprite,'scale_x',sprite.scale*1.25,2,'quadratic',{ease_out=true})
    return tweens.make(sprite,'scale_y',sprite.scale*.7,2,'quadratic',{ease_out=true})
   end).next(function()
    sprite.sprite_id = jump_sprites[3]
    tweens.make(sprite,'scale_x',sprite.scale,4,'quadratic')
    return tweens.make(sprite,'scale_y',sprite.scale,4,'quadratic')
   end)

   return promises.all({jumping,smooshing}).next(function()
    sprite.scale_x = nil
    sprite.scale_y = nil
    sprite.anchor_y= nil
    sprite.y-=sprite.scale*4
   end)
  end

  local anticipation_tween
  if skip_jump_anticipation then
   sprite.sprite_id = jump_sprites[1]
   return jump()
  else
   tweens.make(sprite,'scale_x',sprite.scale*1.5,4)
   return tweens.make(sprite,'scale_y',sprite.scale*.75,4).next(function()
    sprite.sprite_id = jump_sprites[1]
    tweens.make(sprite,'scale_x',sprite.scale,2)
    return tweens.make(sprite,'scale_y',sprite.scale,2)
   end).next(jump)
  end
 end

 local function enemy_jump_to(x)
  local jump_sprites
  if x > enemy.x then
   jump_sprites = {6,5,4}
  else
   jump_sprites = {5,6,4}
  end

  return jump_to(enemy,x,jump_sprites,true)
 end

 local function jump_to_closeness(skip_jump_anticipation)
  cfpx = calc_fighter_x()

  local jump_sprites
  if cfpx >= fighter.x then
   jump_sprites = {1,2,0}
  else
   jump_sprites = {2,1,0}
  end

  just_jumped = true

  return jump_to(fighter,cfpx,jump_sprites,skip_jump_anticipation)
 end

 local function fenemy_attack()
  enemy_data.current_action.start()
  enemy.walking=true

  fanim = noop_f

  local duration = (enemy.x-fighter.x+12)/4
  sfx(12,0)
  tweens.make(enemy,'x',fighter.x+12,duration,'quadratic').on_complete = function()
   enemy.sprite_id = 6
   enemy.walking=false
   sfx(-1,0)
   sfx(15)

   enemy_data.current_action.middle()

   if enemy_data.current_action.lose then
    enemy.sprite_id = 4
    fighter.sprite_id = 2
    local falling = tweens.make(fighter,'x',fighter.x-8,40,'quadratic')
    falling.ease_out = true
    falling.on_complete = function()
     fanim = false
    end
   else
    local jump = jump_to_closeness(true)
    local enemy_jump = enemy_jump_to(enemy_data.base_x)

    promises.all({jump,enemy_jump}).next(function()
     fanim = false
    end)
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

 local function fintro()
  reset_doors()
  fanim=noop_f
  tweens.make(fighter,'x',cfpx,35,'quadratic',{ease_out=true}).next(function()
   sfx(-1,0)
  end)
  tweens.make(fighter,'y',ofpy,40,'quadratic')
  tweens.make(fighter,'scale',4,40,'quadratic').next(function()
   fighter.walking = false
   fighter.walking_scale=8
   enemy.hide = false
   enemy.walking=true
   sfx(12)
   delays.make(35).next(function()
    sfx(-1,0)
   end)
   return tweens.make(enemy,'x',enemy_data.base_x,40,'quadratic',{ease_out=true})
  end).next(function()
   intro_slide = false
   enemy.walking=false
   fanim=false

   queue_text(function()
    reset_combat_cursor()
    if store_id <= 4 then
     color(12)
     print "welcome, see how this suits you"
    else
     color(14)
     print "he's absolutely stunning. it's"
     print "all been building up to this"
    end
   end)
  end)
 end

 function beach_intro()
  for i=1,4 do make_cloud() end

  sun = sprites.make(51,{x=85,y=5,z=1,relative_to_cam=true,centered=true,rounded_position=true})

  fanim=noop_f
  sfx(12,0)
  tweens.make(intro_textbox,'y',48,60,'quadratic').ease_in_and_out=true

  tweens.make(cam,'x',24,20).rounding=true
  tweens.make(fighter,'x',128+4,5).next(function()
   tweens.make(fighter,'y',fighter.y+8,10)
   return tweens.make(fighter,'x',128+13,15)
  end).next(function()
   return tweens.make(fighter,'y',coastline_y,50)
  end).next(function()
   tweens.make(cam,'x',128+24,60).rounding=true
   return tweens.make(fighter,'x',ofpx-24,20)
  end).next(function()
   fighter.walking_scale=8
   return fintro()
  end)
 end

 function store_intro()
  fanim=noop_f
  sliding_store = true

  local text_slide = tweens.make(intro_textbox,'y',48,30,'quadratic')
  text_slide.ease_in_and_out=true

  local store_slide = tweens.make(intro_store,'y',0,30,'quadratic')
  store_slide.ease_in_and_out=true

  store_slide.next(function()
   sliding_store = false
   sfx(12)
   return fintro()
  end)
 end

 local function flose()
  fanim = noop_f

  fighter.sprite_id = 48

  enemy_data.current_action.start()
  enemy.flip = true
  enemy.walking=true
  tweens.make(enemy,'x',cam.x+128+16,30,'cubic').on_complete = function()
   enemy_data.current_action.middle()
   game_over = true
   fighter.before_draw = function()
    pal(7,0)
    pal(11,0)
    pal(10,0)
    pal(4,0)
    pal(12,0)
    pal(15,0)
    pal(14,0)
    pal(3,0)
    pal(8,0)
   end
  end
 end

 local function victory(tween)
  tween.next(function(heart)
   enemy.sprite_id = 5
   heart.kill()
   enemy.z = 50
   fighter.sprite_id = 2
   return tweens.make(enemy,'y',ofpy,20)
  end).next(function()
   fighter.sprite_id = 0
   enemy.flip=true
   enemy.sprite_id = 4
   enemy.walking=true
   fighter.walking=true
   inventory.clear_hearts()
   sfx(12,0)
   music(0,0,8)
   return promises.all({
    tweens.make(fighter,'x',cam.x+128+16,30),
    tweens.make(enemy,'x',cam.x+128+16+(enemy.x-fighter.x),30)
   })
  end).next(function()
   sfx(-1,0)
   tweens.make(sun,'y',24,80,'quadratic')
   return delays.make(40)
  end).next(function()
   dusk=true
   return delays.make(20)
  end).next(function()
   dusk = false
   night = true
   kill_clouds()

   local moon = sprites.make(75,{x=40,y=-8,z=1,relative_to_cam=true,centered=true,rounded_position=true})
   return tweens.make(moon,'y',24,120)
  end).next(function(moon)
   moon.kill()
   sun.y=-8
   delays.make(20).next(function()
    night=false
    dusk=true
    for i=1,2 do make_cloud() end
    return delays.make(20)
   end).next(function()
    dusk=false
   end)
   return tweens.make(sun,'y',5,120,'quadratic',{ease_out=true})
  end).next(function()
   local loop_bubble
   loop_bubble = function(sprite,y_offset)
    y_offset = y_offset or 0
    local heart = sprites.make(10,{x=sprite.x,y=sprite.y+y_offset,z=110,centered=true})
    promises.all({
     tweens.make(heart,'y',heart.y-15,15),
     tweens.make(heart,'scale',sprite.scale/2,10,'quadratic')
    }).next(heart.kill)
    delays.make(rnd()*10+5).next(function()
     loop_bubble(sprite,y_offset)
    end)
   end
   loop_bubble(fighter,-8)
   loop_bubble(enemy,-8)

   fighter.x=cam.x+128+16
   fighter.flip=true
   enemy.x=fighter.x+20
   enemy.flip=false
   local kids = {}
   local kid
   local dur=200
   local full_end_offset = cam.x+16
   local stop_walking = function(sprit)
    sprit.walking=false
   end
   local stop_and_turn = function(spp)
    spp.flip= not spp.flip
    stop_walking(spp)
   end
   local trots = {
    tweens.make(fighter,'x',full_end_offset,dur).next(stop_and_turn),
    tweens.make(enemy,'x',full_end_offset+20,dur).next(stop_walking)
   }
   local trots = {}
   local scale_multiplier = 1
   local offset = 10
   for i=1,4 do
    scale_multiplier*= rnd()
    offset+=6*(2+scale_multiplier)
    kid=sprites.make(0,{x=enemy.x+offset,y=enemy.y+16,z=45})
    if rnd()<0.5 then
     kid.walking_frames=fighter.walking_frames
     kid.flip=true

     add(trots,tweens.make(kid,'x',full_end_offset+20+offset,dur).next(function(k)
      stop_walking(k)
      local jloop
      jloop = function()
       local jump_sprites
       local x = mid(k.x+rnd()*30-15,cam.x+60,cam.x+120)
       if x > k.x then
        jump_sprites = {2,1,0}
        k.flip=false
       else
        jump_sprites = {1,2,0}
        k.flip=true
       end

       return jump_to(k,x,jump_sprites,true,5+rnd()*5).next(jloop)
      end
      jloop()
     end))
    else
     kid.sprite_id = 4
     kid.walking_frames=enemy.walking_frames
     kid.anchor_x=0.625

     add(trots,tweens.make(kid,'x',full_end_offset+20+offset,dur).next(function(k)
      stop_walking(k)
      local jloop
      jloop = function()
       local jump_sprites
       local x = mid(k.x+rnd()*30-15,cam.x+60,cam.x+120)
       if x > k.x then
        jump_sprites = {6,5,4}
        k.flip=true
       else
        jump_sprites = {5,6,4}
        k.flip=false
       end

       return jump_to(k,x,jump_sprites,true,5+rnd()*5).next(jloop)
      end
      jloop()
     end))
    end
    kid.walking=true
    kid.scale=2+scale_multiplier
    kid.anchor_y=1
    kid.centered=true
    kid.walking_scale=2
    loop_bubble(kid,-6*kid.scale)
   end
   return promises.all(trots)
  end).next(function()
   color(8)
   print "as you smile at your family"
   print "your heart overflows with joy"
   color(11)
   print "congratulations!"
   print "ctrl+r to live it again"
  end)
 end

 local function fwin()
  local winwait=60
  local win_sprite_id = ({39,40,38,41,10})[store_id]
  local win_heart = sprites.make(win_sprite_id,{x=fighter.x+16,y=enemy.y+8,scale=8,centered=true,z=40})
  if store_id < 5 then
   win_heart.before_draw = function()
    palt(0,false)
   end
  end

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
  local trophy_spin = tweens.make(enemy,'y',enemy.y-4,50,'quadratic').next(function()
   sfx(11)
   fanim = noop_f
   fighter.sprite_id = 0
   if store_id < 5 then
    enemy.kill()
   end
   kiss=false
   tweens.make(win_heart,'x',fighter.x-32,12,'circular',{ease_out=true}).next(function()
    win_heart.z = 120
    tweens.make(win_heart,'x',fighter.x,12,'circular')
   end)
   tweens.make(win_heart,'y',fighter.y+18,12,'circular',{ease_out=true}).next(function()
    tweens.make(win_heart,'y',fighter.y,12,'circular')
   end)
   return tweens.make(win_heart,'scale',1,24,'quadratic')
  end)
  if store_id < 5 then
   trophy_spin.next(function()
    win_heart.kill()
    fighter.sprite_id = 2
    inventory.increment_store()
    return tweens.make(fighter,'y',fighter.y-5,20,'quadratic',{ease_out = true})
   end).next(function()
    return delays.make(10)
   end).next(exit_battle)
  else
   victory(trophy_spin)
  end
 end

 local function fmove()
  enemy_data.current_action.start()

  fanim = noop_f

  jump_to_closeness(just_jumped).next(function()
   enemy_data.current_action.middle()
   fanim = false
  end)
 end

 local function fattack()
  enemy_data.current_action.start()

  fanim = noop_f

  fighter.walking = true

  approach_easing = tweens.easings.merge(tweens.easings.quadratic,tweens.easings.cubic)
  local approach = tweens.make(fighter,'x',enemy.x-12,20,approach_easing)
  approach.next(function()
   fighter.walking=false
   kiss=flr(rnd()*5+11)
   sfx(13)
   return delays.make(20)
  end).next(function()
   enemy_data.current_action.middle()

   enemy.x+=8
   enemy.sprite_id=6

   if enemy_data.current_action.win then
    fanim = false
   else
    local recede = tweens.make(fighter,'x',cfpx,12,'quadratic')
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
  end)
 end

 local function fmagic()
  local spinx = fighter.x
  local already_full = enemy_data.attraction >= 1

  fanim = noop_f

  local projectile_count = enemy_data.projectile_count

  jump_to_closeness().next(function()
   enemy_data.current_action.start()
   fighter.sprite_id=2
   local counter=0

   fighter.scale_x = 4
   fighter.anchor_x = 0.68
   local spinning = {delay=5,alive=true,tween=nil}
   sfx(14)
   local fighter_promise = tweens.make(spinning,'delay',1,10+5*projectile_count,'quadratic',{
    ease_out=true,
    rounding=true
   }).next(function()
    spinning.tween.kill()
    fighter.flip = false
    fighter.scale_x = nil
    fighter.anchor_x = nil
    enemy_data.current_action.middle()
   end).next(function()
    return tweens.make(fighter,'scale',4,10)
   end).next(function()
    fighter.sprite_id = 0
   end)

   do_spin = function()
    spinning.tween = tweens.make(fighter,'scale_x',1,spinning.delay,'circular')
    spinning.tween.on_complete = function()
     fighter.flip = not fighter.flip
     spinning.tween = tweens.make(fighter,'scale_x',4,spinning.delay,'circular')
     spinning.tween.ease_out = true
     spinning.tween.on_complete = function()
      do_spin()
     end
    end
   end
   do_spin()

   local last_heart_promise
   local push_offset = 4
   if already_full then
    push_offset = 0
   end

   for i=1,projectile_count,1 do
    last_heart_promise = delays.make(i*5+5).next(function()
     local h = sprites.make(10,{x=fighter.x+9+10*rnd(),y=fighter.y-10+20*rnd(),z=100+i})
     h.before_draw = function()
      inventory.remap_hearts()
     end
     h.centered = true
     return tweens.make(h,'x',enemy_data.base_x+push_offset*i,20,'cubic')
    end)
    if not already_full then
     last_heart_promise = last_heart_promise.next(function(h)
      sfx(15)
      enemy.x+=4
      enemy.sprite_id = 6
      h.z-= 60
      tweens.make(h,'x',enemy.x+20,5)
      return tweens.make(h,'scale',4,5)
     end)
    end
    last_heart_promise = last_heart_promise.next(function(h)
     h.kill()
    end)
   end

   if not already_full then
    last_heart_promise = last_heart_promise.next(function()
     return delays.make(5)
    end).next(function()
     enemy.walking=true
     enemy.walking_scale=8
     enemy.sprite_id=4
     return tweens.make(enemy,'x',enemy_data.base_x,8)
    end).next(function()
     enemy.walking=false
     enemy.x = enemy_data.base_x
    end)
   end

   promises.all({fighter_promise,last_heart_promise}).next(function()
    fanim=false
   end)
  end)
 end

 local function frun()
  enemy_data.current_action.start()
  fighter.walking = true
  fanim = noop_f
  enemy.walking=true
  tweens.make(enemy,'x',enemy.x-10,6,'quadratic',{
   ease_in_and_out=true
  }).next(function()
   enemy.walking=false
   enemy_data.current_action.middle()
   fighter.flip = true
   fighter.walking=true
   if sun then
    fighter.walking_scale=4
    tweens.make(fighter,'y',fighter.y-24,40)
    tweens.make(fighter,'scale',1,40,'quadratic').ease_out = true
   end
   sfx(12)
   return tweens.make(fighter,'x',-16,40,'quadratic')
  end).next(function()
   return delays.make(30)
  end).next(function()
   fighter.walking=false
   sfx(-1,0)
   exit_battle()
  end)
 end

 local function press_key(sprite_id,left_x,top_y)
  local key = sprites.make(sprite_id,{x=left_x+4,y=top_y+4})
  key.centered = true
  key.relative_to_cam = true
  tweens.make(key,'scale',2,5).on_complete = key.kill
  queue_text(clear_text)
 end

 local function detect_keys()
  if store_id >= 3 and btn(0) and not btn(1) and not btn(2) then
   press_key(43,25,61)
   enemy_data.withdraw()
   return true
  end
  if btn(1) and not btn(0) and not btn(2) then
   press_key(44,67,61)
   enemy_data.advance()
   return true
  end
  just_jumped=false
  if store_id >= 2 and btn(2) and not btn(0) and not btn(1) then
   press_key(42,46,53)
   enemy_data.dazzle()
   return true
  end

  return false
 end

 local function update_fight()
  if not obj.active then
   return false
  end

  if sun and rnd() < 0.005 then
   make_cloud(128+32)
  end

  if sun and rnd() < 0.01 then
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
   elseif enemy_data.current_action.name == 'counterattack' then
    fenemy_attack()
   elseif enemy_data.current_action.name == 'lose' then
    flose()
   elseif enemy_data.current_action.name == 'win' then
    fwin()
   elseif enemy_data.current_action.name == 'move' then
    fmove()
   end
  end

  return true
 end

 local function draw_fui()
  if not fanim then
   color(7)
   if store_id >= 3 then
    spr(43,cam.x+25,cam.y+61)
    print("withdraw",cam.x+34,cam.y+63)
   end
   if store_id >= 2 then
    spr(42,cam.x+46,cam.y+53)
    print("dazzle",cam.x+55,cam.y+55)
   end
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

 local function draw_fight()
  if obj.active then
   draw_text()
   if game_over then
    rectfill(cam.x,0,cam.x+127,48,8)
    map(19,6,cam.x,intro_textbox.y,16,10) --transparent textbox
    sprites.draw(20,nil)
   elseif intro_slide then
    --clear above text

    map(16+3,0,cam.x,0,16,2) --sky
    if not sliding_store then
     sprites.draw(nil,19) --background sprites (ie, sun, clouds, etc)
    end
    palt(0,false)
    map(0,6,0,48,19,10) --bottom half of town
    --transition+beach

    map(16,2,128,16,32,4) --beach
    map(0,0,0,0,16,8) --top half of town

    palt()
    if sliding_store then
     sprites.draw()
    end
    palt(0,false)

    map(19,6,cam.x,intro_textbox.y,16,10) --textbox
    if intro_store then
     map(35,6*store_id-6,cam.x,intro_store.y,16,6) --sliding down store
    end
    palt()

    if not sliding_store then
     sprites.draw(20,nil) --foreground sprites
    end
   else
    local pal_night = function()
     if dusk then
      pal(12,1)
     elseif night then
      pal(10,15)
      pal(15,4)
      pal(12,0)
     end
    end
    pal_night()
    map(16+3,0,cam.x,0,16,2) --sky
    pal()
    sprites.draw(nil,10) --clouds,sun
    palt(0,false)
    pal_night()
    map(19,2,cam.x,16,16,7) --beach
    if intro_store then
     map(35,6*store_id-6,cam.x,intro_store.y,16,6) --store
    end
    pal()
    palt()
    draw_fui()
    map(19,6,cam.x,intro_textbox.y,16,10) --transparent textbox
    --draw_enemy_stats()
    sprites.draw(11,nil)
    draw_kiss()
   end
   return true
  else
   return false
  end
 end

 local function start_common()
  store_id=inventory.current_store_index
  cfpx=calc_fighter_x()

  player.kill()

  fighter.before_draw = function()
   inventory.remap_girl_colors()
  end
  fighter.centered = true
  fighter.walking_frames = {0,1,0,2}
  fighter.walking = true

  obj.active = true
  intro_slide = true
  intro_textbox = {
   alive=true,
   y=128
  }
 end

 --object initialization and return
 obj = {
  update = update_fight,
  draw = draw_fight,
  start = function()
   ofpx=128+24+26
   ofpy=26
   coastline_y=ofpy-8

   enemy_data = make_enemy(fighter,{
    x=256+128,
    y=ofpy,
    z=50,
    hide=true,
    scale=4,
    walking_scale=8
   })
   enemy = enemy_data.sprite
   enemy_data.base_x = 128+24+96

   fighter = sprites.make(0,{
    x=player.x+4,
    y=player.y+4,
    z=100,
    walking_scale=2
   }) -- +4 because centered

   player.x-=4
   start_common()

   beach_intro()
  end,
  start_store = function(store_index)
   obj.active = true
   ofpx=26
   ofpy=26

   intro_store = {
    alive=true,
    y=-48
   }
   enemy_data = make_enemy(fighter,{
    x=128+16,
    y=ofpy,
    z=50,
    hide=true,
    scale=4,
    walking_scale=8
   })
   enemy = enemy_data.sprite
   enemy_data.base_x = 96

   fighter = sprites.make(0,{
    x=-16,
    z=100,
    y=ofpy,
    walking_scale=8,
    scale=4
   })
   player.y=mid(player.y-8,player.y+8,64) --move away from store

   start_common()

   store_intro()
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
 local action_index = 1
 local obj
 local deferred_action = nil
 local enemy_inv

 local stat_speech = {
  closeness={
   high=function()
    color(14)
    print("just a little closer and he'll")
    print("let me into his heart")
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
  attraction={
   high=function()
    color(12)
    print("your beauty defies words")
    print("my life begins today")
   end,
   mid=function()
    color(12)
    print("you're quite fetching but")
    print("i still have reservations")
   end,
   low=function()
    color(12)
    print("i'm sorry but you're not for me")
   end
  },
  patience={
   high=noop_f,
   mid=noop_f,
   low=function()
    color(12)
    print("your antics bore me")
   end
  }
 }

 local function queue_victory_text()
  queue_text(function()
   color(12)
   print("your charm leaves me powerless")
   print("consider it yours")
   print("and remember me")
  end)
 end

 local raise_multipliers = {
  closeness=function()
   return .25
  end,
  attraction=function()
   return (4+inventory.hearts_count)/15 --TODO
  end
 }

 local lower_multipliers = {
  closeness=function()
   return .33
  end,
  attraction=function()
   return .2
  end,
  patience=function()
   return .4
  end
 }

 local function scaling_function(original,scale)
  return scale - .6*scale*(1-original)*(1-original)
 end

 last_stat_map = {}
 local function report_stat(stat)
  local level
  if obj[stat] < 0.5 then
   level = 'low'
  elseif obj[stat] < 1 then
   level = 'mid'
  else
   level = 'high'
  end

  if last_stat_map[stat] != level then
   last_stat_map[stat] = level
   queue_text(stat_speech[stat][level])
  end
 end

 local function lower_stat(stat, multiplier)
  multiplier = multiplier or lower_multipliers[stat]()
  obj[stat]-= scaling_function(obj[stat],multiplier)
  if obj[stat] < 0.0 then
   obj[stat] = 0
  end
  --
  report_stat(stat)
 end

 local function raise_stat(stat, multiplier)
  multiplier = multiplier or raise_multipliers[stat]()
  obj[stat]+= scaling_function(1-obj[stat],multiplier)
  if obj[stat] > 0.9 then
   obj[stat] = 1
  end

  report_stat(stat)
 end

 local function dazzle_check()
  return obj.closeness < 0.5
 end

 local function withdraw_check()
  return obj.closeness > 0
 end

 local function advance_check()
  return obj.closeness < 1
 end

 local function counterattack_check()
  obj.patience-= 1-obj.attraction
  if obj.patience <= 0 then
   obj.patience+= 1
   return true
  end
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

 local damage_player = function()
  inventory.remove_heart()
  obj.projectile_count = inventory.hearts_count
  if inventory.hearts_count <= 0 then
   obj.current_action.lose = true
   deferred_action = lose
  else
   lower_stat('closeness')
  end
 end

 local function counterattack()
  obj.current_action = {
   name = 'counterattack',
   start = function()
    queue_text(function()
     color(12)
     print "i've had enough of this"
    end)
   end,
   middle = function()
    queue_text(function()
     color(14)
     print "so hurtful.."
    end)
    damage_player()
   end
  }
 end

 local function run()
  obj.current_action = {
   name = 'run',
   start = function()
    queue_text(function()
     color(12)
     print "do i mean nothing to you?"
    end)
   end,
   middle = function()
    queue_text(withdraw_speech)
   end
  }
 end

 local function attempt_counterattack()
  if counterattack_check() then
   deferred_action = counterattack
  end
 end

 obj =  {
  sprite = sprite,
  hp = 1,
  patience = 1,
  closeness = 0.2,
  attraction = .3,
  base_y = 26,
  kill = function()
   if enemy_inv then
    enemy_inv.clear_hearts()
   end
   sprite.kill()
  end,
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

      lower_stat('attraction')
     end
    }
    attempt_counterattack()
   else
    run()
   end
  end,
  dazzle = function()
   reset_actions()

   if dazzle_check() then
    obj.current_action = {
     name = 'magic',
     start = function()
      queue_text(function()
       color(14)
       print("behold the power...")
      end)
     end,
     middle = function()
      if obj.attraction >= 1 then
       queue_text(function()
        color(14)
        print("of my loveliness?")
       end)
       lower_stat('patience')
      else
       queue_text(function()
        color(14)
        print("of my loveliness!")
       end)
       raise_stat('attraction')
       obj.patience = 1
      end
      attempt_counterattack()
     end
    }
   else
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
       queue_text(function()
        color(14)
        print("we've grown too close")
        print("his eyes no longer sparkle")
       end)
       lower_stat('attraction')
      end
     }
     attempt_counterattack()
    end
   end
  end,
  advance = function()
   reset_actions()

   if advance_check() then
    raise_stat('closeness')

    obj.current_action = {
     name="move",
     start=function()
     end,
     middle=function()
      lower_stat('attraction')
     end
    }
   else
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
      obj.hp-=1
      if enemy_inv then
       enemy_inv.remove_heart()
      end
      if obj.hp <= 0 then
       obj.current_action.win = true
       deferred_action = win
       queue_victory_text()
      else
       lower_stat('attraction')
      end
     end
    }
   end
   attempt_counterattack()
  end,
  intro_speech = intro_speech
 }

 if inventory.current_store_index == 1 then
  obj.attraction = 0.6

  lower_multipliers.attraction=function()
   return 0
  end
 elseif inventory.current_store_index == 2 then
  local function dazzle_check()
   return true
  end
 end

 if inventory.current_store_index < 3 then
  dazzle_check = function()
   return true
  end
 end

 if inventory.current_store_index < 4 then
  damage_player = function()
   lower_stat('closeness')
  end
  raise_multipliers.attraction=function()
   return .5
  end
  obj.projectile_count = 4
 else
  if inventory.current_store_index == 4 then
   damage_player = function()
    inventory.remove_heart()
    obj.projectile_count = inventory.hearts_count
    if inventory.hearts_count <= 0 then
     deferred_action = run
    else
     lower_stat('closeness')
    end
   end
   enemy_inv = make_inventory(true)
   obj.hp=2
   for i=1,obj.hp do
    enemy_inv.add_heart()
   end
  end
  for i=1,4 do
   inventory.add_heart()
  end
  obj.projectile_count = inventory.hearts_count
 end

 if inventory.current_store_index == 5 then
  queue_victory_text = function()
   queue_text(function()
    color(12)
    print "no one will ever compare"
    print "let me be forever yours"
   end)
  end
  enemy_inv = make_inventory(true)
  obj.hp=4
  for i=1,obj.hp do
   enemy_inv.add_heart()
  end
 end

 return obj
end
-- end ext
-- start ext main.lua
function sprite_collided(x,y)
 return solid_px(x,y) or
  solid_px(x+7,y) or
  solid_px(x,y+7) or
  solid_px(x+7,y+7)
end

function solid_px(x,y)
 return check_px(x,y,1)
end

function check_px(x,y,bit)
 return check_tile(flr(x/8),flr(y/8),bit)
end

local door_data
local doors, gate

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
  return inventory.current_store()
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
  local fancy_print = function(string,x,y,col1,col2)
   for xi=x-1,x+1 do
    for yi=y-1,y+1 do
     print(string,xi,yi,col1)
    end
   end
   print(string,x,y,col2)
  end
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
  print(sale.text,sale.x,sale.y,sale.color)
 end
end
-- end ext
__gfx__
0aaeaa0000aaeaa00aaeaa0000000000000444000044400000044400000000000000005f99999999088188100000000000000000008880000000000000000000
0a0acf000a00acf00a0acf0000000000000fc50000fc5000000fc50f00000000000000f497777779888888810008888000000080888888000080080000000000
0000f80000000f8f00f0f800000000000f6e466ff6e46600006e466f00000000000000f497677679888888810088880800088808088888880888888000888800
000f3bb0000f3bb0000f3bb0000000000f56655ff56655f00f56655f00000000000000549eee9eee888888810888008000880080800088888888888808880080
00f0ff0f00f0ff000000ff0f0000000000066500006650f00f066500000000000000005f20002000088888100800888000800880880008880800008008008880
0003bb000003bbf00003bb0000000000000ccc1004ccc10000ccccf000000000000000f422122221008881008088880000808800888000888880088800888800
000f0f00000f004000004f0000000000000f0f0005f0ccf000f1044000000000000000f4221222e1000810000888800008088000088888080888888000000000
000404000004000000000400000000000045450000000450044000000000000000000054ee0eee00000000000000000000800000000888800088880000000000
44443b3b45443443454344443335f3434b35f33bbb35fbb45438c5539f949f949f949f9400200020433453549f949f949777777900000000343bbb3443bbbbb3
4cb33f3b3f355f3b3f3b3844353f4b33433f4f3b3f3f4333437c87359f949f949dddddd412221222455435349f949f9497777779000000003bbb33b33bbb33b4
44b3f443f443f443f4433b3435bf433434bff443f44f432b57b8cb739f949f949dc7c7d4122e02ee343533449f949f949767767949999994bb3338333b33333b
c335f445444544f544453b344b354b538335f44544454344397bb7939f949f949d7c7cd402200e003eee3eee9f949f949eee9eee90777709b83333333b333933
b3c5f445f4454445f445f33b34b5f4534b35f445f4454b34594774959f949f949dc7c7d40ee02002200020009f949f942000200097077079b3383333b3933333
34bf4443f443f44bf44f4343543f43b343bff443f44f4335354994359f949f949d7c7cd420022212221222219f949f9422122221977777793333383533339335
333f4f43ff4bf443fb4f43b333bf433545b3f44bff43b444334994539f949f949dddddd42e122212221222e149454945221222e1900770093383333535333353
3b3543bb535434353b3f43b343b54b334445b34334344454445993359f949f949f949f94e00ee00eee0eee0033533533ee0eee00977777793533535335335353
353d534353534532455353545d515d5100000000f55555041111111100000000222222223333333377777776777777767777777612101210f555555444553554
543535453d55335354353533d5d5d5d50f000f00f64455041ccc88c107e277702e88e8823b1bbb1377757776777577767775777621212121f6444454435ff534
5343535353535434534d53535d515d51f440f440f44445041ccc88880722ea702e88888231d1b1d177555776775577767775577612101210f44444543335f453
535d45d4553545533453533515101510444444f4f44445041cc88888072229702e7888723d1d1d1d75555576755555767555557601000100f44446545333f435
3535354533235335353535335d515d51f4444444f44445041c88888207a2a99027ee8ee73bbbbbb377757776775577767775577612101210f44444545353f453
535353545455453d53553d35d5d5d5d5f440f440f64440041c882000079a999a27eeeee7311d1d1177757776777577767775777621212121f64444543533f433
3535433435d33543554453435d515d51ff40f440f440000518822c0107799999266eee663bb1d1b377777776777777767777777612101220f4444455433bf455
543354453535353545353353151015100000000022202220882211010000a9992267776233331333666666666666666666666666010001002220222043bff445
0000000048d2d2c448d4e2c4009000904e95245911111111ccccccccaaaaaaaa66656665aa565565001221222212212222aafaaaaaaaaaaaaaaaaa7a00000000
00000000439be83443923834900a9900e495425911111c11ccccccccaaaaaafa66655555a6655666001221222212212222aaaaaaaaaaaaaaaaaaa66600000000
00000000435333544333353409aaaa09449544591c111111ccccccccaafaaaaa66656665a5566657001221222212212222122aafaaaaaaaaaaaa665700000000
400000004eeebeee4359339409aa7aa044954459111aa11cccccccccaaaaaaaa55556665a6665565000001222212212222122aaaaaaaafaaaaa6556500000000
0fb0f0ae2000200041c3e2d40aa7aa904e952459aaaaaaaaccccccccaaaafaaa66656665a5555766000001222212212222122faaaaaaaaaaaa65576600000000
00bbbfca2212222143233c3490aaaa90e4954259afaaaaaaccccccccaaaaaaaa66655555aa566656000000002212212222122122aafaaaaaaa65665600000000
4f3b38fa221222e1435353540099a00944954459aaaaafaaccccccccafaaaaaa66656665a6665555000000002212212222122122aaaaaaaaa656555500000000
00000000ee0eee004f4ff4f40900090044954459aaaaaaaaccccccccaaaaaaaf55556665a5557666afaaaafa2212212222122122aaaaaaaaa565766600000000
000777700600677000000000aaaaaaaaaaaafaaaaaaaaaaaa3aaaaaaaaaaaaaa439324594e952459777700000000560045115459451154594511545945115459
067776000077770007777607aaa7f7aaaaaffaaaa4444aaaaab3b3b33a33afaa3b3b3b59e49542597777000000000760e0000059000000590000005900000059
676077706770777076777770f7f7f7fafff6fffaa544444aa33b3b3a3aaa3333b3b3b35944954459000077770000067540777777077777700c6cccc077777709
77677677777777677776077767f7fff7af666faaaa555444aaa33a3aab3b3b3a3b3b3b5944954459000077770000057640766667078e2d7006c6c6c076666709
077770700770777677777777a6f7fff7aaf6faaaaaaaa555faa3aa3a33b3b3aa233332594e95245977770000000056764078f2d7078e2d70066c6c6078f2d709
607677006670067067766777fa676aaaafffffaaaaafaaaaaa3a3aa3aa33a3aa12332159e49542597777000000056775e077777707df897006c6c6c077777709
000007700066770006777760aaaaafaaafaaafaaafaaaaaaaaaaaaaaaaaaaaaf412214594400445900007777057677504000000007df8970066c666000000009
006000000000000000000000aaaaaaaaaaaaaaaaaaaaaaafaaaaaafaa3aaaaaa4411445940006459000077770007750040777777077777700666c66077777709
ee2888888888222772228888888882ee700000007777777700000007700000000000000000000007344444434e95245940766667777777770c6c6c6076666709
eeeee8888222277777722228888eeeee700000000000000000000007700000000000000000000007b222b22be4954259e07eacf77000000706c6ccc07eacf709
8eeeeee827777700007777728eeeeee87000000000000000000000077000000000000000000000073999b993449ee45940777777706666070c6cccc077777709
2eeeeee277000000000000772eeeeee2700000000000000000000007700000000000000000000007b355555244eee459400000007029d8070000000000000009
2eee882770000000000000077288eee2700000000000000000000007700000000000000000000007335335334ee7045947777777700000077777777777777779
22ee877700000000000000007778ee22700000000000000000000007700000000000000000000007b22b222b77777759e7000000700000077000000700000079
22ee270000000000000000000072ee22700000000000000000000007700000000000000000000007399b99936666665947066660777777777066660706666079
22287700000000000000000000778222700000000000000000000007777777777777777777777777b444444b44954459470e28f04495441170e28f070e28f079
228770000000000000000000000778224e9624594e7524594e7624594e7624594e7624594e7624594e9524594e9524594e952459470000007000000700000079
28770000000000000000000000007782e4966259e7754259e7766259e7766259e7766259e7766259e4954259e4954259e4954259e70666607066660706666079
287000000000000000000000000007824496065970754459707606597076065970760659707606594495445944988459449bb459470e82a07029d8070e518079
28700000000000000000000000000782449600670075445900760a6700760067007600670076006744774459488884594bbbb459470000007000000700000079
887000000000000000000000000007884e960000007524596076a000a0760000a0760009eb760000477774594222245943333459470000007000000700000079
87700000000000000000000000000778e49600000075425960760a0a00760606a07600080a760606777777597777775977777759e70000007000000700000079
870000000000000000000000000000784496000000754459c07600a00076080870760c04cd760b0b666666596666665966666659477777777777777777777779
770000000000000000000000000000774496000000754459007600c0007600000076606000760000449544594495445944954459449544114495441144954419
000000000000000000000000000000004e960000007524597076000060760606a0760600b07606064e9524594e9114594e952459451154594511545945115459
00000000000000000000000000000000e4960000007542597076000666760a0aa076000a0a760202e4954259e4911259e4954259e77777597777775977777759
000000000000000000000000000000004496000000754459b0760a0060760000b0760800a0760000449aa4594411145944954459476116226336dd796ee66600
0000000000000000000000000000000044960011007544590076a0a16076061600767071007606164aaaa4594111145944774459476116226336dd796ee66600
000000000000000000000000000000004e9601111075245910760a1110760e1e1076071110760c1c499994594000045947777459476116226336dd796ee66600
00000000000000000000000000000000e49561111795425917956111179561111795611117956111777777597777775977777759e7116226336dd679ee666006
00000000000000000000000000000000449546117495445974954611749546117495461174954611666666596666665966666659477777777777777977777777
00000000000000000000000000000000449544674495445944954467449544674495446744954467449544594495445944954459449544114495441944954411
4e9524594e9524594e9524594e9524594e9524594e9524591111111111111111111c111111111111111111110000000000000000000000000000000000000000
e4954259e4954259e4954259e4954259e4954259e495465914111c4111111c11c677711c11111c1111111c110000000000000000000000000000000000000000
449544594495445944954459669544594495445944956659144444411c111111166671111c1111111c1111110000000000000000000000000000000000000000
44954466449544594495446666654459449544594496665914ffff4c1111111ca6667a11aaa1111c11fff11a0000000000000000000000000000000000000000
4e9524664e9524594e9524666e66666666666666666626591144441111111111a5666aaaaaaaafffffaffafa0000000000000000000000000000000000000000
e4954256e4954259e495426924964259e4964259e4964259aaffffaafff1c11faa556aaaaaaaaaaaaffaffaa0000000000000000000000000000000000000000
449544566666666666666669d22224594422245944222d59aa4444aaaffffffaaaaaaaaaaaaaaaaaaaaaafaa0000000000000000000000000000000000000000
4495445946954659469546592dddd2222225222222ddd259aaffffaaaffffffaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000
4e9524594695265946952659d5dd2dddddd2dddddd2d5d59aa4444aaaaafffaa0000000000000000000000000000000000000000000000000000000000000000
e4954259e8954c59eb954e592ddddddddd252dddddddd259aaffffaaaaaffffa0000000000000000000000000000000000000000000000000000000000000000
4495445948954c594b954e59d5dd2dddddd2dddddd2d5d59a444444aaafaffaa0000000000000000000000000000000000000000000000000000000000000000
449544598885ccc9bbb5eee92ddddddddd252dddddddd259affffffaaaaaffaa0000000000000000000000000000000000000000000000000000000000000000
4e9524598885ccc9bbb5eee922222ddddd222ddddd22225944444444aaaaffff0000000000000000000000000000000000000000000000000000000000000000
e4954259e6954659e695465952222222222222222222255944444444aaaaaaaf0000000000000000000000000000000000000000000000000000000000000000
449544594695465946954659d5dd222222d2d222222d5d59aaaaaaaaafaaaaaa0000000000000000000000000000000000000000000000000000000000000000
449544598885ccc9bbb5eee92ddddddddd252dddddddd259aaaaaaaaaaaaaaaf0000000000000000000000000000000000000000000000000000000000000000
4e9524598885ccc9bbb5eee9d5dd2dddddd2dddddd2d5d5900000000000000000000000000000000000000000000000000000000000000000000000000000000
e4954259e8954c59eb954e592ddddddddd252dddddddd25900000000000000000000000000000000000000000000000000000000000000000000000000000000
449544594495445944954459d5dd2dddddd2dddddd2d5d5900000000000000000000000000000000000000000000000000000000000000000000000000000000
4495445944954459449544592ddddddddd252dddddddd25900000000000000000000000000000000000000000000000000000000000000000000000000000000
4e9524594e9524594e95245922dd2dddddd2dddddd2d225900000000000000000000000000000000000000000000000000000000000000000000000000000000
e4954259e4954259e495425942222ddddd222ddddd22245900000000000000000000000000000000000000000000000000000000000000000000000000000000
44954459449544594495445944222222222222222222445900000000000000000000000000000000000000000000000000000000000000000000000000000000
44954459449544594495445940006222220062222200645900000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000b0000000000000303030303030303030303030c04040401010101000b030303030000000109030003010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011111111111111111111111111111236363636363636363636363636363636363636343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131a1a1a1a1a1a1a1f1e201a1a1a201336363636363636363636363636363636363636344c4e4f34484c4e4d4f48344c4e4f340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13191919191919192f2f21191919211335353535358a88898a35868a358735898a3589345c5e5f34345c5e275f34345c5e5f340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13181818291818181e1f20181818201337373e37373737373737963737973737373737346d6e6f34486d6e5d6f48346d6e6f340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131b1b1b251b1b1b2f2f2118281821133d3d393d3d3d3d463d3d3d3d37433d3d374437344949494949494949494949494949490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132122322d3221222222201b251b2213373739453743373737374437373737453737474a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1321202123222232202122322d32201637373950515555555555555555555555555253343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132221232323232d232323232323232d3c3739603f3f3f3f3f3f3f3f3f3f3f3f3f3f63343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1320222322212032222122232221232d3b3739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56344864686965342848346466676548340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13212123212220202022202d212022163a3739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56344874787975343434347476777548340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1322202d222122211a1a3109311a1a13373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56344949494949494949494949494949490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131a3109311a1e1f1919191919191913373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f564a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1319191919192f2f1818181718181813373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1318172717181f1e1718172617181713373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56343448345b3434264834347c344834340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131b1b1b1b1b2f2f1b1b1b1b1b1b1b13373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56344834486b3434343434347a483448340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14111111111111111111111111111115373739543f3f3f3f3f3f3f3f3f3f3f3f3f3f56343448346c347d7f7f7e347b344834340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000344949494949494949494949494949490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000004a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000343434343483848534343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000348081823493949534343480818234340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000349091923493949534294890919234340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000034a0a1a234939495343434a0a1a234340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000003449494949a3a4a549494949494949490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000004a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0002000023011210111f0111e0111e0111e0111d0111d0111d0111d0111f0212102123021270212a0212e0312f0312600136001230012200111001130011500116001180011a0011d00123001290012e0012f001
000d00000d5170d5170d5170e5170f5271052712527135371553714537145471054724547165472b5571b5572a557305452e54531545305452b5072d507315073450736507385073b5073d5053d5053c5053f505
000a000011550165501a5501e55024550195501d55021550275501c55021540255402b5402055025550295502f550365003a5003a500005000050000500005000050000500005000050000500005000050000500
011000081f625156151e625146151b625146151862514615146450060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
0008000014751157511b751237512f75135756387563a756007060070600706007060070600706007060070600706007060070600706007060070600706007060070600706007060070600706007060070600706
011000001c5531d5531f55328553295532b5533455335553375530050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503
011200000f6550e6050d6050960505605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
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
01 01474644
00 02474644
00 03484644
02 02474644
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

