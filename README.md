# Compressor de Áudio Digital — Scripts MATLAB

Código de apoio ao Trabalho de Conclusão de Curso **"Desenvolvimento de um
Sistema de Compressão Dinâmica em Tempo Real Utilizando Processamento Digital
de Sinais"**.

Bacharelado em Engenharia de Controle e Automação
Instituto Federal de São Paulo — Câmpus Catanduva
Autor: Danilo Francisco Ropero Sivirino
Orientador: Prof. Dr. João Domingos Augusto dos Santos Pereira

---

## O que é

Um compressor digital de faixa dinâmica em topologia *feedforward*, com
detector ramificado posicionado no domínio logarítmico. O sistema é
parametrizado por limiar, razão de compressão, largura do joelho, tempos de
ataque e de liberação e ganho de compensação.

O desenvolvimento segue duas etapas. Primeiro o modelo matemático é
prototipado em MATLAB e verificado graficamente; depois é implementado em
C++ sobre o *framework* JUCE e confrontado, amostra a amostra, com esse
protótipo. Este repositório reúne os scripts das duas etapas: os que geram as
figuras do protótipo e os que apuram as métricas da implementação.

Os códigos não são reproduzidos integralmente no corpo da monografia, por
recomendação da banca de qualificação. Estão aqui, versionados e executáveis.

---

## Requisitos

- **MATLAB R2020a ou superior.** A exportação usa `exportgraphics`, que foi
  introduzida nessa versão.
- Nenhum *toolbox* adicional. Tudo é MATLAB base.

---

## Como rodar

Coloque todos os arquivos na mesma pasta, abra o MATLAB nela e execute o
script desejado. Cada um é independente e salva o próprio PNG.

```matlab
>> g1_sinal_entrada      % gera fig_g1_sinal_entrada.png
>> g5_curva_estatica     % gera fig_g5_curva_estatica.png
```

Os scripts da validação em C++ precisam dos arquivos de áudio processados
pela ferramenta `CompressorOffline`. A ordem é: gerar o sinal de ensaio,
processá-lo fora do MATLAB, e então rodar a análise.

```matlab
>> gerar_sinal_reff      % escreve sinal_reff.wav
```

```
> CompressorOffline.exe sinal_reff.wav saida_reff.wav
```

```matlab
>> ratio_efetiva         % lê os dois .wav e gera a curva
```

Vale a convenção de nomes: os arquivos gerados pelos scripts do MATLAB
começam pelo nome do ensaio (`curva_quadrada.wav`, `sinal_reff.wav`); os
produzidos pelo `CompressorOffline` começam por `saida_`
(`saida_quadrada.csv`, `saida_senoide.csv`, `saida.csv`). As análises
procuram exatamente por esses nomes.

---

## Parâmetros de referência

Todos os gráficos do protótipo usam a mesma configuração, representativa de
compressão moderada em material de programa musical:

| Parâmetro | Símbolo | Valor |
|---|---|---|
| Limiar | *T* | −12 dBFS |
| Razão de compressão | *R* | 4:1 |
| Largura do joelho | *W* | 6 dB |
| Tempo de ataque | τ<sub>A</sub> | 10 ms |
| Tempo de liberação | τ<sub>R</sub> | 100 ms |
| Ganho de compensação | *M* | +6 dB |
| Taxa de amostragem | *f<sub>s</sub>* | 44.100 Hz |

O sinal de teste tem três segmentos de um segundo, escolhidos para exercitar
as três regiões da curva estática: amplitude 0,10 a 440 Hz (abaixo do
joelho), 0,80 a 440 Hz (compressão plena) e 0,30 a 220 Hz (dentro do joelho).

---

## Arquivos

### Núcleo

| Arquivo | Função |
|---|---|
| `bloco_base.m` | Implementação de referência do compressor: geração do sinal, laço de compressão amostra a amostra e cálculo das métricas. Está embutido no topo de cada script de gráfico, de modo que todos operem sobre exatamente o mesmo sinal e o mesmo algoritmo. |

### Funções auxiliares — necessárias para rodar os gráficos

| Arquivo | Função |
|---|---|
| `virgula.m` | Troca o ponto decimal por vírgula nos rótulos dos eixos, conforme a norma ortográfica brasileira. Chamada por último em cada script. |
| `numvir.m` | Formata um número com vírgula decimal, para os textos dentro do gráfico. |
| `estilo_abnt.m` | Padronização de eixo para impressão: fundo branco, escrita preta, grade discreta. |

### Prototipagem do modelo

| Script | Produz |
|---|---|
| `g1_sinal_entrada.m` | Sinal de entrada no domínio do tempo, com *zoom* nos ciclos da senoide |
| `g2_sinal_saida.m` | Sinal de saída sobreposto à entrada, com *zoom* no transitório de ataque |
| `g3_envelope_ganho.m` | Envelope de ganho ao longo do sinal, com *zoom* no transitório de liberação |
| `g4_nivel_dBFS.m` | Nível de entrada contra nível de saída, em dBFS |
| `g5_curva_estatica.m` | Curva estática de compressão: sem compressão, *hard knee*, *soft knee* e limitador |
| `g6_metricas.m` | Painel consolidado de métricas e diagrama de polos no plano Z |
| `g7_resposta_degrau.m` | Resposta ao degrau dos filtros de ataque e de liberação, verificando τ<sub>A</sub> e τ<sub>R</sub> |
| `g8_comparacao_knee.m` | Impacto da largura do joelho sobre a curva estática e sobre o sinal em regime |

### Validação da implementação em C++

| Script | Produz |
|---|---|
| `validacao_cruzada.m` | Comparação amostra a amostra entre o protótipo e a implementação |
| `acomodacao.m` | Evolução do envelope de ganho após a transição de nível |
| `metricas_dinamica.m` | Métricas de faixa dinâmica e sensibilidade à janela de guarda |
| `constantes_de_tempo.m` | Constantes de tempo medidas sob diferentes condições de excitação |
| `gerar_sinais_curva.m` | Gera os dois sinais em escada do ensaio: onda quadrada de 100 Hz e senoide de 1 kHz. A primeira serve à varredura da característica estática, a segunda também ao ensaio de distorção harmônica |
| `curva_estatica.m` | Característica estática medida contra a prevista analiticamente |
| `distorcao_harmonica.m` | Distorção harmônica total e composição espectral, por transformada discreta |
| `gerar_sinal_reff.m` | Gera a senoide modulada em amplitude para o ensaio de razão efetiva |
| `ratio_efetiva.m` | Razão de compressão efetiva em função da frequência de modulação |

---

## Notas de implementação

**Precisão dupla.** Coeficientes e variáveis de estado operam em `double`. Em
precisão simples, o termo complementar (1 − α) pode arredondar para zero
quando α se aproxima de 1, bloqueando a atualização do estado do filtro.

**Constante de guarda.** A conversão logarítmica soma ε = 10⁻⁹ à amplitude
antes do logaritmo. No silêncio absoluto o resultado é −180 dBFS, valor
finito e bem definido; a soma depois do logaritmo seria indeterminada.

**Amostragem coerente.** Os ensaios espectrais usam janelas que contêm número
inteiro de ciclos de todas as frequências envolvidas. Sem isso haveria
vazamento espectral, e a apuração exigiria janelamento — que introduz
incerteza própria na medida.

---

## Estado atual

Este repositório contém, por ora, apenas os scripts MATLAB. O código C++ do
*plugin* e da ferramenta de processamento fora de tempo real será publicado
na sequência, junto dos mecanismos de adaptação paramétrica.

---

## Licença

Material acadêmico, disponibilizado para consulta e verificação dos
resultados apresentados na monografia.
