"=============================================================================
" FILE: pum.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

if has('nvim')
  let s:ddc_namespace = nvim_create_namespace('ddc')
endif
let g:pum#skip_next_complete = v:false
if !exists('g:pum#highlight_select')
  let g:pum#highlight_select = 'PmenuSel'
endif

function! pum#_get() abort
  return s:pum
endfunction
function! pum#_init() abort
  if exists('s:pum')
    call pum#close()
  endif

  let s:pum = {
        \ 'buf': -1,
        \ 'items': [],
        \ 'cursor': -1,
        \ 'current_word': '',
        \ 'height': -1,
        \ 'id': -1,
        \ 'len': 0,
        \ 'orig_input': '',
        \ 'pos': [],
        \ 'startcol': -1,
        \ 'width': -1,
        \}
endfunction

call pum#_init()


function! pum#open(startcol, items) abort
  if !has('patch-8.2.1978') && !has('nvim-0.6')
    call s:print_error(
          \ 'pum.vim requires Vim 8.2.1978+ or neovim 0.6.0+.')
    return -1
  endif

  let max_abbr = max(map(copy(a:items), { _, val ->
        \ strwidth(get(val, 'abbr', val.word))
        \ }))
  let max_kind = max(map(copy(a:items), { _, val ->
        \ strwidth(get(val, 'kind', ''))
        \ }))
  let max_menu = max(map(copy(a:items), { _, val ->
        \ strwidth(get(val, 'menu', ''))
        \ }))
  let format = printf('%%-%ds%%-%ds%%-%ds',
        \ max_abbr + (max_kind != 0 ? 1: 0),
        \ max_kind + (max_menu != 0 ? 1: 0),
        \ max_menu)
  let lines = map(copy(a:items), { _, val -> printf(format,
        \ get(val, 'abbr', val.word),
        \ get(val, 'kind', ''),
        \ get(val, 'menu', ''))
        \ })

  let width = max_abbr + max_kind + max_menu
  " Padding
  if max_kind != 0
    let width += 1
  endif
  if max_menu != 0
    let width += 1
  endif

  let height = len(a:items)
  if &pumheight > 0
    let height = min([height, &pumheight])
  endif
  let height = max([height, 1])

  let spos = screenpos('.', line('.'), a:startcol)
  let pos = mode() ==# 'c' ?
        \ [&lines - height - 1, a:startcol] : [spos.row, spos.col - 1]

  if has('nvim')
    if s:pum.buf < 0
      let s:pum.buf = nvim_create_buf(v:false, v:true)
    endif
    call nvim_buf_set_lines(s:pum.buf, 0, -1, v:true, lines)
    if pos == s:pum.pos && s:pum.id > 0
      " Resize window
      call nvim_win_set_width(s:pum.id, width)
      call nvim_win_set_height(s:pum.id, height)
    else
      call pum#close()

      " Create new window
      let opts = {
            \ 'relative': 'editor',
            \ 'width': width,
            \ 'height': height,
            \ 'col': pos[1],
            \ 'row': pos[0],
            \ 'anchor': 'NW',
            \ 'style': 'minimal',
            \ 'noautocmd': v:true,
            \ }
      let id = nvim_open_win(s:pum.buf, v:false, opts)

      let s:pum.id = id
      let s:pum.pos = pos
    endif
  else
    let options = {
          \ 'pos': 'topleft',
          \ 'line': pos[0] + 1,
          \ 'col': pos[1] + 1,
          \ 'maxwidth': width,
          \ 'maxheight': height,
          \ }

    if s:pum.id > 0
      call popup_move(s:pum.id, options)
      call popup_settext(s:pum.id, lines)
    else
      let s:pum.id = popup_create(lines, options)
      let s:pum.buf = winbufnr(s:pum.id)

      " Add prop types
      call prop_type_delete('pum_cursor')
      call prop_type_add('pum_cursor', {
            \ 'highlight': g:pum#highlight_select,
            \ })
    endif
  endif

  " Note: :redraw is needed for command line completion in neovim
  if mode() ==# 'c' && has('nvim')
    redraw
  endif

  let s:pum.cursor = 0
  let s:pum.height = height
  let s:pum.width = width
  let s:pum.len = len(a:items)
  let s:pum.items = copy(a:items)
  let s:pum.startcol = a:startcol
  let s:pum.orig_input = s:getline()[a:startcol - 1 : s:col()]

  return s:pum.id
endfunction

function! pum#close() abort
  if s:pum.id <= 0
    return
  endif

  if has('nvim')
    call nvim_win_close(s:pum.id, v:true)
  else
    call popup_close(s:pum.id)
  endif

  let s:pum.current_word = ''
  let s:pum.id = -1
endfunction

function! pum#select_relative(delta) abort
  if s:pum.buf <= 0
    return ''
  endif

  " Clear current highlight
  if has('nvim')
    call nvim_buf_clear_namespace(s:pum.buf, s:ddc_namespace, 0, -1)
  else
    call prop_remove({
          \ 'type': 'pum_cursor', 'bufnr': s:pum.buf
          \ })
  endif

  let s:pum.cursor += a:delta
  if s:pum.cursor > s:pum.len || s:pum.cursor == 0
    " Reset
    let s:pum.cursor = 0

    call s:redraw()

    return ''
  elseif s:pum.cursor < 0
    " Reset
    let s:pum.cursor = s:pum.len
  endif

  if has('nvim')
    call nvim_buf_add_highlight(
          \ s:pum.buf,
          \ s:ddc_namespace,
          \ g:pum#highlight_select,
          \ s:pum.cursor - 1,
          \ 0, -1
          \ )
  else
    call prop_add(s:pum.cursor, 1, {
          \ 'length': s:pum.width,
          \ 'type': 'pum_cursor',
          \ 'bufnr': s:pum.buf,
          \ })
  endif

  call s:redraw()

  return ''
endfunction

function! pum#insert_relative(delta) abort
  let prev_word = s:pum.cursor > 0 ?
        \ s:pum.items[s:pum.cursor - 1].word :
        \ s:pum.orig_input

  call pum#select_relative(a:delta)
  if s:pum.cursor < 0 || s:pum.id <= 0
    return ''
  endif

  call s:insert_current_word(prev_word)
  return ''
endfunction

function! pum#confirm() abort
  if s:pum.cursor > 0 && s:pum.current_word ==# ''
    call s:insert_current_word(s:pum.orig_input)
  endif
  call pum#close()
  return ''
endfunction

function! pum#cancel() abort
  if s:pum.cursor > 0 && s:pum.current_word !=# ''
    call s:insert(s:pum.orig_input, s:pum.current_word)
  endif
  call pum#close()
  return ''
endfunction

function! pum#visible() abort
  return s:pum.id > 0
endfunction
function! pum#complete_info() abort
  return {
        \ 'mode': '',
        \ 'pumvisible': pum#visible(),
        \ 'items': s:pum.items,
        \ 'selected': s:pum.cursor - 1,
        \ 'inserted': s:pum.current_word,
        \ }
endfunction

function! s:insert(word, prev_word) abort
  " Convert to 0 origin
  let startcol = s:pum.startcol - 1
  let prev_input = startcol == 0 ? '' : s:getline()[: startcol - 1]
  let next_input = s:getline()[startcol :][len(a:prev_word):]

  call s:setline(prev_input . a:word . next_input)
  call s:cursor(s:pum.startcol + len(a:word))

  let s:pum.current_word = a:word

  " Note: The text changes fires TextChanged events.  It must be ignored.
  let g:pum#skip_next_complete = v:true
endfunction
function! s:insert_current_word(prev_word) abort
  let word = s:pum.cursor > 0 ?
        \ s:pum.items[s:pum.cursor - 1].word :
        \ s:pum.orig_input
  call s:insert(word, a:prev_word)
endfunction

function! s:getline() abort
  return mode() ==# 'c' ? getcmdline() : getline('.')
endfunction
function! s:col() abort
  return mode() ==# 'c' ? getcmdpos() : col('.')
endfunction
function! s:cursor(col) abort
  return mode() ==# 'c' ? setcmdpos(a:col) : cursor(0, a:col)
endfunction
function! s:setline(text) abort
  if mode() ==# 'c'
    " setcmdline() is not exists...

    " Clear cmdline
    let chars = "\<C-e>\<C-u>"

    " Note: for control chars
    let chars .= join(map(split(a:text, '\zs'),
          \ { _, val -> val <# ' ' ? "\<C-q>" . val : val }), '')

    call feedkeys(chars, 'n')
  else
    " Note: ":undojoin" is needed to prevent undo breakage
    undojoin | call setline('.', a:text)
  endif
endfunction
function! s:redraw() abort
  " Note: :redraw is needed for command line completion in neovim or Vim
  if mode() ==# 'c' || !has('nvim')
    redraw
  endif
endfunction

function! s:print_error(string) abort
  echohl Error
  echomsg printf('[pum] %s', type(a:string) ==# v:t_string ?
        \ a:string : string(a:string))
  echohl None
endfunction
