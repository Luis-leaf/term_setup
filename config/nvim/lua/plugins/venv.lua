return {
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      -- Procura .venv e venv na raiz do projeto
      name = { ".venv", "venv" },

      -- Atalhos úteis
      -- :VenvSelect  e  :VenvSelectCached
      notify_user_on_venv_activation = true,

      -- Tenta selecionar automaticamente ao entrar no projeto
      auto_refresh = true,
    },
    keys = {
      { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Selecionar venv" },
      { "<leader>vc", "<cmd>VenvSelectCached<cr>", desc = "Selecionar venv (cache)" },
    },
  },
}
