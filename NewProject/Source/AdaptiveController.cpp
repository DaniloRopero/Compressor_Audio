#include "AdaptiveController.h"

namespace
{
    // Mesma constante de guarda do nucleo, pela mesma razao: evitar
    // log10(0). Somada na amplitude linear, produz -180 dBFS no
    // silencio absoluto -- valor finito e bem definido.
    constexpr double kEpsilon = 1.0e-9;

    inline double toDb (double linear) noexcept
    {
        return 20.0 * std::log10 (linear + kEpsilon);
    }

    inline double powerToDb (double power) noexcept
    {
        return 10.0 * std::log10 (power + kEpsilon * kEpsilon);
    }
}

// =====================================================================
//  Coeficiente do filtro de um polo a partir da constante de tempo.
//
//  Identica a formulacao do nucleo (Capitulo 4): discretizacao exata da
//  equacao diferencial de primeira ordem sob entrada constante por
//  partes. A condicao 0 < alpha < 1 e automaticamente satisfeita para
//  tau e fs positivos, o que garante a estabilidade de cada estimador
//  pelo mesmo argumento ja desenvolvido na monografia.
// =====================================================================
double AdaptiveController::alphaFromTau (double tauMs, double fs) noexcept
{
    const double tauSamples = fs * tauMs * 1.0e-3;

    if (tauSamples <= 1.0e-6)
        return 0.0;                       // sem suavizacao

    return std::exp (-1.0 / tauSamples);
}

void AdaptiveController::prepare (double sampleRateHz) noexcept
{
    fs = sampleRateHz;
    setConfig (cfg);                      // recalcula os coeficientes
    reset();
}

void AdaptiveController::reset() noexcept
{
    samplesSeen = 0;

    shortSq   =   0.0;
    muDb      = -40.0;
    msDb      =  muDb * muDb;
    sigmaDb   =   0.0;

    peakSq    =   0.0;
    peakFast  =   0.0;
    rmsSq     =   0.0;
    crestDb   =   0.0;

    levelSm   = -40.0;
    levelPrev = -40.0;
    slopeHeld =   0.0;

    powInSq      =   0.0;
    powOutSq     =   0.0;
    makeupTarget = cfg.makeupDb;
    makeupSm     = cfg.makeupDb;

    primed    = false;

    outThresholdDb = cfg.thresholdDb;
    outRatio       = cfg.ratio;
    outAttackMs    = cfg.attackMs;
    outMakeupDb    = cfg.makeupDb;

    invMakeupLin   = std::pow (10.0, -outMakeupDb / 20.0);
}

void AdaptiveController::setConfig (const Config& newConfig) noexcept
{
    cfg = newConfig;

    aShort   = alphaFromTau (cfg.shortTermTauMs, fs);
    aStats   = alphaFromTau (cfg.statsTauMs,     fs);
    aPower   = alphaFromTau (cfg.powerTauMs,     fs);
    aMakeup  = alphaFromTau (cfg.makeupTauMs,    fs);

    warmupSamples = static_cast<long long> (cfg.warmupMs * 1.0e-3 * fs);

    // Detector de pico: ataque instantaneo, liberacao de peakTauMs.
    // O ataque instantaneo e necessario para que o fator de crista
    // reflita o pico verdadeiro, e nao um pico suavizado. A liberacao
    // deve ser mais lenta que a janela de potencia -- ver comentario
    // em Config::peakTauMs.
    aCrest    = alphaFromTau (cfg.crestTauMs,    fs);
    aPeakFast = alphaFromTau (cfg.peakFastTauMs, fs);

    // Nivel suavizado do qual se extrai a derivada. A suavizacao de
    // 2 ms e indispensavel: a derivada do nivel instantaneo seria
    // inutilizavel, pois |x[n]| cruza o zero a cada semiciclo e o
    // nivel em dB despenca a -180 dBFS nesses instantes.
    aLevel    = alphaFromTau (2.0, fs);

    // Retencao da derivada: ataque instantaneo, liberacao de 80 ms.
    // Sem ela, a derivada de um transiente seria um impulso de poucas
    // amostras, que a leitura uma vez por bloco quase sempre perderia.
    aSlopeRel = alphaFromTau (80.0, fs);
}

// =====================================================================
//  ESTIMADORES -- uma vez por amostra
// =====================================================================
void AdaptiveController::analyse (double detector, double gainLin) noexcept
{
    const double d     = std::abs (detector);
    const double dSq   = d * d;
    const double xG    = toDb (d);

    // --- saida comprimida ANTES da compensacao -----------------------
    //  O controlador remove o ganho de compensacao que ele proprio
    //  impos. E esta a grandeza que alimenta o Modo 4.
    const double gPre   = gainLin * invMakeupLin;
    const double outPre = d * gPre;
    const double outSq  = outPre * outPre;

    // --- primeira amostra: carrega os estados -------------------------
    //  Evita um transitorio inicial de varias centenas de milissegundos
    //  enquanto os filtros partem de suas condicoes iniciais.
    if (! primed)
    {
        primed    = true;
        shortSq   = dSq;
        muDb      = powerToDb (dSq);
        msDb      = muDb * muDb;
        sigmaDb   = 0.0;
        peakSq    = dSq;
        peakFast  = d;
        rmsSq     = dSq;
        levelSm   = xG;
        levelPrev = xG;
        slopeHeld = 0.0;
        powInSq   = dSq;
        powOutSq  = outSq;
    }

    if (samplesSeen < warmupSamples)
        ++samplesSeen;

    // -----------------------------------------------------------------
    //  Modo 1 -- media e desvio padrao do nivel
    //
    //  Janela exponencial de constante de tempo statsTauMs. Equivale,
    //  em reducao de variancia, a uma janela retangular de duracao
    //  aproximada 2*tau -- equivalencia que convem registrar no texto,
    //  pois o objetivo especifico fala em "janelas temporais discretas".
    //
    //  A variancia sai da identidade  sigma^2 = E[x^2] - (E[x])^2.
    //  A diferenca pode resultar levemente negativa por arredondamento,
    //  dai a saturacao em zero antes da raiz.
    // -----------------------------------------------------------------
    //  Primeiro estagio: potencia de curto prazo.
    shortSq = flush (aShort * shortSq + (1.0 - aShort) * dSq);

    double levelShortDb = powerToDb (shortSq);
    if (levelShortDb < cfg.levelFloorDb)
        levelShortDb = cfg.levelFloorDb;

    //  Ao encerrar-se o aquecimento, a estatistica e recarregada com o
    //  nivel corrente. Sem isso, o trecho inicial -- em que a potencia
    //  de curto prazo parte do repouso e o nivel percorre dezenas de
    //  decibeis -- permaneceria no acumulador e inflaria o desvio
    //  padrao por varias constantes de tempo.
    if (samplesSeen == warmupSamples)
    {
        ++samplesSeen;                 // executa uma unica vez
        muDb    = levelShortDb;
        msDb    = levelShortDb * levelShortDb;
        sigmaDb = 0.0;
    }

    //  Segundo estagio: estatistica sobre o nivel de curto prazo.
    muDb = flush (aStats * muDb + (1.0 - aStats) * levelShortDb);
    msDb = flush (aStats * msDb + (1.0 - aStats) * levelShortDb * levelShortDb);

    const double var = msDb - muDb * muDb;
    sigmaDb = (var > 0.0) ? std::sqrt (var) : 0.0;

    // -----------------------------------------------------------------
    //  Modo 2 -- fator de crista
    //
    //  CF = 20*log10(pico / eficaz). Observe-se que esta e a MESMA
    //  grandeza reportada como resultado no capitulo de validacao: ali
    //  ela e medida, aqui passa a ser variavel de controle.
    //
    //  Formulacao de Giannoulis, Massberg e Reiss (2013): pico e eficaz
    //  estimados sobre o QUADRADO do sinal, ambos com a MESMA constante
    //  de tempo (cfg.crestTauMs). O compartilhamento do coeficiente e o
    //  ponto essencial -- ver a justificativa no cabecalho.
    //
    //  Note-se que o ramo de liberacao do detector de pico nao e um
    //  decaimento puro: ele replica integralmente a recursao do valor
    //  eficaz. E dai que vem o casamento das envoltorias.
    // -----------------------------------------------------------------
    rmsSq  = flush (aCrest * rmsSq + (1.0 - aCrest) * dSq);

    const double decaiPico = aCrest * peakSq + (1.0 - aCrest) * dSq;
    peakSq = flush ((dSq > decaiPico) ? dSq : decaiPico);

    //  Razao de POTENCIAS: o fator 10, e nao 20, porque as grandezas
    //  ja estao ao quadrado.
    crestDb = (rmsSq > 0.0) ? 10.0 * std::log10 (peakSq / rmsSq) : 0.0;

    //  Guarda defensiva. Pela construcao acima peakSq >= rmsSq sempre,
    //  de modo que a condicao nunca deveria disparar; mantida apenas
    //  contra denormais extremos.
    if (crestDb < 0.0) crestDb = 0.0;

    // -----------------------------------------------------------------
    //  Modo 3 -- derivada discreta do envelope
    //
    //  Extraida do nivel suavizado, em dB por milissegundo, retendo-se
    //  apenas a parte ascendente: e a chegada do transiente que exige
    //  ataque curto, nao o seu decaimento.
    // -----------------------------------------------------------------
    peakFast = (d > peakFast) ? d : flush (aPeakFast * peakFast);

    levelPrev = levelSm;
    levelSm   = flush (aLevel * levelSm + (1.0 - aLevel) * toDb (peakFast));

    const double rise  = levelSm - levelPrev;                  // dB/amostra
    const double slope = (rise > 0.0) ? rise * fs * 1.0e-3     // dB/ms
                                      : 0.0;

    slopeHeld = (slope > slopeHeld) ? slope
                                    : flush (aSlopeRel * slopeHeld);

    // -----------------------------------------------------------------
    //  Modo 4 -- potencias media de entrada e de saida
    //
    //  NOTA DE PROJETO -- malha aberta por construcao
    //  ----------------------------------------------
    //  A potencia de saida e medida ANTES da aplicacao do ganho de
    //  compensacao. Com isso, M nao influencia a grandeza que o
    //  determina, e o mecanismo permanece estritamente feedforward.
    //
    //  A alternativa -- medir a saida ja compensada -- fecharia uma
    //  malha de realimentacao integral, estavel apenas sob separacao
    //  suficiente de escalas de tempo e sujeita a oscilacao quando essa
    //  separacao nao se verifica. A escolha pela malha aberta e
    //  deliberada, e deve ser justificada no texto: ela elimina a
    //  possibilidade de oscilacao sem perda de funcionalidade, uma vez
    //  que a relacao entre M e o nivel de saida e exatamente conhecida.
    // -----------------------------------------------------------------
    powInSq  = flush (aPower * powInSq  + (1.0 - aPower) * dSq);
    powOutSq = flush (aPower * powOutSq + (1.0 - aPower) * outSq);

    // -----------------------------------------------------------------
    //  Suavizacao do proprio ganho de compensacao.
    //
    //  POR QUE AQUI, E NAO EM updateCore()
    //  -----------------------------------
    //  O coeficiente de um filtro de primeira ordem e calculado para
    //  uma cadencia de atualizacao especifica. Aplicado uma vez por
    //  BLOCO um coeficiente calculado para cadencia por AMOSTRA, a
    //  constante de tempo efetiva resultaria multiplicada pelo tamanho
    //  do bloco -- 512 vezes maior, no caso usual. O alvo e calculado
    //  por bloco em updateCore(); a suavizacao corre aqui, por amostra,
    //  o que torna a constante de tempo independente do tamanho do
    //  bloco escolhido pelo programa hospedeiro.
    // -----------------------------------------------------------------
    makeupSm = flush (aMakeup * makeupSm + (1.0 - aMakeup) * makeupTarget);
}

// =====================================================================
//  LEIS DE ADAPTACAO -- uma vez por bloco
// =====================================================================
void AdaptiveController::updateCore (CompressorCore& core) noexcept
{
    // -----------------------------------------------------------------
    //  Aquecimento: enquanto os estimadores nao houverem acumulado
    //  historico suficiente, mantem-se os parametros manuais. Evita o
    //  transitorio inicial sem significado descrito em Config::warmupMs.
    // -----------------------------------------------------------------
    const bool warm = (samplesSeen >= warmupSamples);

    if (! warm)
    {
        outThresholdDb = cfg.thresholdDb;
        outRatio       = cfg.ratio;
        outAttackMs    = cfg.attackMs;
        outMakeupDb    = cfg.makeupDb;
        makeupTarget   = cfg.makeupDb;
        makeupSm       = cfg.makeupDb;
        invMakeupLin   = std::pow (10.0, -outMakeupDb / 20.0);

        core.setParameters (outThresholdDb, outRatio, outAttackMs,
                            cfg.releaseMs, cfg.kneeDb, outMakeupDb);
        return;
    }

    // --- Modo 1: limiar ----------------------------------------------
    if (cfg.adaptiveThreshold)
    {
        const double t = muDb + cfg.thresholdK * sigmaDb;
        outThresholdDb = clampd (t, cfg.thresholdMinDb, cfg.thresholdMaxDb);
    }
    else
    {
        outThresholdDb = cfg.thresholdDb;
    }

    // --- Modo 2: razao ------------------------------------------------
    //  Interpolacao linear entre os dois pontos de referencia, com
    //  extrapolacao saturada fora do intervalo.
    if (cfg.adaptiveRatio)
    {
        const double span = cfg.crestHighDb - cfg.crestLowDb;
        double r;

        if (span > 1.0e-6)
        {
            const double u = clampd ((crestDb - cfg.crestLowDb) / span, 0.0, 1.0);
            r = cfg.ratioAtLow + u * (cfg.ratioAtHigh - cfg.ratioAtLow);
        }
        else
        {
            r = cfg.ratio;
        }

        outRatio = clampd (r, cfg.ratioMin, cfg.ratioMax);

        // Razao inferior a 1 significaria expansao, nao compressao.
        if (outRatio < 1.0) outRatio = 1.0;
    }
    else
    {
        outRatio = cfg.ratio;
    }

    // --- Modo 3: tempo de ataque -------------------------------------
    //  tau_A = min + (max - min) / (1 + s / sRef)
    //
    //  Lei monotona decrescente, continua e intrinsecamente limitada:
    //    s = 0        -> attackMaxMs
    //    s = sRef     -> ponto medio entre min e max
    //    s -> infinito-> attackMinMs
    //  Dispensa saturacao explicita, o que elimina a descontinuidade
    //  de derivada que uma saturacao introduziria.
    if (cfg.adaptiveAttack)
    {
        const double sRef = (cfg.slopeRefDbPerMs > 1.0e-6)
                          ?  cfg.slopeRefDbPerMs : 1.0;

        const double span = cfg.attackMaxMs - cfg.attackMinMs;
        outAttackMs = cfg.attackMinMs + span / (1.0 + slopeHeld / sRef);
    }
    else
    {
        outAttackMs = cfg.attackMs;
    }

    // --- Modo 4: compensacao automatica ------------------------------
    //  M = 10*log10(P_in / P_out), com P_out medida pre-compensacao.
    //  Dez, e nao vinte, porque a razao e de potencias.
    if (cfg.autoMakeup)
    {
        // Alvo instantaneo. A suavizacao que impede o bombeamento de
        // nivel corre por amostra, em analyse().
        makeupTarget = clampd (powerToDb (powInSq) - powerToDb (powOutSq),
                               cfg.makeupMinDb, cfg.makeupMaxDb);

        outMakeupDb = makeupSm;
    }
    else
    {
        outMakeupDb  = cfg.makeupDb;
        makeupTarget = cfg.makeupDb;
        makeupSm     = cfg.makeupDb;
    }

    // Fator que desfaz a compensacao na proxima rodada de estimativas.
    invMakeupLin = std::pow (10.0, -outMakeupDb / 20.0);

    // --- entrega ao nucleo -------------------------------------------
    //  Unico ponto de contato com a classe congelada.
    core.setParameters (outThresholdDb,
                        outRatio,
                        outAttackMs,
                        cfg.releaseMs,
                        cfg.kneeDb,
                        outMakeupDb);
}

double AdaptiveController::getInputLevelDb() const noexcept
{
    return powerToDb (powInSq);
}

double AdaptiveController::getOutputLevelDb() const noexcept
{
    return powerToDb (powOutSq);
}
