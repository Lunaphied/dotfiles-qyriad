scriptencoding utf-8

syntax on
filetype plugin indent on

runtime ftplugin/man.vim

" Options
set number " Show line numbers
set modeline " Allow vim commands in text file comments
set undofile " Persistent undo tree
set incsearch " Incremental search
set tabstop=4 " Number of visual spaces to be displayed per HT
set noexpandtab " Don't 'expand' tabs to spaces
set shiftwidth=0 " Use tabstop value for indenting
set showcmd " Show the last command on the command line
set lazyredraw " Only redraw when we need to
set scrolloff=8 " Keep 8 lines between the end of the buffer and the cursor
set sidescrolloff=2 " Keep 2 characters between the current column and the screen edge
set mouse=n " Enable the mouse in normal mode
set colorcolumn=120 " It's typically good to keep lines of code under 120 characters
set textwidth=120 " ""
set wildmenu " Autocomplete command menu
set wildmode=longest:full,full " Most bash-like way
set wildignorecase
set cursorcolumn " Highlight the column the cursor is on
set cursorline " Highlight the line the cursor is on
set timeoutlen=1000 ttimeoutlen=10 " Remove <Esc> leaving insert mode delay
set noshowmode " We're using lightline, so showing the mode in the command line is redundant
set splitright " Make :vsplit put the new window on the right
set splitbelow " Same as above, but on the bottom with horizontal splis
"set foldlevel=1 " Usually collapse to function definitions in classes, not the classes themselves
set foldlevel=5
set hidden " Allow for hidden, modified but not written buffers
set bufhidden=hide " Hide buffers instead of deleting or unloading them
set ignorecase
set smartcase
set gdefault " Substitute all matches in a line by default
set cindent
set cinoptions=1l,j1 " Indent case blocks correctly; indent Java anonymous classes correctly
" Don't display . on folds
set fillchars=fold:\ 

let g:vimsyn_folding = 'aflmpPrt'

" Completion
set completeopt=menu,menuone,preview,noselect,noinsert
inoremap <expr> <Esc> pumvisible() ? "\<C-e>" : "\<Esc>"
inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<CR>"
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent><expr> <C-Space> deoplete#mappings#manual_complete()
"let g:ale_completion_enabled = 1
let g:LanguageClient_serverCommands = { 'rust': ['rustup', 'run', 'nightly', 'rls'] }
let g:deoplete#enable_at_startup = 1

" use fuzzy YCM-style matching
augroup deoplete_source
	autocmd! VimEnter * call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy'])
augroup END

" Linting
let g:c_space_errors = 1
let g:python_space_error_highlight = 1
let g:ale_c_parse_compile_commands = 1
let g:ale_linters = {'c': ['ccls', 'clang'], 'rust': ['rls', 'cargo']}
let g:ale_c_ccls_init_options = {'clang': {'extraArgs': ['-isystem', '/usr/include'] } }
let g:LanguageClient_diagnosticsEnable = 0

" Other LSP
nnoremap <Return> :ALEHover<CR>
nnoremap <A-Return> :ALEGoToDefinition<CR>
nnoremap <leader><A-CR> :ALEGoToDefinitionInTab<C-b><Space><Left>
function! Ale_hover()
	let hover_s = ale#hover#Show(bufnr(''), getcurpos()[1], getcurpos()[2], {})
	sleep 2
endfunction

" Lightline helper functions
function! SyntaxItem()
	let synid = synID(line('.'), col('.'), 1)
	let trans = synIDtrans(synid)
	return synIDattr(synid, 'name') . ' | ' . synIDattr(trans, 'name') . ' | ' . synIDattr(trans, 'fg')
endfunction

function! SyntaxColor()
	highlight SyntaxItem()
endfunction

function! HomeRelDir()
	let l:dir = fnamemodify(expand('%:p:h'), ':~:.')
	if l:dir ==? substitute(getcwd(), $HOME, '~', 'e')
		return ''
	else
		return l:dir
	endif
endfunction

function! LightlineReload()
	call lightline#init()
	call lightline#colorscheme()
	call lightline#update()
endfunction

command! LightlineReload call LightlineReload()


" Mapping helper functions
function! BufSel(pattern)
	let bufcount = bufnr('$')
	let currbufnr = 1
	let nummatches = 0
	let firstmatchingbufnr = 0
	while currbufnr <= bufcount
		if(bufexists(currbufnr))
			let currbufname = bufname(currbufnr)
			if(match(currbufname, a:pattern) > -1)
				echo currbufnr . ': ' . bufname(currbufnr)
				let nummatches += 1
				let firstmatchingbufnr = currbufnr
			endif
		endif
		let currbufnr = currbufnr + 1
	endwhile
	if(nummatches == 1)
		execute ':buffer ' . firstmatchingbufnr
	elseif(nummatches > 1)
		let desiredbufnr = input('Enter buffer number: ')
		if(strlen(desiredbufnr) != 0)
			execute ':buffer ' . desiredbufnr
		endif
	else
		echo 'No matching buffers'
	endif
endfunction

command! -nargs=1 Bs :call BufSel('<args>')

" Color customization

" Make the highlight color for the colorcolumn not obnoxious, but still stand out
highlight ColorColumn ctermbg=236 guibg=#303030
" Make the highlight color for the current column not obnoxious, but still stand out a bit less than above
highlight CursorColumn ctermbg=234 guibg=#1c1c1c
" Make the highlight color for the current row not obnoxious and not underlined
highlight CursorLine ctermbg=234 cterm=NONE guibg=#1c1c1c
" Also bold the line number
highlight CursorLineNr cterm=bold gui=bold guifg=#af5f00
" Make the folded text color not suck
highlight Folded ctermbg=17

" Make the completion menu look not ungodly
highlight Pmenu guibg=#303030 guifg=#5a95f4

" Enable truecolors
set termguicolors
" Reset to term colors
highlight Statement guifg=#af5f00
highlight Comment guifg=#0aa6da
highlight PreProc guifg=#c397d8
highlight Identifier guifg=#70c0ba
highlight Constant guifg=#cf0002
highlight Type guifg=#00cc00
highlight Special guifg=#c397d8
highlight LineNr gui=none guifg=#af5f00

" Actually be able to see searched stuff
"highlight Search guibg=#a0a0a0
highlight Search guibg=#5c5c5c guifg=#ffffff gui=NONE

command! Hitest :source $VIMRUNTIME/syntax/hitest.vim

" Autocommands
augroup insert_nohlsearch
	autocmd! InsertEnter * set nohlsearch
augroup END

function! Init_menu_items() abort
	"let l:tagl = taglist('.', 'init.vim')
	let l:tagl = {
	\ 'Options': {-> execute('tag options')},
	\ 'Completion': {-> execute('tag completion')},
	\ 'Linting': {-> execute('tag linting')},
	\ 'Other LSP': {-> execute('tag other-lsp')},
	\ 'Lightline helper functions': {-> execute('tag lightline-helper-functions')},
	\ 'Mapping helper functions': {-> execute('tag mapping-helper-functions')},
	\ 'Color customization': {-> execute('tag color-customization')},
	\ 'Autocommands': {-> execute('tag autocommands')},
	\ 'Mappings': {-> execute('tag mappings')},
	\ 'Lightline': {-> execute('tag lightline')},
	\ 'vim-plug': {-> execute('tag vim-plug')},
	\}

	return l:tagl
endfunction

function! Init_menu_handle(item) abort
	let l:items = Init_menu_items()
	execute 'redraw'
	return call(l:items[a:item], [])
endfunction

function! Init_menu() abort
	let l:options = keys(Init_menu_items())

	return fzf#run(fzf#wrap({'source': l:options, 'sink': function('Init_menu_handle'), }))
endfunction

augroup init_mapping
	autocmd! BufReadPre init.vim nnoremap <buffer> <leader><leader> :call Init_menu()<CR>
augroup END

"augroup init_toc_ft
	"autocmd! BufWinEnter init-toc.txt filetype detect
"augroup END

"function! Init_toc_goto_tag()
	"let cw = expand("<cword>")
	"execute "normal \<C-w>h"
	"execute "tag " . cw
"endfunction

"function! Init_toc_helper()
	"vsplit ~/.config/nvim/init-toc.txt
	""setlocal filetype=help
	"" Start off in the tag column
	"normal w
	"" Remap goto-tag to use the existing window
	"nnoremap <buffer> <C-]> :call Init_toc_goto_tag()<CR>
	"" Switch back to init.vim
	"normal <C-w>h
	"setlocal filetype=vim
"endfunction

"augroup init_toc
	"autocmd! BufWinEnter init.vim call Init_toc_helper()
"augroup END

augroup fzf_quit
	autocmd! FileType fzf nnoremap <buffer> q :silent q<CR> | nnoremap <buffer> <Esc> :silent q<CR>
augroup EN

" Mappings

let mapleader="\\"

" Save my pinky
nnoremap ; :

" Have the indent commands re-highlight the last visual selection
vnoremap > >gv
vnoremap < <gv

" Go to the second to last character
vnoremap <leader>$ $h

" Stop highlighting last search with \/
nnoremap <leader>/ :nohlsearch<CR>

" gp to select pasted text
nnoremap gp `[v`]

" unmap Q
nnoremap Q <nop>

" Alt+Backspace to kill-word
inoremap <A-BS> <C-w>
cnoremap <A-BS> <C-w>

" Add newlines above and below without entering insert mode or moving the cursor
nnoremap <leader>o mso<Esc>`s
nnoremap <leader>O msO<Esc>`s

" Add newline at current position without entering insert mode or moving the cursor
nnoremap <leader><CR> msi<CR><Esc>`s

" Switch buffer
nnoremap <leader>sb :Bs<CR>

" Use escape to exit terminal mode
tnoremap <Esc> <C-\><C-n>

" Use line-wrapped movement by default, but specifying a count disables it
nnoremap <expr> j (v:count > 0 ? "m'" . v:count . 'j' : 'gj')
nnoremap <expr> k (v:count > 0 ? "m'" . v:count . 'k' : 'gk')

" \$ for third-to-last character
nnoremap <leader>$ $2h

" <A-CR> to insert and goto line above
inoremap <A-CR> <Esc>O

" Copy current command line
cnoremap <C-y> <C-f>Vy<C-c>

" Edit and source vimrc shortcuts
nnoremap <leader>ev :tabedit $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" Gstatus
nnoremap <leader>gs :tab Gstatus<CR>

" Statusline/lightline
set laststatus=2 " Always show statusline

" Lightline
let g:lightline =
\{
	\	'active': { 
	\		'left': [['mode', 'paste'], ['readonly', 'filename', 'modified']],
	\		'right': [[], ['dir', 'filetype', 'lineinfo', 'percent', 'fileencoding', 'fileformat'], ['syncolor', 'syn']]
	\	},
	\	'separator': { 'left': "\ue0b0", 'right': "\ue0b2" },
	\	'component_function': { 'syn': 'SyntaxItem', 'dir': 'HomeRelDir' },
	\	'tab': { 'active': ['tabnum', 'filename', 'modified'], 'inactive': ['tabnum', 'filename', 'modified'] }
\}

" vim-plug
if empty(glob('~/.config/nvim/autoload/plug.vim'))
	echomsg 'vim-plug not installed; downloading…'
	!curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
	augroup vim_plug
		autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
	augroup END
endif

call plug#begin('~/.config/nvim/plugged')
Plug 'itchyny/lightline.vim'
Plug 'chrisbra/colorizer'
Plug 'tmhedberg/SimpylFold'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-characterize'
Plug 'scrooloose/nerdcommenter'
Plug 'Konfekt/vim-alias'
Plug 'neoclide/jsonc.vim'
Plug 'leafgarland/typescript-vim'
Plug 'w0rp/ale'
Plug 'Shougo/deoplete.nvim'
Plug 'Shougo/neco-syntax'
Plug 'Shougo/neco-vim'
Plug 'autozimu/LanguageClient-neovim', { 'branch': 'next', 'do': 'bash install.sh' }
"Plug 'thinca/vim-ft-vim_fold'
call plug#end()

" vim:textwidth=0
