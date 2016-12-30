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
function make_fight(inv)
 local obj, fanim, first_draw, kiss --misc fight state
 local ofpx, ofpy --player state
 local oepx, ehp, edef --enemy state
 local fighter, enemy --sprites

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
  enemy.kill()
  fighter.kill()
  sprites.make(player.sprite_id,player).flip = true
  obj.active = false
 end

 local function fenemy_attack()
  enemy.flip=false
  enemy.sprite_id=5

  tweens.make(enemy,'x',fighter.x+24,10,tweens.easings.quadratic).on_complete = function()
   fighter.sprite_id = 2
   fighter.x-= 2
   color(12)
   print "aint got nothin on this!"
   inventory.remove_heart()
   enemy.sprite_id = 6
   local rising = tweens.make(enemy,'y',ofpy-10,7,tweens.easings.quadratic)
   rising.ease_out = true
   rising.on_complete = function()
    tweens.make(enemy,'y',ofpy,7,tweens.easings.quadratic)
   end
   local pull_back = tweens.make(enemy,'x',oepx,14,tweens.easings.quadratic)
   pull_back.ease_out=true
   pull_back.on_complete = function()
    enemy.sprite_id = 4
    fanim = false
    fighter.sprite_id = 0
    fighter.x=ofpx
    color(14)
    print "how hurtful..."
   end
  end
 end

 function fintro()
  player.kill()
  fighter = sprites.make(0,{x=-20,y=ofpy,z=100})
  fighter.before_draw = function()
   inventory.remap_girl_colors()
  end
  fighter.centered = true

  fanim = function()
  end

  tweens.make(fighter,'scale',4,20,tweens.easings.quadratic).slide_out = true
  local slide_in = tweens.make(fighter,'x',ofpx,20,tweens.easings.quadratic)
  slide_in.ease_out = true
  slide_in.on_complete = function()
   color(7)
   print("wow, a void!")
   enemy = sprites.make(4,{x=128,y=ofpy,z=50})
   enemy.centered = true
   tweens.make(enemy,'scale',4,20,tweens.easings.quadratic).ease_out = true
   local e_slide_in = tweens.make(enemy,'x',oepx,20,tweens.easings.quadratic)
   e_slide_in.ease_out = true
   e_slide_in.on_complete = function()
    color(7)
    print("what a beautiful baker! <3")
    fanim = false
   end
  end
 end

 local function fwin()
  print "noooo"
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
    color(7)
    local jump = tweens.make(fighter,'y',fighter.y-5,14,tweens.easings.cubic)
    jump.ease_out = true
    jump.on_complete = exit_battle
   end
  end
 end

 local function fattack()
  -- local charging=true
  clear_text()
  color(14)
  print "*whistles*"
  local attack_success= edef < 1
  local pull_back

  fanim = function()
    fighter.sprite_id = flr(fighter.x/6)%3
  end

  approach_easing = tweens.easings.merge(tweens.easings.quadratic,tweens.easings.cubic)
  local approach = tweens.make(fighter,'x',enemy.x-16,20,approach_easing)
  --approach.ease_in_and_out = true
  approach.on_complete = function()
   fanim = function()
   end
   if attack_success then
    color(14)
    print "mwa! :*"
    kiss=flr(rnd()*5+11)
    ehp-=4
    enemy.x+=8
    enemy.sprite_id=6
   else
    enemy.flip=true
    enemy.x+=8
    color(7)
    print "cold shoulder!"
    color(12)
    print "i'm sorry but i..."
    print "think you got the wrong idea"
   end
   if ehp <= 0 then
    fwin()
   else
    local recede = tweens.make(fighter,'x',ofpx,12,tweens.easings.quadratic)
    fighter.sprite_id = 2
    recede.ease_in_and_out=true
    recede.on_complete = function()
     fighter.sprite_id=0
     kiss=false
     enemy.sprite_id=4
     enemy.x=oepx
     if attack_success then
      fanim=false
     else
      fenemy_attack()
     end
    end
   end
  end
 end

 local function fmagic()
  local spinx = fighter.x+20
  fighter.sprite_id = 1
  clear_text()

  fanim = function()
  end

  local rising = tweens.make(fighter,'y',ofpy-10,5)
  rising.ease_out = true
  rising.on_complete = function()
   tweens.make(fighter,'y',ofpy,5)
  end
  tweens.make(fighter,'scale',5,10)
  tweens.make(fighter,'x',ofpx+20,10).on_complete = function()
   fighter.sprite_id=2
   magwait=30
   --magwaitx=fpx
   color(14)
   print("behold the power...")
   local counter=0
   local hearts = {}
   for i=1,inventory.hearts_count do
    counter+=2
    local h = sprites.make(10,{x=fighter.x+9+counter,y=fighter.y-10+20*rnd(),z=100+counter})
    h.before_draw = function()
     pal(8,inventory.ring_color)
    end
    h.centered = true
    tweens.make(h,'x',enemy.x,flr(20+6*rnd()),tweens.easings.cubic).on_complete = function()
     tweens.make(h,'x',enemy.x+20,5)
     tweens.make(h,'scale',4,5).on_complete = h.kill
    end
    add(hearts,h)
   end
   fanim = function()
    magwait-=1

    for _,h in pairs(hearts) do
     if h.alive and h.z > 100 and h.x > enemy.x then
      h.z-= 100
     end
    end

    if flr(((50-magwait)/25)^3) % 2 == 0 then
     fighter.flip=true
     fighter.x = spinx+12
    else
     fighter.flip=false
     fighter.x = spinx
    end
    if magwait <= 0 then
     fighter.x = spinx
     fighter.flip=false
     color(14)
     print("of my loveliness!")
     fanim = function()
     end
     tweens.make(fighter,'scale',4,10)
     tweens.make(fighter,'x',ofpx,10,tweens.easings.cubic).on_complete = function()
      fighter.sprite_id = 0
      fanim=false
      enemy.x = oepx
      enemy.sprite_id=4
      edef-=1
     end
    end
   end
  end
 end

 local function frun()
  clear_text()
  color(14)
  print "screw this!"
  fighter.sprite_id = 2
  tweens.make(fighter,'x',-16,20,tweens.easings.quadratic).on_complete = function()
    exit_battle()
  end
  tweens.make(fighter,'scale',1,20,tweens.easings.quadratic)
  fanim = function()
  end
 end

 local function update_fight()
  if not obj.active then
   return false
  end

  if fanim then
   fanim()
   return true
  end

  if btn(0) and not btn(1) and not btn(2) then
   frun()
  elseif btn(1) and not btn(0) and not btn(2) then
   fattack()
  elseif btn(2) and not btn(0) and not btn(1) then
   fmagic()
  end

  return true
 end

 local function reset_combat_cursor()
  cursor(1,70)
 end

 -----------------------
 --Drawing fighting code
 -----------------------
 local function draw_fui()
  if not fanim then
   color(1)

   --rectfill(0,0,255,255)
   color(7)
   spr(43,25,61)
   cursor(34,63)
   print("withdraw")
   spr(42,46,53)
   cursor(55,55)
   print("dazzle")
   spr(44,67,61)
   cursor(76,63)
   print("advance")

   reset_combat_cursor()
  end
 end

 function draw_kiss()
  if kiss then
   if not kissx then
    kissx=enemy.x-6+rnd()*10
    kissy=enemy.y-14+rnd()*10
   end
   inv.remap_kiss()
   spr(kiss,kissx,kissy)
   pal()
  else
   kissx=false
   kissy=false
  end
 end

 local function draw_fight()
  if obj.active then
   if first_draw then
    first_draw=false
    cls()
    reset_combat_cursor()
   end
   --clear above text
   rectfill(0,0,127,69,0)
   draw_fui()
   sprites.draw()
   draw_kiss()
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
   first_draw=true

   oepx=96
   ehp=10
   edef=1
   espr=4

   ofpx=26
   ofpy=26
   fspr=0
   fflp=false

   obj.active = true
   fintro()
  end,
  active = false
 }

 return obj
end
-- END LIB
