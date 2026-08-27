return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        functions = {},
        variables = {},
      },
      on_colors = function(colors)
        -- fundo mais preto (menos azul)
        colors.bg = "#0b0e14"
        colors.bg_dark = "#090b10"
      end,
    },
  },
}
