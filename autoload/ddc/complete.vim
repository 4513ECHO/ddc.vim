function ddc#complete#_on_complete_done(completed_item) abort
  if !ddc#_denops_running() || a:completed_item->empty()
        \ || !(a:completed_item->has_key('user_data'))
        \ || a:completed_item.user_data->type() != v:t_dict
    return
  endif

  call denops#request('ddc', 'onCompleteDone', [a:completed_item])
endfunction

function ddc#complete#_skip(pos, items) abort
  if a:pos < 0 || g:ddc#_changedtick != b:changedtick
    return v:true
  endif

  if g:ddc#_skip_next_complete > 0
    let g:ddc#_skip_next_complete -= 1
    return v:true
  endif

  " NOTE: If the input text is longer than 'textwidth', the completed text
  " will be the next line.  It breaks auto completion behavior.
  if &l:formatoptions =~# '[tca]' && &l:textwidth > 0
    const input = getline('.')[: a:pos]
    const displaywidth = max(a:items->copy()
          \ ->map({ _, val -> strdisplaywidth(input .. val.word) })) + 1
    const col = mode() ==# 'c' ? getcmdpos() : virtcol('.')
    if displaywidth >= &l:textwidth || col >= displaywidth
      return v:true
    endif
  endif

  return v:false
endfunction
