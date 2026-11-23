# Compressor Dinâmico Adaptativo em Tempo Real

Código do Trabalho de Conclusão de Curso **"Desenvolvimento de um Sistema de
Compressão Dinâmica em Tempo Real Utilizando Processamento Digital de
Sinais"**, de Danilo Francisco Ropero Sivirino. Engenharia de Controle e
Automação, IFSP Câmpus Catanduva, 2026. Orientador: Prof. Dr. João Domingos
Augusto dos Santos Pereira.

---

## O que é

Um compressor digital de faixa dinâmica implementado como *plugin* de áudio
(VST3 e *Standalone*) em C++ sobre o *framework* JUCE 8, em três camadas:

1. **Núcleo de processamento.** Topologia *feedforward*, detector ramificado
   no domínio logarítmico, posicionado após o computador de ganho, e joelho
   quadrático (*soft knee*). É parametrizado por limiar, razão, largura do
   joelho, tempos de ataque e de liberação e ganho de compensação.
2. **Camada adaptativa.** Quatro mecanismos ajustam parâmetros em tempo real
   a partir de estatísticas do próprio sinal. Cada um pode ser ligado ou
   desligado. Com os quatro desligados, o sistema é exatamente o núcleo
   validado.
3. **Interface gráfica.** Mostra a curva estática, a redução de ganho, o
   registro temporal de entrada, saída e ganho, e um painel de telemetria
   com a métrica estimada ao lado do parâmetro que ela determina.

O desenvolvimento seguiu a ordem: o modelo matemático foi prototipado em
MATLAB e implementado em C++. A implementação foi confrontada amostra a
amostra com o protótipo. Por fim, a camada adaptativa e a interface foram
construídas sobre o núcleo validado.

Os códigos não são reproduzidos integralmente no corpo da monografia, por
recomendação da banca de qualificação. Estão aqui, versionados e executáveis.

---

## Estrutura do repositório

```
Compressor_Audio/
├── README.md
├── *.m                       scripts MATLAB (protótipo, ensaios e figuras)
├── NewProject/               projeto do plugin (JUCE / Projucer)
│   ├── *.jucer               descrição do projeto
│   └── Source/
│       ├── CompressorCore.h/.cpp          núcleo: os cinco passos do modelo
│       ├── AdaptiveController.h/.cpp      os quatro mecanismos adaptativos
│       ├── PluginProcessor.h/.cpp         parâmetros, processBlock, telemetria
│       ├── PluginEditor.h/.cpp            composição da janela, temporizador de 30 Hz
│       ├── CompressorComponents.h/.cpp    elementos de tela
│       ├── CompressorLookAndFeel.h/.cpp   cores, tipografia e desenho dos controles
│       ├── Benchmark.cpp                  medição de desempenho (programa à parte)
│       └── TesteAdaptativo.cpp            verificação rápida dos modos (programa à parte)
└── CompressorOffline/        ferramenta de linha de comando (JUCE, console)
    ├── *.jucer
    └── Source/
        └── Main.cpp
```

O `CompressorOffline` compila os mesmos `CompressorCore` e
`AdaptiveController` do *plugin* (inclui `../../NewProject/Source/`). Não há
cópia. Por isso, a equivalência entre o código validado e o código em
operação é garantida por construção.

As pastas `Builds/` e `JuceLibraryCode/` não são versionadas, porque o
Projucer as regenera a cada salvamento.

---

## Requisitos

- **MATLAB R2020a ou superior.** Não há *toolbox* adicional; tudo é MATLAB
  base. A exportação usa `exportgraphics`.
- **JUCE 8** com o Projucer.
- **Microsoft Visual Studio** (MSVC, 64 bits), no Windows.
- **DAW compatível com VST3** para uso do *plugin*. Os testes foram feitos
  no Ableton Live.

---

## Como compilar o plugin

1. Abra o arquivo `.jucer` de `NewProject/` no Projucer e confira o caminho
   dos módulos do JUCE.
2. Salve o projeto no Projucer. Isso regenera `Builds/` e
   `JuceLibraryCode/`. Sem salvar, o Visual Studio continua com a lista
   antiga de arquivos.
3. Abra a solução gerada em `Builds/VisualStudio20xx/` e compile em
   **Release x64**.
4. Copie o `.vst3` gerado para `C:\Program Files\Common Files\VST3` e
   peça à DAW para atualizar a lista de *plugins*.

O `CompressorOffline` é compilado da mesma forma, a partir do seu `.jucer`.
O `Benchmark.cpp` e o `TesteAdaptativo.cpp` não dependem do JUCE: as linhas
de compilação (`cl` ou `g++`) estão no cabeçalho de cada arquivo.

---

## CompressorOffline

Processa um arquivo WAV pelo mesmo núcleo do *plugin* e grava o resultado e
a telemetria.

```
CompressorOffline <entrada.wav> <saida.wav> [T R ataque release joelho makeup] [opções]
```

| Argumento | Significado | Padrão |
|---|---|---|
| `T` | limiar, dBFS | −12 |
| `R` | razão | 4 |
| `ataque` | constante de tempo, ms | 10 |
| `release` | constante de tempo, ms | 100 |
| `joelho` | largura, dB | 6 |
| `makeup` | ganho de compensação, dB | 6 |

Os seis parâmetros são opcionais: informe todos ou nenhum, nesta ordem.

| Opção | Efeito |
|---|---|
| `--adapt-threshold` | Modo 1: limiar pela média e desvio padrão |
| `--adapt-ratio` | Modo 2: razão pelo fator de crista |
| `--adapt-attack` | Modo 3: ataque pela derivada do envelope |
| `--auto-makeup` | Modo 4: compensação automática de ganho |
| `--adapt-all` | liga os quatro |
| `--bloco N` | amostras por bloco (padrão 512) |
| `--decimar N` | passo de gravação da telemetria (padrão 16) |

Os parâmetros manuais continuam valendo para os modos desligados.

O programa grava três arquivos:

- `<saida>.wav` com o áudio processado;
- `<saida>.csv` com as amostras de saída e o envelope de ganho;
- `<saida>_adapt.csv` com a telemetria dos estimadores e dos parâmetros.

---

## Scripts MATLAB

Coloque todos os `.m` na mesma pasta, abra o MATLAB nela e execute o script
desejado. Cada script salva o próprio PNG.

### Funções auxiliares (necessárias para os gráficos)

| Arquivo | Função |
|---|---|
| `virgula.m` | Troca o ponto decimal por vírgula nos rótulos dos eixos e congela a posição dos ticks, para que a exportação não os redistribua. Chamada por último em cada script. |
| `numvir.m` | Formata um número com vírgula decimal, para os textos dentro do gráfico. |
| `estilo_abnt.m` | Padronização de eixo para impressão: fundo branco, escrita preta, grade discreta. |

### Protótipo do modelo (Capítulo 6)

| Script | Produz |
|---|---|
| `bloco_base.m` | Implementação de referência: sinal de ensaio, laço de compressão amostra a amostra e métricas. Está embutido no topo de cada script de gráfico. |
| `g1_sinal_entrada.m` | Sinal de entrada, com *zoom* nos ciclos da senoide |
| `g2_sinal_saida.m` | Sinal de saída sobreposto à entrada, com *zoom* no transitório de ataque |
| `g3_envelope_ganho.m` | Envelope de ganho, com *zoom* no transitório de liberação |
| `g4_nivel_dBFS.m` | Nível de entrada contra nível de saída, em dBFS |
| `g5_curva_estatica.m` | Curva estática: sem compressão, *hard knee*, *soft knee* e limitador |
| `g6_metricas.m` | Painel de métricas e diagrama de polos no plano Z |
| `g7_resposta_degrau.m` | Resposta ao degrau dos filtros de ataque e de liberação |
| `g8_comparacao_knee.m` | Efeito da largura do joelho sobre a curva e sobre o sinal em regime |

### Validação da implementação em C++ (Capítulo 8)

| Script | Produz |
|---|---|
| `validacao_cruzada.m` | Comparação amostra a amostra entre protótipo e implementação |
| `acomodacao.m` | Evolução do envelope de ganho após a transição de nível |
| `metricas_dinamica.m` | Métricas de faixa dinâmica e sensibilidade à janela de guarda |
| `constantes_de_tempo.m` | Constantes de tempo medidas sob diferentes excitações |
| `gerar_sinais_curva.m` | Sinais em escada para a curva estática e a distorção harmônica |
| `curva_estatica.m` | Característica estática medida contra a prevista |
| `distorcao_harmonica.m` | Distorção harmônica total e composição espectral |
| `gerar_sinal_reff.m` | Senoide modulada em amplitude para o ensaio de razão efetiva |
| `ratio_efetiva.m` | Razão de compressão efetiva em função da frequência de modulação |

### Camada adaptativa (Capítulo 9)

| Script | Produz |
|---|---|
| `gerar_sinais_adaptativos.m` | Os quatro sinais de ensaio, um por modo, e a previsão de cada grandeza adaptada. Imprime no console qual modo ligar em cada ensaio. |
| `g9_modos_adaptativos.m` | As cinco figuras do capítulo e as tabelas numéricas, a partir da telemetria |

### Ordem dos ensaios

Para gerar os gráficos do protótipo, basta rodar o script. Os ensaios da
implementação seguem três passos: gerar o sinal no MATLAB, processá-lo com o
`CompressorOffline` e rodar a análise.

```matlab
>> gerar_sinal_reff      % escreve sinal_reff.wav
```
```
> CompressorOffline sinal_reff.wav saida_reff.wav
```
```matlab
>> ratio_efetiva         % lê os dois .wav e gera a curva
```

Na camada adaptativa, cada sinal é processado com **apenas** o modo
correspondente ligado. A operação simultânea usa `--adapt-all`.

| Ensaio | Sinal | Opção | Condição | Saída |
|---|---|---|---|---|
| Modo 1 | `sinal_modo1_limiar.wav` | `--adapt-threshold` | — | `saida_modo1.wav` |
| Modo 2 | `sinal_modo2_crista.wav` | `--adapt-ratio` | limiar manual de −25 dBFS | `saida_modo2.wav` |
| Modo 3 | `sinal_modo3_ataque.wav` | `--adapt-attack` | — | `saida_modo3.wav` |
| Modo 4 | `sinal_modo4_makeup.wav` | `--auto-makeup` | compensação manual de 0 dB | `saida_modo4.wav` |
| Simultâneo | `sinal_modo2_crista.wav` | `--adapt-all` | limiar manual de −25 dBFS | `saida_todos.wav` |

Exemplo do Modo 4, como impresso pelo `gerar_sinais_adaptativos.m`:

```
> CompressorOffline sinal_modo4_makeup.wav saida_modo4.wav -12 4 10 100 6 0 --auto-makeup
```

O `g9_modos_adaptativos.m` lê a telemetria gravada pelo `CompressorOffline`:
os arquivos `saida_modo1_adapt.csv` a `saida_modo4_adapt.csv` e
`saida_todos_adapt.csv`.

Sobre os nomes de arquivo: os gerados pelo MATLAB começam pelo nome do
ensaio (`curva_quadrada.wav`, `sinal_reff.wav`), e os produzidos pelo
`CompressorOffline` começam por `saida_`. As análises procuram exatamente por
esses nomes.

---

## Parâmetros de referência

| Parâmetro | Símbolo | Valor |
|---|---|---|
| Limiar | *T* | −12 dBFS |
| Razão de compressão | *R* | 4:1 |
| Largura do joelho | *W* | 6 dB |
| Tempo de ataque | τ<sub>A</sub> | 10 ms |
| Tempo de liberação | τ<sub>R</sub> | 100 ms |
| Ganho de compensação | *M* | +6 dB |
| Taxa de amostragem | *f<sub>s</sub>* | 44.100 Hz |

O sinal de teste do protótipo tem três trechos de um segundo, um para cada
região da curva estática:

- 0,10 a 440 Hz, abaixo do joelho;
- 0,80 a 440 Hz, compressão plena;
- 0,30 a 220 Hz, dentro do joelho.

---

## Camada adaptativa

| Modo | Parâmetro | Lei | Constantes |
|---|---|---|---|
| 1 | Limiar | *T* = μ + *k*σ, sobre o nível de curto prazo em dB | *k* = 1,0; nível em 30 ms; estatística em 400 ms; *T* ∈ [−50, −3] dBFS |
| 2 | Razão | interpolação linear: CF de 3 a 15 dB → *R* de 2 a 8, saturada | fator de crista pelo estimador de Giannoulis, Massberg e Reiss (2013), com 200 ms |
| 3 | Ataque | τ<sub>A</sub> = τ<sub>mín</sub> + (τ<sub>máx</sub> − τ<sub>mín</sub>) / (1 + *v*/*v*<sub>ref</sub>) | 0,5 a 50 ms; *v*<sub>ref</sub> = 10 dB/ms; pico rápido de 50 ms, suavização de 2 ms, retenção de 80 ms |
| 4 | Compensação | *M* = 10·log<sub>10</sub>(*P*<sub>ent</sub> / *P*<sub>sai</sub>), em malha aberta | potências em 500 ms; suavização de *M* em 1000 ms; *M* ∈ [0, 24] dB |

As leis são avaliadas uma vez por bloco, e os estimadores a cada amostra. Há
um aquecimento de 1000 ms, durante o qual vigoram os parâmetros manuais.

---

## Principais resultados

| Grandeza | Valor |
|---|---|
| Erro máximo C++ × MATLAB | 5,0 × 10⁻¹³ |
| Custo do núcleo (44,1 kHz) | 32 ns por amostra, 0,14 % de um núcleo |
| Custo com a camada adaptativa (44,1 kHz) | 85 ns por amostra, 0,38 % de um núcleo |
| Limiar adaptativo, erro máximo em 36 dB | 0,12 dB |
| Fator de crista da senoide, estimado contra teórico | 3,00 contra 3,01 dB |
| Ataque adaptativo, desvio máximo em relação à lei | 0,04 ms |
| Compensação automática, sobressinal máximo | 0,0076 dB |
| Estabilidade, 600 s de operação contínua | sem deriva mensurável |

---

## Ensaios com material musical

- **Guitarra** (Ableton Live, 44,1 kHz, bloco de 256 amostras): concluído.
  O limiar calculado pela lei, −14,9 dB, coincide com o exibido pelo
  *plugin*, −15,0 dB.
- Demais instrumentos: serão publicados neste repositório.

---

## Notas de implementação

**Precisão dupla.** Coeficientes e variáveis de estado operam em `double`.
Em precisão simples, o termo (1 − α) pode arredondar para zero quando α se
aproxima de 1, o que bloqueia a atualização do estado do filtro.

**Constante de guarda.** A conversão logarítmica soma ε = 10⁻⁹ à amplitude
antes do logaritmo. No silêncio absoluto, o resultado é −180 dBFS, valor
finito e bem definido.

**Estéreo.** A detecção usa o máximo entre os módulos dos dois canais, e o
ganho é único para os dois, o que preserva a imagem estéreo.

**Latência zero.** Não há *lookahead*. O custo dessa escolha é o sobressinal
no início do ataque.

**Tempo real.** A interface nunca chama o processador, e o processador
nunca chama a interface. A telemetria é publicada em variáveis atômicas, com
ordenação *release*–*acquire*, sem nenhum *mutex* na linha de áudio.

**Amostragem coerente.** Os ensaios espectrais usam janelas com número
inteiro de ciclos de todas as frequências envolvidas, o que evita vazamento
espectral sem precisar de janelamento.

---

## Licença

Material acadêmico, disponibilizado para consulta e verificação dos
resultados apresentados na monografia.
