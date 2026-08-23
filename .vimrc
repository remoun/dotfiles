set nocompatible        " Don't emulate vi
filetype off            " required

set rtp+=/opt/homebrew/opt/fzf

function! _setupVundle()
  " set the runtime path to include Vundle and initialize
  set rtp+=~/.vim/bundle/Vundle.vim
  call vundle#begin()

  " let Vundle manage Vundle, required
  Plugin 'VundleVim/Vundle.vim'

  " Git integration
  Plugin 'git.zip'
  Plugin 'fugitive.vim'
  " Peek into buffers with ", @, Ctrl-R
  Plugin 'junegunn/vim-peekaboo'
  " YCM: Powerful completion engine.
  Plugin 'ycm-core/YouCompleteMe'
  " Asynchronous Lint Engine
  Plugin 'dense-analysis/ale'

  " Enable rust-analyzer with ALE
  let g:ale_linters = {'rust': ['analyzer']}
endfunction


syntax enable           " enable syntax processing

set mouse=a             " enable mouse support (might not work well on Mac OS X)
set number              " show line numbers
set showcmd             " show command in bottom bar
set cursorline          " highlight current line
filetype indent on      " load filetype-specific indent files
set wildmenu            " visual autocomplete for command menu
set lazyredraw          " redraw only when we need to.
set showmatch           " highlight matching [{()}]
set autoindent          " copy indent from current line when starting a new line
set smartindent         " even better autoindent (e.g. add indent after '{')

set ts=4                " render tabs as 4 spaces
set et                  " expand tabs into spaces by default.

" Use semi-colon to start a command.
noremap ; :
" jk is escape
inoremap jk <esc>
" Tab to jump around windows
map <Tab> <C-W>w

set list
set listchars=tab:→\ ,nbsp:␣,trail:•,extends:⟩,precedes:⟨

" Searching
set ignorecase          " case-insensitive matching
set smartcase
set incsearch           " search as characters are entered
set hlsearch            " highlight matches

" Leader Shortcuts
let mapleader=","       " leader is comma

" Backups
set backup
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set backupskip=/tmp/*,/private/tmp/*
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set writebackup

" Undo
set undofile " Maintain undo history between sessions
set undodir=~/.vim/undodir

" Append modeline after last line in buffer.
" Use substitute() instead of printf() to handle '%%s' modeline in LaTeX
" files.
function! AppendModeline()
  let l:modeline = printf(" vim: set ts=%d sw=%d tw=%d %set :",
        \ &tabstop, &shiftwidth, &textwidth, &expandtab ? '' : 'no')
  let l:modeline = substitute(&commentstring, "%s", l:modeline, "")
  call append(line("$"), l:modeline)
endfunction
nnoremap <silent> <Leader>ml :call AppendModeline()<CR>

