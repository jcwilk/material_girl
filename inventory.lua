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
-- END LIB
