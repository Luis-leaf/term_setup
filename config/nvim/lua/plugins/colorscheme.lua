return {
  {
    "tiagovla/tokyodark.nvim",
    opts = {
      -- suas configurações personalizadas aqui (opcional)
    },
    config = function(_, opts)
      require("tokyodark").setup(opts)
    end,
  },

  -- Configure o LazyVim para usar o TokyoDark
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyodark",
    },
  },
}
