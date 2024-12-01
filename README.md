# nirc
nirc is a rudimentary IRC client written as a plugin for neovim.

## Installation
Use your favorite plugin manager to install nirc. For example, using lazy.nvim:
```lua
{
  'boredcoder411/nirc',
  config = function()
    require'nirc'.setup({
        password = 'password', -- optional
        nickname = 'nirc',
        username = 'nirc',
        realname = 'nirc'
    })
  end
}
```
