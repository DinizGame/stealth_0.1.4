# Configurações independentes por seção

## Implementado

- Cada cena de opção inicia e controla sua própria seção.
- Jogo/idioma, gráficos, áudio e inputs possuem botões locais de salvar e restaurar padrão.
- Salvar uma seção atualiza apenas seu arquivo/chaves e seu snapshot.
- Restaurar uma seção aplica apenas os padrões daquela seção e não salva automaticamente.
- O menu principal mantém as ações globais de restaurar tudo e salvar/sair.
- Ao sair com pendências, o popup lista somente as seções não salvas.
- O popup oferece: cancelar, sair sem salvar e salvar tudo.
- A API aceita filtros de seção para futuros ambientes, como o menu de pausa.

## Uso em outros ambientes

Ao instanciar apenas uma aba, ela continua independente. O gerenciador daquele ambiente pode consultar:

```gdscript
AutoConfig.tem_alteracoes_pendentes([AutoConfig.SecaoConfig.AUDIO])
```

e descartar somente essa seção com:

```gdscript
await AutoConfig.descartar_secao(AutoConfig.SecaoConfig.AUDIO)
```
