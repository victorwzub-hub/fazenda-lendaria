# 🌾 Fazenda Lendária

Jogo de Roblox de fazenda e exploração: você entra em **rotas**, coleta materiais, abre **ninhos** que dão animais com raridade sorteada e **evolui** cada animal de Comum até **Lendário** e **Mítico**. Cada animal produz moedas por segundo (até com você offline), e as moedas liberam rotas novas, melhorias e mais espaço na fazenda.

## Como abrir no Roblox Studio (jeito mais fácil)

1. Baixe o arquivo **`FazendaLendaria.rbxlx`** deste repositório.
2. Dê dois cliques nele (ou, no Studio, **File → Open from File**).
3. Aperte **Play** (F5). O mapa inteiro é gerado por código quando o jogo roda, então no modo de edição a cena aparece vazia. Isso é normal.

### Para o progresso salvar
Publique o jogo (**File → Publish to Roblox**), vá em **Game Settings → Security** e ligue **Enable Studio Access to API Services**. Sem isso o jogo funciona, mas avisa que o progresso não será salvo.

### Configurações recomendadas
- **Game Settings → Places → Max Players: 8** (o mapa tem 8 lotes de fazenda).
- **Game Settings → Avatar**: R15 ou R6, tanto faz.

## Como o jogo funciona

| Sistema | O que faz |
|---|---|
| 🗺️ **Rotas** | 4 ilhas: Galinheiro (grátis), Chiqueiro, Pasto e Pradaria. Cada rota exige um animal da rota anterior numa raridade mínima, mais moedas. |
| 🌱 **Materiais** | Cada rota tem 3 materiais (comum, incomum, raro brilhante) e o ultra-raro 💎 Cristal Estelar. |
| 🥚 **Ninhos** | Dão um animal da rota com raridade sorteada. A sorte aumenta a chance de raridades altas e de ✨ Brilhante (3x moedas). |
| ⬆️ **Evolução** | Materiais + moedas sobem a raridade: Comum → Incomum → Rara → Épica → Lendária → Mítica. |
| 🪙 **Produção** | Cada animal rende moedas por segundo. Offline rende 50%, por até 8h. |
| 🌟 **Hora Dourada** | A cada 12 min, por 2 min: sorte x2 e itens raros aparecem 3x mais. |
| 📖 **Índice** | Coleção de todas as espécies e raridades. |
| 🛒 **Loja** | Melhorias (Sorte, Fazenda Maior, Botas Rápidas) e passes premium. |

Quando alguém consegue um Lendário ou Mítico, o servidor inteiro recebe o anúncio.

## Passes premium (monetização)

Os passes já estão programados, mas aparecem como "Em breve" até você criar e colar os IDs:

1. No [Creator Hub](https://create.roblox.com/dashboard/creations), abra o jogo → **Monetization → Passes** e crie os passes **VIP** (2x moedas), **Sorte Dupla** (2x sorte) e **Fazenda Gigante** (+10 espaços).
2. Copie o ID de cada passe para `src/shared/Config/GamePasses.luau` (campo `id`).
3. Gere o arquivo de novo (veja abaixo) ou edite o ModuleScript `ReplicatedStorage.Shared.Config.GamePasses` direto no Studio.

## Balanceamento

Todos os números ficam em arquivos de configuração fáceis de mexer:

- `src/shared/Config/Species.luau`: espécies, moedas/s de cada uma, materiais de evolução.
- `src/shared/Config/Rarities.luau`: multiplicador e chance de cada raridade.
- `src/shared/Config/Routes.luau`: rotas, requisitos, preço, chance de cada item.
- `src/shared/Config/Upgrades.luau`: melhorias da loja.
- `src/shared/Balance.luau`: custos de evolução, sorte, ganhos offline, venda.

Para adicionar um animal novo (ex.: 🐑 Ovelha): crie os materiais em `Materials.luau`, a espécie em `Species.luau` (com um `shape` existente ou novo em `AnimalModel.luau`) e a rota em `Routes.luau`.

## Estrutura do código

```
src/
├── shared/                  → ReplicatedStorage.Shared (servidor + cliente)
│   ├── Config/              números e conteúdo do jogo
│   ├── Balance.luau         regras de economia
│   ├── AnimalModel.luau     monta os animais 3D por código
│   ├── Format.luau          1.2K, 3.4M, tempo
│   └── Remotes.luau         comunicação cliente ↔ servidor
├── server/                  → ServerScriptService.Server
│   ├── init.server.luau     inicialização e entrada/saída de jogadores
│   └── Services/
│       ├── MapBuilder       gera o mapa (centro, 8 lotes, portais, 4 ilhas)
│       ├── DataService      salvamento (DataStore) e moedas
│       ├── FarmService      lotes, animais andando, produção, evolução, venda
│       ├── RouteService     pontos de coleta, ninhos, portais, Hora Dourada
│       ├── ActionService    valida as ações pedidas pelo cliente
│       └── PassService      passes premium
└── client/                  → StarterPlayerScripts.Client
    ├── State.luau           dados do jogador no cliente
    ├── World.luau           placas dos portais e efeito da Hora Dourada
    └── UI/                  HUD, menus (Animais, Rotas, Loja, Índice, Mochila), avisos
```

Toda ação importante (evoluir, vender, comprar, viajar, coletar) é validada no servidor, então exploits no cliente não conseguem dar moedas ou itens.

## Desenvolvendo com código (opcional)

**Opção 1: gerar o `.rbxlx` de novo.** Com [Node.js](https://nodejs.org) instalado:

```bash
node tools/build-place.mjs
```

**Opção 2: Rojo (sincronização ao vivo com o Studio).** Instale o [Rojo](https://rojo.space) e o plugin dele no Studio, depois:

```bash
rojo serve
```

No Studio, abra o plugin do Rojo e clique em **Connect**. Qualquer mudança nos arquivos `.luau` aparece no Studio na hora.
