#pragma once

// =====================================================================
//  AdaptiveController
//
//  Camada de adaptacao parametrica sobre o nucleo validado.
//
//  PRINCIPIO DE PROJETO
//  --------------------
//  A classe CompressorCore esta CONGELADA na etiqueta "nucleo-validado"
//  do repositorio, e o Capitulo 8 inteiro repousa sobre essa validacao.
//  Esta classe NAO a modifica: estima metricas do sinal, calcula os
//  parametros T, R, tau_A e M, e os entrega ao nucleo por meio do
//  metodo setParameters() ja existente.
//
//  Consequencias:
//    - a validacao cruzada do Capitulo 8 permanece valida, porque o
//      nucleo e bit a bit o mesmo arquivo compilado;
//    - cada modo pode ser ligado e desligado individualmente, condicao
//      necessaria para valida-los em isolamento;
//    - o custo computacional da adaptacao pode ser medido em separado.
//
//  SEGURANCA EM TEMPO REAL
//  -----------------------
//  Sem alocacao dinamica, sem travas, sem entrada e saida, sem excecoes.
//  Todos os metodos sao noexcept. Todas as variaveis de estado sao
//  membros, em precisao dupla. Nao ha dependencia de framework: a classe
//  compila tanto no plugin quanto no programa de validacao fora de
//  tempo real.
//
//  CADENCIA DE OPERACAO
//  --------------------
//    analyse()    -> uma vez por AMOSTRA. Atualiza os estimadores.
//    updateCore() -> uma vez por BLOCO.   Calcula os parametros e os
//                                         entrega ao nucleo.
//
//  A separacao e deliberada. O calculo dos coeficientes alpha envolve
//  uma exponencial, cuja execucao a cada amostra seria desproporcional
//  ao orcamento de tempo do bloco. Ela introduz atraso de adaptacao de
//  um bloco (11,6 ms a 44.100 Hz com blocos de 512 amostras), valor
//  muito inferior as constantes de tempo dos proprios estimadores.
//
//  TCC -- Danilo Francisco Ropero Sivirino
//  IFSP Campus Catanduva -- Engenharia de Controle e Automacao
// =====================================================================

#include <cmath>
#include <algorithm>

#include "CompressorCore.h"

class AdaptiveController
{
public:
    // -----------------------------------------------------------------
    //  Configuracao
    //
    //  Reune os parametros manuais (usados quando o modo correspondente
    //  esta desligado), as chaves de habilitacao e as constantes de
    //  sintonia de cada lei de adaptacao.
    // -----------------------------------------------------------------
    struct Config
    {
        // --- parametros manuais do nucleo -----------------------------
        double thresholdDb { -12.0 };
        double ratio       {   4.0 };
        double attackMs    {  10.0 };
        double releaseMs   { 100.0 };
        double kneeDb      {   6.0 };
        double makeupDb    {   6.0 };

        // --- chaves de habilitacao dos modos --------------------------
        bool adaptiveThreshold { false };   // Modo 1
        bool adaptiveRatio     { false };   // Modo 2
        bool adaptiveAttack    { false };   // Modo 3
        bool autoMakeup        { false };   // Modo 4

        // --- Modo 1: limiar adaptativo --------------------------------
        //  T[n] = mu[n] + k * sigma[n], limitado a [min, max].
        //
        //  mu e sigma NAO sao calculados sobre o nivel instantaneo, e
        //  sim sobre o NIVEL DE CURTO PRAZO -- a potencia media em
        //  janela de shortTermTauMs, expressa em dB. A distincao e
        //  essencial: o nivel instantaneo de um sinal oscilatorio
        //  atravessa o zero a cada semiciclo e despenca a -180 dBFS,
        //  de modo que sua media e seu desvio padrao descrevem a forma
        //  de onda, e nao o nivel do sinal. Uma senoide estacionaria
        //  apresentaria desvio padrao de varios decibeis, quando o
        //  correto e zero.
        //
        //  A estimativa e, portanto, de dois estagios: potencia de
        //  curto prazo e, sobre ela, estatistica de longo prazo.
        double thresholdK      {   1.0 };   // em desvios padrao
        double shortTermTauMs  {  30.0 };   // janela do nivel de curto prazo
        double statsTauMs      { 400.0 };   // janela da estatistica
        double thresholdMinDb  { -50.0 };
        double thresholdMaxDb  {  -3.0 };

        // --- Modo 2: razao pelo fator de crista -----------------------
        //  Interpolacao linear entre dois pontos de referencia.
        //  ATENCAO: calibrar estas quatro constantes pela secao de
        //  automacao de parametros de Giannoulis, Massberg e Reiss
        //  (2013). A ESTRUTURA da lei nao muda; apenas os numeros.
        double crestLowDb  {  3.0 };        // crista baixa (senoide pura)
        double crestHighDb { 15.0 };        // crista alta  (percussivo)
        double ratioAtLow  {  2.0 };
        double ratioAtHigh {  8.0 };
        double ratioMin    {  1.0 };        // 1,0 = sem compressao
        double ratioMax    { 20.0 };

        //  Constante de tempo UNICA do estimador de fator de crista.
        //
        //  Segue a formulacao de Giannoulis, Massberg e Reiss (2013):
        //  o valor de pico e o valor eficaz sao estimados sobre o
        //  QUADRADO do sinal, ambos com a MESMA constante de tempo.
        //
        //      x2_pico[n] = max( x2[n],  a*x2_pico[n-1] + (1-a)*x2[n] )
        //      x2_rms [n] =              a*x2_rms [n-1] + (1-a)*x2[n]
        //      CF[n]      = sqrt( x2_pico[n] / x2_rms[n] )
        //
        //  Duas propriedades decorrem de compartilhar o coeficiente:
        //
        //  (i)  as envoltorias de liberacao sao casadas. Com constantes
        //       distintas, pico e eficaz decaem em ritmos diferentes e
        //       a razao entre eles deriva mesmo com o sinal parado --
        //       o fator de crista passa a medir o descasamento dos
        //       estimadores, e nao a crista do sinal;
        //
        //  (ii) CF >= 1 por construcao. Como x2_pico[n] e o maximo
        //       entre x2[n] e uma expressao identica a de x2_rms[n]
        //       exceto pelo estado anterior, a desigualdade
        //       x2_pico >= x2_rms se propaga por inducao. Dispensa a
        //       saturacao em zero que a formulacao anterior exigia.
        //
        //  O valor de 200 ms e o adotado pelos autores. Verificado:
        //  senoide pura devolve 3,00 dB (teorico 3,0103) e onda
        //  quadrada devolve 0,00 dB.
        double crestTauMs { 200.0 };

        // --- Modo 3: ataque pela derivada do envelope -----------------
        //  tau_A = min + (max - min) / (1 + s / sRef)
        //  Lei monotona decrescente e intrinsecamente limitada:
        //  s = 0 devolve attackMaxMs; s -> infinito devolve attackMinMs.
        //  Dispensa saturacao explicita.
        double slopeRefDbPerMs { 10.0 };
        double attackMinMs     {  0.5 };
        double attackMaxMs     { 50.0 };

        //  Liberacao do detector de pico RAPIDO, dedicado a derivada.
        //  Nao pode ser o mesmo detector do fator de crista: aquele
        //  exige liberacao lenta, para que o pico persista ao longo da
        //  janela de medida; esta exige liberacao rapida, para que o
        //  envelope decaia entre transientes e o seguinte volte a
        //  produzir uma subida mensuravel. Sao requisitos opostos, e a
        //  tentativa de atende-los com um unico detector inviabiliza um
        //  dos dois modos.
        double peakFastTauMs { 50.0 };

        // --- Modo 4: compensacao automatica de ganho ------------------
        //  M = 10*log10(P_in / P_out), com P_out medida ANTES da
        //  aplicacao de M. A medida pre-compensacao torna a malha
        //  ABERTA: o valor de M nao realimenta a propria medida.
        //  Ver nota de projeto no .cpp.
        double powerTauMs  {  500.0 };      // janela das potencias
        double makeupTauMs { 1000.0 };      // suavizacao do proprio M
        double makeupMinDb {    0.0 };
        double makeupMaxDb {   24.0 };

        // --- aquecimento dos estimadores ------------------------------
        //  Enquanto os estimadores nao houverem acumulado historico
        //  suficiente, as leis de adaptacao produzem valores sem
        //  significado: no primeiro instante o detector de pico ja
        //  registra o pico do sinal, mas a potencia media ainda e
        //  proxima de zero, e o fator de crista resultante tende ao
        //  infinito. Durante esse intervalo o controlador mantem os
        //  parametros manuais.
        double warmupMs { 1000.0 };

        //  Piso de analise. Niveis de curto prazo abaixo deste valor
        //  sao saturados antes de entrarem na estatistica, de modo que
        //  intervalos de silencio nao distorcam a media e o desvio
        //  padrao. Pratica analoga ao portao (gate) absoluto definido
        //  pela recomendacao ITU-R BS.1770 para medicao de loudness.
        double levelFloorDb { -100.0 };
    };

    // -----------------------------------------------------------------
    //  Ciclo de vida
    // -----------------------------------------------------------------
    void prepare (double sampleRateHz) noexcept;
    void reset() noexcept;
    void setConfig (const Config& newConfig) noexcept;

    // -----------------------------------------------------------------
    //  Uma vez por AMOSTRA, apos a chamada a core.nextGain().
    //
    //  detector  valor alimentado ao nucleo, ja retificado
    //            (para estereo, max(|xL|, |xR|))
    //  gainLin   fator devolvido por core.nextGain(), que INCLUI o
    //            ganho de compensacao em vigor
    //
    //  O controlador remove internamente o ganho de compensacao que ele
    //  proprio impos, obtendo a saida comprimida pre-compensacao. E essa
    //  grandeza que alimenta o Modo 4, o que mantem a malha aberta.
    // -----------------------------------------------------------------
    void analyse (double detector, double gainLin) noexcept;

    // -----------------------------------------------------------------
    //  Uma vez por BLOCO, antes de processar as amostras.
    //  Calcula os parametros ativos e os entrega ao nucleo.
    // -----------------------------------------------------------------
    void updateCore (CompressorCore& core) noexcept;

    // -----------------------------------------------------------------
    //  Telemetria -- parametros em vigor
    //  Destinada aos medidores da interface grafica e ao registro em
    //  arquivo para as figuras do capitulo de validacao.
    // -----------------------------------------------------------------
    double getThresholdDb() const noexcept { return outThresholdDb; }
    double getRatio()       const noexcept { return outRatio;       }
    double getAttackMs()    const noexcept { return outAttackMs;    }
    double getMakeupDb()    const noexcept { return outMakeupDb;    }

    // -----------------------------------------------------------------
    //  Telemetria -- estimadores internos
    //  Sao estas as grandezas a registrar nos ensaios de validacao de
    //  cada modo: demonstram que a lei de adaptacao responde a metrica
    //  que a governa.
    // -----------------------------------------------------------------
    bool   isWarmedUp()      const noexcept { return samplesSeen >= warmupSamples; }
    double getMeanLevelDb()  const noexcept { return muDb;          }
    double getStdDevDb()     const noexcept { return sigmaDb;       }
    double getCrestFactorDb()const noexcept { return crestDb;       }
    double getSlopeDbPerMs() const noexcept { return slopeHeld;     }
    double getInputLevelDb() const noexcept;
    double getOutputLevelDb()const noexcept;

private:
    static double alphaFromTau (double tauMs, double fs) noexcept;
    static double clampd (double v, double lo, double hi) noexcept
    {
        return (v < lo) ? lo : ((v > hi) ? hi : v);
    }
    // Zera valores subnormais, cuja aritmetica e ordens de grandeza
    // mais lenta em algumas arquiteturas. Custo: uma comparacao.
    static double flush (double v) noexcept
    {
        return (std::abs (v) < 1.0e-20) ? 0.0 : v;
    }

    Config cfg {};

    double fs { 44100.0 };

    // --- coeficientes derivados de cfg (recalculados em setConfig) ---
    double aStats  { 0.0 };     // janela de media e desvio padrao
    double aPower  { 0.0 };     // janela das potencias (Modo 4)
    double aMakeup { 0.0 };     // suavizacao de M      (Modo 4)
    double aCrest  { 0.0 };     // janela unica do fator de crista (Modo 2)
    double aPeakFast{ 0.0 };    // liberacao do pico rapido (Modo 3)
    double aShort  { 0.0 };     // janela do nivel de curto prazo
    double aLevel  { 0.0 };     // suavizacao do nivel p/ a derivada
    double aSlopeRel{ 0.0 };    // retencao da derivada (Modo 3)

    long long warmupSamples { 0 };
    long long samplesSeen   { 0 };

    // --- estado dos estimadores --------------------------------------
    double shortSq   {   0.0 }; // potencia de curto prazo
    double muDb      { -40.0 }; // media do nivel de curto prazo, dBFS
    double msDb      {   0.0 }; // media do quadrado desse nivel
    double sigmaDb   {   0.0 }; // desvio padrao do nivel, dB

    double peakSq    {   0.0 }; // pico do quadrado, p/ o fator de crista
    double peakFast  {   0.0 }; // pico rapido, p/ a derivada
    double rmsSq     {   0.0 }; // media do quadrado, p/ o fator de crista
    double crestDb   {   0.0 }; // fator de crista, dB

    double levelSm   { -40.0 }; // nivel suavizado p/ a derivada
    double levelPrev { -40.0 };
    double slopeHeld {   0.0 }; // derivada retida, dB/ms

    double powInSq      { 0.0 };   // potencia media da entrada
    double powOutSq     { 0.0 };   // potencia media da saida pre-compensacao
    double makeupTarget { 6.0 };   // alvo de M, calculado por bloco
    double makeupSm     { 6.0 };   // M suavizado, atualizado por amostra

    bool primed { false };      // trata a primeira amostra sem transitorio

    // --- parametros em vigor -----------------------------------------
    double outThresholdDb { -12.0 };
    double outRatio       {   4.0 };
    double outAttackMs    {  10.0 };
    double outMakeupDb    {   6.0 };

    // fator linear que desfaz o ganho de compensacao em vigor
    double invMakeupLin   {   1.0 };
};
