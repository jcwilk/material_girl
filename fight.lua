-- START LIB
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
 local obj, fanim, first_draw, hide_enemy, kiss --misc fight state
 local fpx, fpy, ofpx, ofpy, fflp, fspr --player state
 local epx, epy, oepx, ehp, edef, eflp, espr --enemy state

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
  fpx=ofpx
  px=114
  flp=true
  obj.active = false
 end

 local function fenemy_attack()
  eflp=false
  espr=5
  local echarging=true
  local taunt_count=0
  local depy

  fanim = function()
   if echarging then
    epx-=4
    if epx<40 then
     echarging=false
     etaunting=true
     etauntleft=false
     fspr=2
     fpx-=2
     depy=4
     taunt_count=2
     color(12)
     print "aint got nothin on this!"
    end
   elseif etaunting then
    if etauntleft then
     epx-=4
     epy-=depy
     depy-=1
     if epy>ofpy then
      epy=ofpy
      etauntleft=false
      depy=4
      fpx-=1
      if taunt_count > 0 then
       taunt_count-=1
      else
       etaunting=false
      end
     end
    else
     epx+=4
     epy-=depy
     depy-=1
     if epy>ofpy then
      etauntleft=true
      depy=3
      epy=ofpy
     end
    end
   else
    espr=6
    epx+=4
    if epx>=oepx then
     espr=4
     epx=oepx
     fanim=false
     fspr=0
     fpx=ofpx
     color(14)
     print "how hurtful..."
    end
   end
  end
 end

 function fintro()
  fpx=-20
  fpy=ofpy
  epx=128
  epy=ofpy

  local enemy_intro = false

  fanim = function()
   if enemy_intro then
    epx-=flr((epx-oepx)/10)+1
    espr=4+flr(epx/8)%3
    if epx < oepx then
     epx=oepx
     espr=4
     fanim=false
     color(7)
     print("what a beautiful baker! <3")
    end
   else
    fpx+=flr((ofpx-fpx)/12)+1
    fspr=flr(fpx/5)%3
    if(fpx>=ofpx) then
     fpx=ofpx
     fspr=0
     color(7)
     print("wow, a void!")
     enemy_intro=true
    end
   end
  end
 end

 local function fwin()
  print "noooo"
  local winwait=60

  fanim = function()
   if winwait<0 then
    color(7)
    exit_battle()
   elseif winwait<20 then
    hide_enemy=true
   else
    hide_enemy=flr(((80-winwait)/20)^2) % 2 == 0
   end
   winwait-=1
  end
 end

 local function fattack()
  local charging=true
  clear_text()
  color(14)
  print "*whistles*"
  local attack_success= edef < 1
  fanim = function()
   if charging then
    fspr=flr(fpx/12)%3
    fpx+=4
    if fpx>=60 then
     fpx=60
     charging=false
     if attack_success then
      color(14)
      print "mwa! :*"
      kiss=flr(rnd()*5+11)
      ehp-=4
      epx+=5
      espr=6
     else
      eflp=true
      epx+=8
      color(7)
      print "cold shoulder!"
      color(12)
      print "i'm sorry but i..."
      print "think you got the wrong idea"
     end
    end
   else
    fspr=2
    fpx-=4
    if fpx<=ofpx then
     if ehp<=0 then
      fwin()
     else
      fpx=ofpx
      fspr=0
      kiss=false
      espr=4
      epx=oepx
      if attack_success then
       fanim=false
      else
       fenemy_attack()
      end
     end
    end
   end
  end
 end

 local function fmagic()
  local dfpy=4
  local magret=false
  local magwait=false
  fspr=1
  clear_text()

  fanim = function()
   if magwait then
    fspr=0
    if magwait>0 then
     if magwait<20 then
      for h in all(hearts) do
       if h.x and h.x > fpx+20+magwait then
        h.x+=8--flr(((20-magwait)/6)^2.5)
        if h.x>epx+30 then
         h.x=false
         epx+=1
         espr=6
        end
       end
      end
     end
     fspr=2
     if flr(((50-magwait)/25)^3) % 2 == 0 then
      fflp=true
      fpx=magwaitx
     else
      fflp=false
      fpx=magwaitx-8
     end

     magwait-=1
     return
    else
     color(14)
     print("of my loveliness!")
     magwait=false
     magret=true
    end
   end
   if magret then
    fspr=2
    fpx-=4
    if fpx<=ofpx then
     fspr=0
     fpx=ofpx
     fanim=false
     epx=oepx
     espr=4
     edef-=1
    end
    return
   end
   fpy-=dfpy
   dfpy-=1
   fpx+=3
   if fpy>=ofpy then
    fpy=ofpy
    magwait=30
    magwaitx=fpx
    color(14)
    print("behold the power...")
    local counter=0
    for h in all(hearts) do
     counter+=2
     h.x=fpx+25+counter--15*rnd()
     h.y=fpy+5+20*rnd()
    end
   end
  end
 end

 local function frun()
  clear_text()
  color(14)
  print "screw this!"
  fspr=2
  fanim = function()
   fpx-=3
   if fpx<=-30 then
    exit_battle()
   end
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

 function draw_fighter()
  local scale

  inv.remap_girl_colors()
  if fpx <= 0 then
   scale = 1
  else --if fpx < ofpx then
   scale = 3*fpx/ofpx+1
  --else
   --scale = 4
  end
  sprites.make(fspr,{x = fpx-10, y = fpy+(12*(4-scale)/3)})

  zspr(fspr,1,1,fpx,fpy+(12*(4-scale)/3),scale,fflp)
  pal()
 end

 function draw_enemy()
  local scale
  if not hide_enemy then
   if epx >= 120 then
    scale = 1
   elseif epx > oepx then
    scale = 3*(120-epx)/(120-oepx)+1
   else
    scale = 4
   end
   zspr(espr,1,1,epx,epy+(12*(4-scale)/3),scale,eflp)
  end
 end

 function draw_kiss()
  if kiss then
   if not kissx then
    kissx=epx+10+rnd()*10
    kissy=epy+2+rnd()*10
   end
   inv.remap_kiss()
   spr(kiss,kissx,kissy)
   pal()
  else
   kissx=false
   kissy=false
  end
 end

 function draw_hearts(fg)
  local scale
  inv.remap_hearts()
  for h in all(hearts) do
   if h.x then
    if not fg and h.x-4 > epx then
     scale = (h.x-epx)/4
     zspr(10,1,1,h.x-8,h.y-4*(scale-1),scale)
    elseif fg then
     spr(10,h.x,h.y)
    end
   end
  end
  pal()
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
   draw_fighter()
   draw_hearts(false)
   draw_enemy()
   draw_kiss()
   draw_hearts(true)
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

   oepx=80
   ehp=10
   edef=1
   espr=4

   ofpx=10
   ofpy=10
   fspr=0
   fflp=false

   hearts={}
   for i=1,6 do
    add(hearts,{})
   end

   obj.active = true
   fintro()
  end,
  active = false
 }

 return obj
end
-- END LIB
