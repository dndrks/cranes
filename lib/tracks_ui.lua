local trx_ui = {}

local _hui

local snake_styles

function trx_ui.init()

	ui = {}
	ui.control_set = "play"
	ui.display_style = "single"
	ui.edit_note = {}
	ui.seq_focus = 1
	ui.menu_focus = 1
	ui.screen_controls = {}
	ui.seq_menu_focus = 1
	ui.seq_menu_layer = "nav"
	ui.seq_controls = {}
	ui.pattern_focus = { "s1", "s1", "s1", "s1" }

	ui.popup_focus = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
	ui.popup_focus.tracks = {}
	for i = 1, number_of_sequencers do
		ui.popup_focus.tracks[i] = {}
		for j = 1, 8 do
			ui.popup_focus.tracks[i][j] = 1
		end
	end

  for i = 1,8 do
    ui.seq_controls[i] =
    {
      ["seq"] = {["focus"] = 1}
    , ["trig_detail"] = {["focus"] = 1, ["max"] = 3}
    }
    ui.screen_controls[i] = {}
    ui.screen_controls[i] =
      {
        ["hills"] = {["focus"] = 1, ["max"] = 12}
      , ["bounds"] = {["focus"] = 1, ["max"] = 2}
      , ["notes"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "mute step", ["velocity"] = false}
      , ["loop"] = {["focus"] = 1, ["max"] = 2}
      , ["samples"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "shuffle"}
      }
  end
  
  tracks_ui = {}
  tracks_ui.focus = "seq" -- "params" or "seq"
  tracks_ui.sel = 1
  tracks_ui.hill_sel = 1
  tracks_ui.alt = false
  tracks_ui.param = 1
  tracks_ui.seq_position = {1,1,1,1,1,1,1,1,1,1}
  tracks_ui.seq_page = {1,1,1,1,1,1,1,1,1,1}
  tracks_ui.alt_view_sel = 1
  tracks_ui.alt_fill_sel = 1
  tracks_ui.show_chain = false
  tracks_ui.show_chain_edit_position = { 1, 1, 1 }
	tracks_ui.show_chain_edit_page = { 1, 1, 1 }
  tracks_ui.fill = {}
  tracks_ui.show_fill = false
  _hui = tracks_ui
end

local function check_for_menu_condition(i)
  if (key1_hold or (#conditional_entry_steps.focus[i] > 0)) and ui.control_set == 'edit' then
    return true
  else
    return false
  end
end

function trx_ui.draw_menu()

  local hf = ui.seq_focus
  local _page = tracks_ui.seq_page[hf]
  local _target = sequence[hf]
  local _a = sequence[hf][_page]
  screen.level(15)
  screen.move(0,10)
  screen.aa(1)
  screen.font_size(10)
  screen.text(ui.seq_focus)
  screen.fill()
  screen.aa(0)
  if ui.control_set ~= "seq" then
    if ui.control_set ~= 'step parameters' and ui.control_set ~= 'poly parameters' and ui.control_set ~= 'cc parameters' then
      local focus = hf
      screen.level(1)
      screen.rect(31,5,97,30)
      screen.fill()
      local menus = {"trigs","bounds","notes","loop","smpl"}
      screen.font_size(8)
      if ui.control_set == "edit" and ui.menu_focus ~= 1 then
        screen.move(0,22)
        screen.level(3)
        screen.text("trigs")
      elseif ui.control_set == "edit" and ui.menu_focus == 1 then
        screen.move(0,32)
        screen.level(3)
        screen.text("stp: ".._a.ui_position)
      end
      local upper_bound = 5
      for i = 1,upper_bound do
        screen.level(ui.menu_focus == i and (key1_hold and ((ui.menu_focus > 2 and  ui.control_set == "edit") and 3 or 15) or 15) or 3)
        screen.move(0,12+(10*i))
        if ui.control_set == "edit" and ui.menu_focus == i then
					screen.text(menus[i])
        elseif ui.control_set ~= "edit" then
          screen.text(menus[i])
        end
      end

      local focused_set = _target.focus == "main" and _a or _a.fill
      if ui.control_set == 'edit' then
        focused_set = tracks_ui.show_fill and _a.fill or _a
      end
      screen.move(0,10)
      screen.level(3)
      screen.level(_hui.focus == "seq" and 8 or 0)
      local e_pos = sequence[hf][_page].ui_position
      screen.rect(31+(trx_ui.index_to_grid_pos(e_pos,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(e_pos,8)[2])-4,13,8)
      screen.fill()
      local lvl = 5
      screen.font_face(2)
      for i = 1,24 do
        if e_pos == i then
          if _a.step == i and _a.playing and tracks_ui.seq_page[hf] == _target.page then
            lvl = _hui.focus == "seq" and 5 or 4
          else
            lvl = _hui.focus == "seq" and 0 or 2
          end
        else
          if i <= _a.end_point and i >= _a.start_point then
            if _a.step == i and tracks_ui.seq_page[hf] == _target.page then
              lvl = _hui.focus == "seq" and 15 or 4
            else
              lvl = _hui.focus == "seq" and 5 or 2
            end
          else
            lvl = 0
          end
        end
        screen.level(lvl)
        screen.move(37+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,3+(10*trx_ui.index_to_grid_pos(i,8)[2]))
        local display_step_data
        if ui.menu_focus ~= 3 then
          if focused_set.trigs[i] then
            if focused_set.muted_trigs[i] then
              display_step_data = 'M'
            elseif focused_set.accented_trigs[i] and not focused_set.lock_trigs[i] then
              display_step_data = '\\'
            elseif focused_set.lock_trigs[i] then
              display_step_data = 'P'
            else
              -- display_step_data = '|'
							display_step_data = focused_set.pad_id[i]
            end
          else
            if focused_set.lock_trigs[i] then
              display_step_data = '-P'
            else
              display_step_data = '-'
            end
          end
        else
          local note_index = focused_set.pad_id[i]
          if focused_set.trigs[i] == true then
            if focused_set.pad_id[i] == 0 then
              local note_check
              if params:string('voice_model_'..hf) ~= 'sample' and params:string('voice_model_'..hf) ~= 'input' then
                note_check = params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
              else
                note_check = params:get('hill '..hf..' base note')
              end
              display_step_data = note_check
            else
              display_step_data = note_index
            end
          else
            display_step_data = '-'
          end
        end

        if tracks_ui.alt and _hui.focus == "params" then
          local first
          local second = display_step_data
          local third
          if _hui.fill.start_point[_hui.sel] == i then
            first = "["
          else
            first = ""
          end
          if _hui.fill.end_point[_hui.sel] == i then
            third = "]"
          else
            third = ""
          end
          screen.text_center(first..second..third)
        else
          screen.text_center(display_step_data)
          -- local note_check
          -- if params:string('voice_model_'..hf) ~= 'sample' and params:string('voice_model_'..hf) ~= 'input' then
          --   note_check = params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
          -- else
          --   note_check = params:get('hill '..hf..' base note')
          -- end
          -- if focused_set.pad_id[i] == note_check then
          --   if e_pos == i then
          --     screen.level(15)
          --   else
          --     screen.level(4)
          --   end
          --   screen.move(33+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,15+(10*trx_ui.index_to_grid_pos(i,8)[2]))
          --   screen.line_rel(9,0)
          --   screen.stroke()
          -- end
          if focused_set.prob[i] ~= 100 then
            if focused_set.prob[i] <= 20 then
              for pix = 33,34 do
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 40 then
              for pix = 33,34 do
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 60 then
              for pix = 33,34 do
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,0+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 80 then
              for pix = 33,34 do
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(i,8)[2])-1)
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,0+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] < 100 then
              for pix = 33,34 do
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(i,8)[2])-2)
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(i,8)[2])-1)
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,0+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
              end
            end
            screen.fill()
          end
          if focused_set.conditional.A[i] ~= 1 or focused_set.conditional.B[i] ~= 1 then
            screen.pixel(40+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(i,8)[2])-3)
            screen.pixel(42+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,(10*trx_ui.index_to_grid_pos(i,8)[2])-3)
            screen.fill()
          end
          if focused_set.conditional.retrig_count[i] > 0 then
            screen.pixel(41+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,0+(10*trx_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(42+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(41+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(40+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,1+(10*trx_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(41+(trx_ui.index_to_grid_pos(i,8)[1]-1)*12,2+(10*trx_ui.index_to_grid_pos(i,8)[2]))
            screen.fill()
          end
        end
      end
      screen.font_face(1)

      if KEY2_hold then
        screen.font_size(8)
        screen.level(15)
        screen.move(128,64)
        screen.text_right("K3: PER-STEP PARAMS")
      else
        -- PAGE DISPLAY (bottom right)
        for i = 1,8 do
          lvl = _hui.seq_page[hf] == i and 10 or 2
          screen.level(lvl)
          -- screen.rect(117 + (util.wrap(i-1,0,3) * 3),i <= 4 and 56 or 59,2,2)
          screen.rect(113 + (util.wrap(i-1,0,3) * 4),i <= 4 and 56 or 60,3,3)
          screen.fill()
        end
      end

      if ui.menu_focus == 1 then
        screen.level(15)
        screen.move(128,42)
        if grid_mute then
          screen.text_right("[STEP MUTE]")
        elseif grid_accent then
          screen.text_right("[STEP ACCENT]")
        elseif grid_loop_modifier then
          if get_loop_modifier_stage() == 'define start' then
            screen.text_right('[SET LOOP START]')
          elseif get_loop_modifier_stage() == 'define end' then
            screen.text_right('[SET LOOP END]')
          end
        end
        screen.move(84,62)
        if ui.control_set == 'play' then
          screen.text(sequence[hf].focus == "fill" and "[FILL]" or "")
        elseif ui.control_set == 'edit' then
          screen.text(tracks_ui.show_fill and "[FILL]" or "")
        end
      elseif ui.menu_focus == 2 then
        local s_c = ui.screen_controls[hf]
        if ui.control_set == 'play' then
          screen.level(3)
        else
          screen.level(s_c["bounds"]["focus"] == 1 and 15 or 3)
        end
        screen.move(32,42)
        screen.text("min: "..sequence[hf][_page].start_point)
        if ui.control_set == 'play' then
          screen.level(3)
        else
          screen.level(s_c["bounds"]["focus"] == 1 and 3 or 15)
        end
        screen.move(128,42)
        screen.text_right("max: "..sequence[hf][_page].end_point)
      elseif ui.menu_focus == 3 then
        if ui.control_set == 'edit' then
          local pos = _active.ui_position
          local display_text = ''
          screen.level(3)
          if focused_set.trigs[pos] == false then
            display_text = 'set note adds trig'
          else
            local note_check
            if params:string('voice_model_'..hf) ~= 'sample' and params:string('voice_model_'..hf) ~= 'input' then
              note_check = params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
            else
              note_check = params:get('hill '..hf..' base note')
            end
            if focused_set.pad_id[pos] == note_check then
              display_text = 'K3: clear to default'
            end
          end
          screen.move(40,10)
          screen.text(display_text)
        end
      end

      -- if (key1_hold or (#conditional_entry_steps.focus[hf] > 0)) and ui.control_set == 'edit' then
      local current_step = sequence[hf][_page].ui_position
      if ui.menu_focus == 1 and ui.control_set ~= 'play' then
        local lvl_sel, lvl_other
        if (key1_hold or (#conditional_entry_steps.focus[hf] > 0)) and ui.control_set == 'edit' then
          lvl_sel = 15
          lvl_other = 4
        else
          lvl_sel = 2
          lvl_other = 2
        end
        -- draw_popup("->")
        -- screen.move(40,20)
        screen.move(32,42)
        screen.level(ui.popup_focus.tracks[hf][1] == 1 and lvl_sel or lvl_other)
        local base, line_above
        if focused_set.conditional.mode[current_step] == "NOT PRE" then
          base = "PRE"
          line_above = true
        elseif focused_set.conditional.mode[current_step] == "NOT NEI" then
          base = "NEI"
          line_above = true
        elseif focused_set.conditional.mode[current_step] == "A:B" then
          base = focused_set.conditional.A[current_step]..':'..focused_set.conditional.B[current_step]
          line_above = false
        else
          base = focused_set.conditional.mode[current_step]
          line_above = false
        end
        screen.text('COND: '..base)
        if line_above then
          -- screen.move(87,14)
          screen.move(57,36)
          screen.line(base == "PRE" and 70 or 69,36)
          screen.stroke()
        end
        screen.move(84,42)
        screen.level(ui.popup_focus.tracks[hf][1] == 2 and lvl_sel or lvl_other)
        screen.text('PROB: '..focused_set.prob[current_step]..'%')
        screen.move(32,52)
        screen.level(ui.popup_focus.tracks[hf][1] == 3 and lvl_sel or lvl_other)
        screen.text('RETRIG: '..focused_set.conditional.retrig_count[current_step]..'x')
        screen.level(ui.popup_focus.tracks[hf][1] == 4 and lvl_sel or lvl_other)
        local get_string = _a.focus == 'main' and ('track_retrig_time_'..hf..'_'.._page..'_'..current_step) or ('track_fill_retrig_time_'..hf..'_'.._page..'_'..current_step)
        screen.move(84,52)
        screen.text('RATE: '..track_paramset:string(get_string))
        screen.level(ui.popup_focus.tracks[hf][1] == 5 and lvl_sel or lvl_other)
        screen.move(32,62)
        local show_sign = focused_set.conditional.retrig_slope[current_step] > 0 and '+' or ''
        screen.text('SLOPE: '..show_sign..focused_set.conditional.retrig_slope[current_step])
      elseif ui.menu_focus == 2 then
        -- draw_popup(norns.state.path..'img/bolt.png',6,17)
        -- screen.move(15,20)
        -- screen.level(15)
        -- screen.text('[EUCLID]')
        -- screen.move(55,20)
        -- screen.level(ui.popup_focus.tracks[hf][2] == 1 and 15 or 4)
        -- screen.text('PULSES: '..focused_set.er.pulses)
        -- screen.move(55,30)
        -- screen.level(ui.popup_focus.tracks[hf][2] == 2 and 15 or 4)
        -- screen.text('STEPS: '..focused_set.er.steps)
        -- screen.move(55,40)
        -- screen.level(ui.popup_focus.tracks[hf][2] == 3 and 15 or 4)
        -- screen.text('SHIFT: '..focused_set.er.shift)
        -- screen.move(55,50)
        -- screen.level(ui.popup_focus.tracks[hf][2] == 4 and 15 or 4)
        -- screen.text('GENERATE (K3)')
      elseif ui.menu_focus == 3 then
        -- draw_popup(norns.state.path..'img/keys.png',9,17)
        -- screen.move(55,20)
        -- screen.level(ui.popup_focus.tracks[hf][3] == 1 and 15 or 4)
        -- screen.text('VELOCITY: '..focused_set.velocities[current_step])
        -- screen.move(55,30)
        -- screen.level(ui.popup_focus.tracks[hf][3] == 2 and 15 or 4)
        -- screen.text('CHORD DEG: '..focused_set.chord_degrees[current_step])
      end
      -- elseif grid_conditional_entry and #conditional_entry_steps.focus[hf] == 0 and ui.control_set == 'edit' then
      --   if ui.menu_focus == 1 then
      --     draw_prepop('STEP CONDITIONS')
      --   end
      -- elseif grid_data_entry and #data_entry_steps.focus[hf] == 0 and ui.control_set == 'edit' then
      --   if ui.menu_focus == 1 then
      --     draw_prepop('PARAMETER LOCKS')
      --   end
      -- end

    elseif ui.control_set == 'step parameters' then
      _fkprm.redraw()
    elseif ui.control_set == 'poly parameters' then
      _polyparams.redraw()
    elseif ui.control_set == 'cc parameters' then
      _ccparams.redraw()
    end
  end
end

function trx_ui.parse_grid(x,y,z)
	local hf = ui.seq_focus
	local _page = tracks_ui.seq_page[hf]
	local _target = sequence[hf]
	local _a = sequence[hf][_page]
  local i = ui.seq_focus
  local j = tracks_ui.seq_page[i]
	local focused_set = _target.focus == "main" and _a or _a.fill
  -- main step space:
  if x >= 4 and x<= 11 and y >= 9 and y <= 11 and z == 1 then
    if tracks_ui.show_chain then
      tracks_ui.show_chain_edit_position[i] = util.clamp(((y-9)*8) + (x-3),1,#sequence[i].page_chain+1)
    else
			if ui.control_set == "play" then
				focused_set = _target.focus == "main" and _a or _a.fill
			else
				focused_set = tracks_ui.show_fill and _a.fill or _a
			end
      sequence[i].ui_position = ((y-9)*8) + (x-3)
      _tracks.change_trig_state(focused_set, sequence[i].ui_position, not focused_set.trigs[sequence[i].ui_position], i, j, _page)
    end
  -- sequencer pages:
  elseif x >= 13 and x <= 16 and y >= 9 and y <= 10 and z == 1 then
    local sel = (x - 12) + ((y - 9) * 4)
    if ui.control_set ~= 'edit' then
      ui.control_set = 'edit'
    elseif tracks_ui.seq_page[hf] == sel and not tracks_ui.show_chain then
      ui.control_set = 'play'
      tracks_ui.seq_page[hf] = sequence[hf].page
    end
    if ui.control_set == 'edit' then
      if tracks_ui.show_chain then
        tracks_ui.show_chain_edit_page[hf] = sel
				sequence[hf].page_chain_ids[tracks_ui.show_chain_edit_position[hf]] = sel
				sequence[hf].page_chain:settable(sequence[hf].page_chain_ids)
      else
        tracks_ui.seq_page[hf] = sel
      end
    end
  elseif x == 1 and y >= 9 and y <= 11 then
    ui.seq_focus = y - 8
  elseif x == 12 and y == 12 then
    if ui.control_set == 'play' then
      _target.focus = z == 1 and "fill" or "main"
    else
      tracks_ui.show_fill = z == 1
    end
  elseif x == 16 and y == 11 then
    tracks_ui.show_chain = z == 1
  end
end

function trx_ui.draw_grid(v)
	local p = tracks_ui.seq_page[v]
  for i = 1,3 do
    g:led(1, i + 8, ui.seq_focus == i and 12 or 3)
  end
  -- fill button:
  if ui.control_set == 'play' then
    g:led(12,12,sequence[v].focus == "main" and 2 or 10)
  else
    g:led(12,12,tracks_ui.show_fill and 10 or 2)
  end
  -- chain button:
  g:led(16,11,tracks_ui.show_chain and 10 or 3)
  if ui.control_set == 'play' or ui.control_set == 'edit' then
		local this_seq = sequence[v][p]
    if tracks_ui.show_chain then
      -- show pattern chain:
      for s = 1,24 do
				local x = util.wrap(s, 1, 8)
				local batch = s <= 8 and 1 or (s <= 16 and 2 or 3)
				local brightness
        if tracks_ui.show_chain_edit_position[v] == s then
          brightness = 15
        elseif sequence[v].page_chain.ix == s then
          brightness = 8
        else
          brightness = sequence[v].page_chain[s] ~= nil and 4 or 2
        end
        g:led(x+3, batch+8, brightness)
      end
    else
      -- show steps:
      for s = this_seq.start_point, this_seq.end_point do
        local x = util.wrap(s,1,8)
        local batch = s <= 8 and 1 or (s<= 16 and 2 or 3)
        local brightness
        local focused = sequence[v].focus == "main" and sequence[v][p] or sequence[v][p].fill
        if ui.control_set == 'play' then
          focused = sequence[v].focus == "main" and sequence[v][p] or sequence[v][p].fill
        else
          focused = tracks_ui.show_fill and sequence[v][p].fill or sequence[v][p]
        end
        if this_seq.step == s and sequence[v].playing and tracks_ui.seq_page[v] == sequence[v].page then
          brightness = focused.trigs[s] and 15 or 10
        else
          brightness = focused.trigs[s] and 5 or 2
        end
        g:led(x+3, batch+8, brightness)
      end
    end
  elseif ui.control_set == 'step_parameters' then
		for s = step.seq[v].locks.start_point, step.seq[v].locks.end_point do
			local x = util.wrap(s, 1, 8)
			local batch = s <= 8 and 1 or (s <= 16 and 2 or 3)
			local brightness
			if step.seq[v].current_step == s and sequence[v].playing then
				brightness = step.seq[v].locks[s].active and 15 or 10
			else
				brightness = step.seq[v].locks[s].active and 5 or 2
			end
			g:led(x + 8, batch + 8, brightness)
		end
  elseif ui.control_set == 'rotate' then
    for s = 0,15 do
      local brightness
      if s == math.abs(step.seq[v].step_offset) then
        brightness = step.seq[v].step_offset >= 0 and 10 or 0
      else
        brightness = step.seq[v].step_offset >= 0 and 3 or 10
      end
      g:led(s+1,v,brightness)
    end
  end
  -- patterns:
	for x = 13,16 do
    for y = 9,10 do
      g:led(x,y,2)
      local sel = (x - 12) + ((y-9)*4)
      if tracks_ui.show_chain then
        local brightness = 2
        -- if the chain step is empty, lowest brightness:
        if sequence[v].page_chain[tracks_ui.show_chain_edit_position[v]] == nil then
          brightness = 2
        else
          -- if the chain step has data:
          if sequence[v].page_chain[tracks_ui.show_chain_edit_position[v]] ~= nil then
            brightness = sel == sequence[v].page_chain[tracks_ui.show_chain_edit_position[v]] and 15 or 2
          end
          if sequence[v].page_chain:peek() == sel and sequence[v].page_chain[tracks_ui.show_chain_edit_position[v]] ~= sel then
            brightness = 5
          end
        end
				g:led(x, y, brightness)
      else
        if ui.control_set == 'edit' then
          if sequence[v].page == sel and sequence[v].page ~= p then
            g:led(x,y,5)
          elseif sequence[v].page == sel and sequence[v].page == p then
            g:led(x, y, 10)
          elseif p == sel then
            g:led(x, y, 10)
          end
        else
          if sequence[v].page == sel then
            g:led(x, y, 10)
          end
        end
      end
    end
  end
end

local conditional_modes = {"NOT NEI","NEI","NOT PRE","PRE","A:B"}

function trx_ui.cycle_conditional(i,j,step,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]] -- here, we want the UI page, not the tracked page
  local send_to_many = false
  if grid_conditional_entry and #conditional_entry_steps.focus[i] > 1 then
    step = conditional_entry_steps.focus[i][#conditional_entry_steps.focus[i]]
  end
  local focused_set = _a.focus == 'main' and _a or _a.fill
  if d > 0 then
    if focused_set.conditional.mode[step] == "A:B" then
      local current_B = focused_set.conditional.B[step]
      current_B = current_B+d
      if current_B > 8 then
        local newA = util.clamp(focused_set.conditional.A[step]+1,1,8)
        local newB = focused_set.conditional.A[step] ~= 8 and 1 or 8
        for s = 1,#conditional_entry_steps.focus[i] do
          focused_set.conditional.A[conditional_entry_steps.focus[i][s]] = newA
          focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = newB
        end
      else
        for s = 1,#conditional_entry_steps.focus[i] do
          focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = current_B
        end
      end
    else
      local which_mode = tab.key(conditional_modes,focused_set.conditional.mode[step])
      which_mode = util.clamp(which_mode + d,1,#conditional_modes)
      focused_set.conditional.mode[step] = conditional_modes[which_mode]
    end
  elseif d < 0 then
    if focused_set.conditional.mode[step] == "A:B" then
      if focused_set.conditional.A[step] == 1 and focused_set.conditional.B[step] == 1 then
        focused_set.conditional.mode[step] = "PRE"
        for s = 1,#conditional_entry_steps.focus[i] do
          focused_set.conditional.mode[conditional_entry_steps.focus[i][s]] = focused_set.conditional.mode[step]
        end
      else
        local current_B = focused_set.conditional.B[step]
        current_B = current_B+d
        if current_B < 1 then
          focused_set.conditional.A[step] = util.clamp(focused_set.conditional.A[step]-1,1,8)
          -- focused_set.conditional.B[step] = focused_set.conditional.A[step] ~= 1 and 8 or 1
          focused_set.conditional.B[step] = 8
          for s = 1,#conditional_entry_steps.focus[i] do
            focused_set.conditional.A[conditional_entry_steps.focus[i][s]] = focused_set.conditional.A[step]
            focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
          end
        else
          focused_set.conditional.B[step] = current_B
          for s = 1,#conditional_entry_steps.focus[i] do
            focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
          end
        end
      end
    else
      local which_mode = tab.key(conditional_modes,focused_set.conditional.mode[step])
      which_mode = util.clamp(which_mode + d,1,#conditional_modes)
      focused_set.conditional.mode[step] = conditional_modes[which_mode]
      for s = 1,#conditional_entry_steps.focus[i] do
        focused_set.conditional.mode[conditional_entry_steps.focus[i][s]] = focused_set.conditional.mode[step]
      end
    end
  end
end

function trx_ui.cycle_prob(i,j,step,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and _a or _a.fill
  if grid_conditional_entry and #conditional_entry_steps.focus[i] > 1 then
    step = conditional_entry_steps.focus[i][#conditional_entry_steps.focus[i]]
  end
  focused_set.prob[step] = util.clamp(focused_set.prob[step] + d, 0, 100)
  for s = 1,#conditional_entry_steps.focus[i] do
    focused_set.prob[conditional_entry_steps.focus[i][s]] = focused_set.prob[step]
  end
end

function trx_ui.cycle_retrig_count(i,j,step,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and _a or _a.fill
  focused_set.conditional.retrig_count[step] = util.clamp(focused_set.conditional.retrig_count[step]+d, 0, 128)
end

function trx_ui.cycle_retrig_time(i,j,step,d)
  local _active = sequence[i]
	local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and ('track_retrig_time_'..i..'_'.._active.page..'_'..step) or ('track_fill_retrig_time_'..i..'_'.._active.page..'_'..step)
  track_paramset:delta(focused_set,d)
end

function trx_ui.cycle_retrig_vel(i,j,step,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and _a or _a.fill
  focused_set.conditional.retrig_slope[step] = util.clamp(focused_set.conditional.retrig_slope[step]+d, -128, 128)
end

function trx_ui.cycle_er_param(prm,i,j,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and _a or _a.fill
  if prm == 'pulses' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, 0, focused_set.er.steps)
  elseif prm == 'steps' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, 0, 128)
  elseif prm == 'shift' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, -128, 128)
  end
end

function trx_ui.cycle_chord_degrees(i,j,step,d)
  local _active = sequence[i]
  local _a = _active[tracks_ui.seq_page[i]]
  local focused_set = _a.focus == 'main' and _a or _a.fill
  focused_set.chord_degrees[step] = util.clamp(focused_set.chord_degrees[step] + d, 1, 7)
end

function trx_ui.index_to_grid_pos(val,columns)
  -- local x = math.fmod(val-1,columns)+1
  -- local y = util.wrap(math.modf((val-1)/columns)+1,1,3)
  local x = ((val-1)%columns)+1
  local y = val <= 8 and 1 or (val<=16 and 2 or 3)
  return {x,y}
end

return trx_ui