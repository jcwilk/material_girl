-- START LIB
function make_inventory(is_for_enemy)
  local owned_hearts = {}
  local obj
  obj = {
    store_sprite_map = {41,39,40,38},
    hearts_count = 0,
    current_store_index = 1
  }

  obj.increment_store = function()
    obj.current_store_index+=1
  end

  obj.add_heart = function()
    local heart
    if is_for_enemy then
      heart = sprites.make(10,{x=123-9*obj.hearts_count,y=-12,z=200})
      heart.before_draw = function()
        pal(8,5)
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
-- END LIB
