# exo.nvim

Run external commands and show the output in a throwaway buffer.

- Inspired by [vim-shout](https://github.com/habamax/vim-shout)
- Automatically uses [bufix.nvim](https://github.com/msaher/bufix.nvim) if available.

# Installation

Use your favorite plugin manager

```lua
vim.pack.add{
  { src = 'https://github.com/msaher/exo.nvim' },
}
```

# Usage

See full documentation in `:h exo`.

Run an external command

```
:Exo <args>
```

Run a command interactively (remembers history)

```
:ExoPrompt
```

Use the built in `:cgetbuffer` to send the output to the quick fix list.

exo uses a normal buffer. You can modify the output as any other buffer.
