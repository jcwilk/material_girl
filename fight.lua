-- START LIB
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
-- END LIB
