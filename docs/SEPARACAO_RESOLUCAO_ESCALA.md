# Separação entre resolução e escala da interface

## O que mudou

A configuração de vídeo agora possui dois valores independentes:

- **Resolução da janela:** 1280×720, 1920×1080, 2560×1440 ou 3840×2160.
- **Escala da interface:** 75%, 100%, 125% ou 150%.

A interface continua usando **1280×720 como tamanho-base de desenvolvimento**. Alterar a resolução não troca mais o tema nem multiplica manualmente fontes e ícones.

## Fluxo atual

```text
OptionResolution
    -> AutoConfig.set_resolution_multiplier()
    -> VideoSettings.resolution_multiplier
    -> altera somente o tamanho físico da janela

OptionInterfaceScale
    -> AutoConfig.set_interface_scale()
    -> VideoSettings.interface_scale_index
    -> altera Window.content_scale_factor
```

O `AutoConfig` continua sendo a única entrada pública. A implementação permanece concentrada em `video_settings.gd`.

## Arquivos principais

- `ScriptGlobais/settings/video_settings.gd`
  - guarda resolução e escala separadamente;
  - aplica a resolução física da janela;
  - aplica a escala uniforme da interface;
  - salva e restaura os dois valores no snapshot.

- `ScriptGlobais/AutoConfig.gd`
  - expõe `interface_scale_index`;
  - possui `set_interface_scale(index)`;
  - reutiliza os sinais de vídeo já existentes.

- `UI_ASSETS/script/graphic_options.gd`
  - controla os dois `OptionButton` de forma independente.

- `Config/default.cfg`
  - usa `interface_scale_index=1`, correspondente a 100%.

## Compatibilidade

O nome `resolution_multiplier` foi mantido para não quebrar cenas antigas, mas agora ele representa somente o **índice da resolução**.

Arquivos de usuário antigos continuam funcionando. Quando `interface_scale_index` não existir, o sistema usa automaticamente o índice `1`, ou seja, **100%**.

Os temas de 1080p, 1440p e 2160p foram preservados no projeto para facilitar comparação ou reversão, mas o fluxo atual utiliza somente o tema-base de 720p e deixa o `Window` escalar a interface uniformemente.

## Tela cheia

Em tela cheia, a janela ocupa a resolução nativa do monitor. A resolução selecionada fica guardada e volta a ser aplicada quando o jogo retorna ao modo janela. A escala da interface continua funcionando nos dois modos.

## Testes manuais recomendados

1. Em modo janela, testar cada resolução com escala em 100%.
2. Manter a resolução fixa e testar 75%, 100%, 125% e 150%.
3. Alternar entre tela cheia e modo janela.
4. Salvar, reiniciar o projeto e confirmar os dois valores.
5. Alterar ambos, escolher sair sem salvar e confirmar a restauração.
6. Restaurar somente a seção de vídeo para o padrão.
7. Verificar o menu principal, opções, popups e ícones de inputs em cada escala.
