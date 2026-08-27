local set = vim.api.nvim_set_hl

-- =========================
-- Python: alto contraste
-- =========================

-- Keywords gerais (if/for/while/try/with/async/await etc.)
set(0, "@keyword.python", { fg = "#bb9af7", bold = true }) -- roxo forte
set(0, "@keyword.operator.python", { fg = "#bb9af7", bold = true })

-- 'def' e 'class' separados e bem chamativos
set(0, "@keyword.function.python", { fg = "#f7768e", bold = true }) -- rosa (DEF)
set(0, "@keyword.type.python", { fg = "#f7768e", bold = true }) -- CLASS

-- return / raise / yield com cor própria
set(0, "@keyword.return.python", { fg = "#ff9e64", bold = true })
set(0, "@keyword.exception.python", { fg = "#ff9e64", bold = true })

-- Nome de função: verde vivo (bem diferente do 'def')
set(0, "@function.python", { fg = "#9ece6a", bold = true })
set(0, "@function.call.python", { fg = "#9ece6a" })

-- Classes / tipos: amarelo/laranja (bem separado do resto)
set(0, "@type.python", { fg = "#e0af68", bold = true })
set(0, "@constructor.python", { fg = "#e0af68", bold = true })

-- Decorators (@app.get): ciano bem visível
set(0, "@attribute.python", { fg = "#2ac3de", bold = true })

-- Parâmetros: lilás (diferente de variável normal)
set(0, "@parameter.python", { fg = "#9d7cd8", italic = true })

-- Variáveis: neutro claro
set(0, "@variable.python", { fg = "#c0caf5" })

-- Builtins/constantes (None/True/False): teal
set(0, "@constant.builtin.python", { fg = "#4fd6be", bold = true })
set(0, "@boolean.python", { fg = "#4fd6be", bold = true })

-- Números: laranja
set(0, "@number.python", { fg = "#ff9e64" })

-- Comentários: mais legíveis
set(0, "@comment.python", { fg = "#565f89", italic = true })
