-- START LIB
function make_inventory()
 local dress_light_color_map = {11,14,10,13}
 local dress_dark_color_map = {3,2,9,1}
 local lipstick_color_map = {8,14,13,2}
 local ring_color_map = {14,13,9,8}
 local shoes_color_map = {4,5,7,8}
 local equipped_items = {1,1,1,1}
 local obj = {
  store_sprite_map = {41,39,40,38},
  dress_light_color = 11,
  dress_dark_color = 3,
  ring_color = 14,
  lipstick_color = 8,
  shoes_color = 4
 }

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


 return obj
end
-- END LIB
