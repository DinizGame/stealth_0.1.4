# Perfis de customização

## Fluxo da interface

- `Novo Perfil` aparece sempre no primeiro item de `base_save.tscn`.
- Selecionar um perfil existente carrega os itens e parâmetros registrados no disco.
- O botão de restaurar recarrega o perfil selecionado do disco.
- Salvar um perfil existente sobrescreve esse perfil.
- Salvar com `Novo Perfil` selecionado abre `popup_nome_save.tscn`.
- Ao sair com alterações pendentes, `popup_alerta_geral.tscn` permite continuar editando ou sair sem salvar.
- Sair da tela nunca abre o popup de nome e nunca obriga a criação de um perfil.

## Arquivos gerados

```text
user://profiles/body_bakes/<profile_id>/
├── profile.json
├── body_color.png
└── body_roughness.png
```

O JSON contém os IDs dos itens e os valores dos parâmetros editáveis. Os PNGs são o resultado do bake para uso posterior na gameplay.
