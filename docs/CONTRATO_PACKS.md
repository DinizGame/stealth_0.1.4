# Contrato de Packs Extras

O Stealth deve conhecer um pack apenas pelo manifesto carregado em `res://mods/extras/`. Não crie referências diretas do projeto principal para arquivos internos de `res://packs/<pack>/`.

## Inicialização

1. `LoadPack` monta os `.pck`.
2. `mod_loader.gd` lê os manifestos disponíveis.
3. `base_panel_extra.tscn` valida `requires.input_actions` e `requires.autoloads`, quando declarados.
4. Antes de trocar de cena, o host grava `SceneTree` metadata `extras_return_scene` com a cena atual.
5. A cena indicada por `next_scene` é aberta.

## Retorno

O pack não deve conhecer o caminho do menu do Stealth. Ele lê `extras_return_scene`, fornecido pelo host, e retorna para essa cena. Assim mudanças de pastas ou cenas no Stealth não obrigam editar o pack.

## Regra de dependência

- Host -> pack: somente manifesto e `next_scene`.
- Pack -> host: somente contratos declarados no manifesto e a metadata de retorno.
- Recursos internos, sinais e sistemas do pack devem permanecer dentro do próprio pack.
- InputMap é propriedade do host durante execução; o `project.godot` de cada pack mantém apenas um mapa de desenvolvimento com os mesmos nomes de ações exigidos.
