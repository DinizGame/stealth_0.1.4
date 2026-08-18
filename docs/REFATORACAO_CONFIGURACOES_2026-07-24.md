# Refatoração do sistema de configurações — 24/07/2026

## Objetivo

Separar responsabilidades do antigo `AutoConfig.gd` sem quebrar a interface pública utilizada pelas cenas existentes.

## Estrutura criada

- `ScriptGlobais/AutoConfig.gd`: fachada e orquestrador.
- `ScriptGlobais/settings/config_storage.gd`: leitura e escrita de CFG/JSON.
- `ScriptGlobais/settings/video_settings.gd`: resolução, janela e temas.
- `ScriptGlobais/settings/audio_settings.gd`: volumes e aplicação nos buses.
- `ScriptGlobais/settings/language_settings.gd`: idioma e TranslationServer.
- `ScriptGlobais/settings/input_settings.gd`: persistência, migração, snapshots e restauração de inputs.
- `ScriptGlobais/settings/input_icon_resolver.gd`: resolução centralizada de ícones.

## Mudanças funcionais

1. O menu de opções agora trabalha de forma transacional:
   - abrir opções cria snapshot;
   - editar altera apenas memória;
   - salvar confirma e grava;
   - sair sem salvar restaura o snapshot.
2. Os inputs deixam de ser gravados a cada remapeamento.
3. O arquivo padrão continua imutável em `res://Config/InputMapPadrao.json`.
4. O arquivo do usuário passa a usar `PC` e `JOYPAD`.
5. Arquivos antigos com `XBOX` e `PLAYSTATION` são migrados automaticamente.
6. Botões e eixos são armazenados com tipos explícitos, eliminando ambiguidade entre RB e LT.
7. A restauração individual de input usa o módulo central, sem ler JSON em cada linha da UI.
8. Xbox e PlayStation continuam separados apenas na camada de ícones.
9. Os índices físicos de RB/LB foram normalizados para RB = 10 e LB = 9.
10. Resolução maior que o monitor abre em janela reduzida e centralizada.
11. O áudio é aplicado imediatamente durante a edição e restaurado ao cancelar.

## Compatibilidade

A interface pública principal do `AutoConfig` foi mantida para reduzir quebras em cenas existentes. Novas alterações devem preferir os métodos:

- `set_resolution_multiplier()`
- `set_fullscreen()`
- `set_idioma()`
- `set_tipo_controle()`
- `iniciar_edicao()`
- `confirmar_edicao()`
- `cancelar_edicoes_sem_salvar()`
- `restaurar_padrao_em_memoria()`

## Testes manuais recomendados

- Apagar `user://user_local.cfg` e `user://inputs.json` e iniciar o jogo.
- Alterar vídeo, áudio, idioma e input; cancelar; confirmar restauração.
- Alterar vídeo, áudio, idioma e input; salvar; reiniciar o jogo.
- Restaurar apenas uma tecla, um botão e um gatilho.
- Restaurar todas as configurações e depois cancelar.
- Abrir arquivo antigo de inputs com chaves `XBOX`/`PLAYSTATION`.
- Testar janela em resolução maior que a área útil do monitor.
