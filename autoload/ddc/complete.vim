function! ddc#complete#_on_complete_done() abort
  if !ddc#_denops_running() || empty(v:completed_item)
        \ || !has_key(v:completed_item, 'user_data')
        \ || type(v:completed_item.user_data) != v:t_dict
    return
  endif

  " Search selected item from previous items
  let items = filter(copy(g:ddc#_items), { _, val
        \ -> val.word ==# v:completed_item.word
        \ && val.abbr ==# v:completed_item.abbr
        \ && val.info ==# v:completed_item.info
        \ && val.kind ==# v:completed_item.kind
        \ && val.menu ==# v:completed_item.menu
        \ && has_key(val, 'user_data')
        \ && val.user_data ==# v:completed_item.user_data
        \ })
  if empty(items)
    return
  endif

  call denops#request('ddc', 'onCompleteDone',
        \ [items[0].__sourceName, v:completed_item.user_data])
endfunction

function! ddc#complete#_check_complete_info() abort
  let pum_visible = exists('*pum#visible') ? pum#visible() : v:false
  let info = ddc#complete_info()
  let noinsert = &completeopt =~# 'noinsert'
  return pum_visible &&
        \ ((info.mode !=# '' && info.mode !=# 'eval')
        \ || (noinsert && info.selected > 0)
        \ || (!noinsert && info.selected >= 0))
endfunction

function! ddc#complete#_skip(pos, items) abort
  if a:pos < 0 || g:ddc#_changedtick != b:changedtick
        \ || ddc#complete#_check_complete_info()
    return v:true
  endif

  " Note: If the input text is longer than 'textwidth', the completed text
  " will be the next line.  It breaks auto completion behavior.
  if &l:formatoptions =~# '[tca]' && &l:textwidth > 0
    let input = getline('.')[: a:pos]
    let displaywidth = max(map(copy(a:items),
          \ { _, val -> strdisplaywidth(input . val.word) })) + 1
    let col = mode() ==# 'c' ? getcmdpos() : virtcol('.')
    if displaywidth >= &l:textwidth || col >= displaywidth
      return v:true
    endif
  endif

  return v:false
endfunction
