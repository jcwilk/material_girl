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
  local intro_textbox, intro_store
  local game_over
  local clouds = make_pool()
  local sun
  local just_jumped = false --fancy bounce animation
  local sliding_store = false

  ----
  -- fighting animation update logic
  ----
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

  local function exit_battle()
    clouds.each(function(c)
      c.kill()
    end)
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

  local function jump_to(sprite,to_x,jump_sprites,skip_jump_anticipation)
    sprite.scale_x=4
    sprite.scale_y=4
    sprite.anchor_y=1
    sprite.y+=16

    local jump = function()
      sprite.anchor_y=0
      sprite.y-=32
      tweens.make(sprite,'x',to_x,10)
      tweens.make(sprite,'scale_x',3.5,3).next(function()
        return tweens.make(sprite,'scale_x',4,3)
      end)

      local smooshing = tweens.make(sprite,'scale_y',5,3).next(function()
        return tweens.make(sprite,'scale_y',3.5,3,'cubic',{
          ease_out=true
        })
      end).next(function()
        return tweens.make(sprite,'scale_y',4,4,'cubic')
      end)

      local jumping = tweens.make(sprite,'y',sprite.y-10,5,'quadratic',{
        ease_out=true
      }).next(function()
        sprite.sprite_id = jump_sprites[2]
        return tweens.make(sprite,'y',ofpy-16,5,'quadratic')
      end).next(function()
        sprite.anchor_y=1
        sprite.y+=32
        tweens.make(sprite,'scale_x',5.5,2,'quadratic',{ease_out=true})
        return tweens.make(sprite,'scale_y',2.8,2,'quadratic',{ease_out=true})
      end).next(function()
        sprite.sprite_id = jump_sprites[3]
        tweens.make(sprite,'scale_x',4,4,'quadratic')
        return tweens.make(sprite,'scale_y',4,4,'quadratic')
      end)

      return promises.all({jumping,smooshing}).next(function()
        sprite.scale_x = nil
        sprite.scale_y = nil
        sprite.anchor_y= nil
        sprite.y-=16
      end)
    end

    local anticipation_tween
    if skip_jump_anticipation then
      sprite.sprite_id = jump_sprites[1]
      return jump()
    else
      tweens.make(sprite,'scale_x',6,4)
      return tweens.make(sprite,'scale_y',3,4).next(function()
        sprite.sprite_id = jump_sprites[1]
        tweens.make(sprite,'scale_x',4,2)
        return tweens.make(sprite,'scale_y',4,2)
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

    tweens.make(enemy,'x',fighter.x+12,duration,'quadratic').on_complete = function()
      enemy.sprite_id = 6
      enemy.walking=false

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
    tweens.make(fighter,'x',cfpx,20)
    tweens.make(fighter,'y',ofpy,40,'quadratic')
    tweens.make(fighter,'scale',4,40,'quadratic').next(function()
      fighter.walking = false
      fighter.walking_scale=8
      enemy.hide = false
      enemy.walking=true
      --tweens.make(enemy,'scale',4,20,'quadratic').ease_out = true
      return tweens.make(enemy,'x',enemy_data.base_x,40,'quadratic',{
        ease_out=true
      })
    end).next(function()
      --enemy_data.intro_speech()
      intro_slide = false
      enemy.walking=false
      fanim=false

      queue_text(function()
        reset_combat_cursor()
        if inventory.current_store_index <= 4 then
          color(12)
          print "welcome, see how this fits"
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

  local function fwin()
    if inventory.current_store_index > 4 then
      queue_text(function()
        color(11)
        print("you win! <3 <3 <3")
        print("i haven't gotten this far")
        print("with the programming but")
        print("good job! :d")
        delays.make(0).next(function()
          while true do
          end
        end)
      end)
    end

    local winwait=60
    local win_sprite_id = ({39,40,38,41,10})[inventory.current_store_index]
    local win_heart = sprites.make(win_sprite_id,{x=fighter.x+16,y=enemy.y+8,scale=8,centered=true,z=40})
    if inventory.current_store_index < 5 then
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
    local float = tweens.make(enemy,'y',enemy.y-4,50,'quadratic')
    float.on_complete = function()
      fighter.sprite_id = 0
      enemy.kill()
      kiss=false
      local slide_out = tweens.make(win_heart,'x',fighter.x-32,12,'circular')
      slide_out.ease_out = true
      slide_out.on_complete = function()
        win_heart.z = 120
        tweens.make(win_heart,'x',fighter.x,12,'circular')
      end
      local slide_down = tweens.make(win_heart,'y',fighter.y+18,12,'circular')
      slide_down.ease_out = true
      slide_down.on_complete = function()
        tweens.make(win_heart,'y',fighter.y,12,'circular')
      end
      tweens.make(win_heart,'scale',1,24,'quadratic').next(function()
        win_heart.kill()
        fighter.sprite_id = 2
        inventory.increment_store()
        return tweens.make(fighter,'y',fighter.y-5,20,'quadratic',{ease_out = true})
      end).next(function()
        return delays.make(10)
      end).next(exit_battle)
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

      fanim = noop_f
      enemy.flip=true
      enemy.x+=8
      if enemy_data.hp <= 0 then
        fwin()
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
          enemy.flip=false
        end
      end
    end
  end

  local function fmagic()
    local spinx = fighter.x
    --fighter.sprite_id = 1

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
      return tweens.make(fighter,'x',-16,40,'quadratic')
    end).next(function()
      return delays.make(30)
    end).next(function()
      fighter.walking=false
      exit_battle()
    end)
  end

  local function fflee()
    enemy_data.current_action.start()
    enemy.walking = true
    fanim = noop_f
    enemy.flip=true
    enemy_data.current_action.middle()
    tweens.make(enemy,'x',cam.x+140,60,'quadratic').on_complete = function()
      enemy.walking=false
      exit_battle()
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
    if inventory.current_store_index >= 3 and btn(0) and not btn(1) and not btn(2) then
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
    if inventory.current_store_index >= 2 and btn(2) and not btn(0) and not btn(1) then
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
      if inventory.current_store_index >= 3 then
        spr(43,cam.x+25,cam.y+61)
        print("withdraw",cam.x+34,cam.y+63)
      end
      if inventory.current_store_index >= 2 then
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

  local function draw_stat(percentage, top_y, color)
    left_x = cam.x
    of_twenty = flr(max(percentage,0,1)*20+0.5)
    line(20-of_twenty+left_x,top_y,left_x+20,top_y,color)
  end

  local highest_cpu = 0
  local function draw_enemy_stats()
    draw_stat(enemy_data.closeness,9,8)
    draw_stat(enemy_data.attraction,10,9)
    draw_stat(enemy_data.patience,11,10)
    draw_stat(stat(0)/1024,12,11)
    draw_stat(stat(1),13,12)
    highest_cpu = max(highest_cpu,stat(1))
    draw_stat(highest_cpu,14,13)
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
          map(35,0,cam.x,intro_store.y,16,6) --sliding down store
        end
        palt()

        if not sliding_store then
          sprites.draw(20,nil) --foreground sprites
        end
      else
        map(16+3,0,cam.x,0,16,2) --sky
        sprites.draw(nil,10) --clouds,sun
        palt(0,false)
        map(19,2,cam.x,16,16,7) --beach
        if intro_store then
          map(35,0,cam.x,intro_store.y,16,6) --store
        end
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
      player.y=(player.y-64)*0.7+64 --move away from store

      start_common()

      store_intro()
    end,
    active = false
  }

  return obj
end
-- END LIB
