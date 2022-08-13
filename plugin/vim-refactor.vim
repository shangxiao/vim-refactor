if exists("g:loaded_vim_refactor")
    finish
endif
let g:loaded_vim_refactor = 1

let s:plugin_root_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')

python3 << EOF
import sys
from os.path import normpath, join
import vim
plugin_root_dir = vim.eval('s:plugin_root_dir')
python_root_dir = normpath(join(plugin_root_dir, '..', 'python'))
sys.path.insert(0, python_root_dir)
import refactor
EOF


" https://github.com/LucHermitte/lh-vim-lib/blob/master/autoload/lh/ui.vim#L52
function! GetCurrentWord()
  let c = col ('.')-1
  let l = line('.')
  let ll = getline(l)
  let ll1 = strpart(ll,0,c)
  let ll1 = matchstr(ll1,'\w*$')
  if strlen(ll1) == 0
    return ll1
  else
    let ll2 = strpart(ll,c,strlen(ll)-c+1)
    let ll2 = strpart(ll2,0,match(ll2,'$\|\W'))
    return ll1.ll2
  endif
endfunction


function! Cword()
    " <cword> will jump spaces to get the nearest word
    return matchstr(getline('.'), '\w*\%' . col('.') . 'v\w*')
endfunction

function! IsEOL()
    return col(".") == col("$")-1
endfunction


" http://candidtim.github.io/vim/2017/08/11/write-vim-plugin-in-python.html
" https://stackoverflow.com/questions/1803539/how-do-i-turn-on-search-highlighting-from-a-vim-script

function! FileOffset(qualifier)
    " charcol() or col()?  also how get the line2char() equivalent if not bytes?
    " this is wrt code with unicode chars in it
    return line2byte(line(a:qualifier)) + charcol(a:qualifier) - 1
endfunction

function! SearchAll(pattern)
    call setpos('.', [0, 0, 0, 0])
    let matches = []
    let curr_match = searchpos(a:pattern, 'W')
    while curr_match[0] > 0
        let matches = add(matches, curr_match)
        let curr_match = searchpos(a:pattern, 'W')
    endwhile
    return matches
endfunction

function! PreSub()
    let pos = getcurpos()
    let s:search_results = SearchAll('zzz')

    " Flag to indicate if we've finished subbing for reasons below
    let s:finished_subbing = 0

    " record the cursor position & line so that if we move away from the current keyword then finish subbing
    " The last pos is updated as we type out the keyword so track that while subbing
    let s:line = pos[1]
    let s:start_col = pos[2]
    let s:last_pos = pos[2]

    " set flag for first sub - used for turning off subbing if whitespace is typed - but ignore the first interaction which will be whitespace
    let s:first_sub = 1

    call setpos('.', pos)
endfunction

function! Sub()
    " No more subbing
    if s:finished_subbing
        return
    endif

    " Can't do anything if completion is active
    if pumvisible()
        return
    endif

    let pos = getcurpos()
    let word = GetCurrentWord()
    let char = getline('.')[col('.')-2]

    " If move away from keyword then finish subbing
    if pos[1] != s:line || pos[2] < s:start_col || pos[2] > s:last_pos + 1
        let s:finished_subbing = 1
        return
    endif

    if pos[2] > s:last_pos
        let s:last_pos = pos[2]
    endif

    " If type a space then finish subbing
    " Initial interaction word will be ''
    if s:first_sub == 0
        if word == ""
            let s:finished_subbing = 1
            return
        endif

        " If type any char that's non-word then finish subbing
        if match(char, '\w') == -1
            let s:finished_subbing = 1
            return
        endif
    endif
    let s:first_sub = 0

    for zpos in s:search_results
        let line = zpos[0]
        " let col = zpos[1] + len(word)
        let col = zpos[1]
        call setpos('.', [0, line, col, 0])
        " let curr_word = expand('<cword>')
        let curr_word = Cword()

        " Skip if completion, attempting to update buffer while completion is active will result in
        " an E565 error. pumvisible() is only useful if there is a popup menu, which won't appear
        " if there's only one option to complete

        try
            if curr_word == ""
                exec "normal! i".word."\<Esc>"
            elseif len(curr_word) == 1
                let is_eol = IsEOL()

                if is_eol
                    " x moves cursor backward if eol
                    exec "normal! xa".word."\<Esc>"
                else
                    exec "normal! xi".word."\<Esc>"
                endif
            else
                exec "normal! ce".word."\<Esc>"
            endif
        catch
            " can't even put back the current word?
            call setpos('.', pos)
            return
        endtry
    endfor

    " let new_word = "zzz" . word
    " %s/zzz\w*/\=new_word/ge
    call setpos('.', pos)
endfunction

function! Clean()
    " %s/zzz//ge
    " if finished on completion need to substitute a final time
    call Sub()
    au! * <buffer>
endfunction

function! Debug()
    debug call ExtractVariable()
endfunction

function! ExtractVariable()
    let start = FileOffset("'<") - 1
    let end = FileOffset("'>")
    let cwd = getcwd()

    python3 refactor.extract_variable()

    " let @/=expand('zzz')
    exec "normal" "gg0"
    call search("zzz")
    call matchadd('Search', "zzz")
    exec "normal" "de"
    " let &hls = 1
    " exec "normal" "^*"
    call PreSub()
    au TextChangedI <buffer> call Sub()
    au InsertLeave <buffer> call Clean()
    startinsert
endfunction

function! ExtractFunction()
    let start = FileOffset("'<") - 1
    let end = FileOffset("'>")
    let cwd = getcwd()

    python3 refactor.extract_function()

    exec "normal" "gg0"
    call search("zzz", "b")
    call matchadd('Search', "zzz")
    exec "normal" "de"
    call PreSub()
    au TextChangedI <buffer> call Sub()
    au InsertLeave <buffer> call Clean()
    startinsert
endfunction

function! Inline()
    let pos = getpos('.')
    let offset = FileOffset('.')
    let cwd = getcwd()

    python3 refactor.inline()

    " If we don't reset the cursor, it jumps back to top of file
    call setpos('.', pos)
endfunction
