# ItemMeshCustomizavel — uso real

## Resposta direta

Não é necessário criar ou anexar um script diferente para cada mesh.

Cada item utiliza:

1. a cena normal da mesh (`.scn` ou `.tscn`);
2. um recurso de dados `ItemMeshCustomizavel` (`.tres`) ao lado dela.

Exemplo já configurado:

```text
assets/player/meshs/MeshBase/Body/
├── body_skin.scn
└── body_skin_customizavel.tres
```

O painel procura os arquivos `.tres`. Ele não adiciona mais todo arquivo `.scn`
encontrado na pasta.

## Criando um novo item no Inspector

1. No FileSystem, clique com o botão direito na pasta da mesh.
2. Selecione **New Resource**.
3. Escolha **ItemMeshCustomizavel**.
4. Salve, por exemplo, como `traje_2_customizavel.tres`.
5. Preencha:
   - `id`: identificador permanente do save;
   - `titulo`: nome mostrado na interface;
   - `slot`: local ocupado no personagem;
   - `cena`: a cena real da mesh;
   - `recebe_bake_cor` e `recebe_bake_roughness`, quando necessário.
6. Em `parametros`, adicione elementos do tipo `ParametroShaderEditavel`.
7. Em cada parâmetro, informe:
   - `id`: chave permanente do JSON;
   - `titulo`: nome visível;
   - `aba`: aba em que aparecerá;
   - `shader_parameter`: uniform exato do shader;
   - `tipo_controle`: Float, Color ou Texture;
   - `alvo_material`: material da mesh, bake de cor ou bake de roughness;
   - range, step ou pasta de opções, quando aplicável.

## Responsabilidades

### O recurso do item informa

- quem ele é;
- qual slot ocupa;
- qual cena deve ser instanciada;
- quais parâmetros podem aparecer no editor;
- qual material recebe cada parâmetro.

### O panel_edicao.gd coordena

- descoberta dos recursos do catálogo;
- preenchimento dos seletores;
- solicitação de instalação ou remoção;
- criação da interface declarada pelo item.

### O GerenteItensCustomizacao executa

- validação do slot;
- remoção do item anterior;
- conflitos entre roupas;
- instanciação da cena;
- duplicação dos materiais;
- aplicação dos bakes.

## Critério de entrada

Uma cena `.scn` isolada não aparece mais no seletor. Para entrar no editor ela
precisa possuir um `ItemMeshCustomizavel.tres` válido apontando para ela.
