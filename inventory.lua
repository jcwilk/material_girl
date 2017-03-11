-- START LIB
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
    equipped_items = equipped_items,
    current_store_index = 5
  }

  obj.current_store = function()
    -- lipstick, ring, shoes, dress
    return ({2,3,4,1})[obj.current_store_index]
  end

  obj.increment_store = function()
    obj.current_store_index+=1
  end

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

  -- obj.destroy_hearts = function()
  --  for _,h in pairs(owned_hearts) do
  --   tweens.make(h,'y',4)
  -- end

  obj.remap_girl_colors = function()
    pal(14,obj.ring_color)
    pal(8,obj.lipstick_color)
    pal(11,obj.dress_light_color)
    pal(3,obj.dress_dark_color)
    pal(4,obj.shoes_color)
  end

  obj.remap_kiss = function()
    pal(8,obj.lipstick_color)
  end

  obj.remap_hearts = function()
    pal(8,obj.ring_color)
  end

  return obj
end
-- END LIB
