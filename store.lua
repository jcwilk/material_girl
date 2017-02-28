-- START LIB
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
-- END LIB
