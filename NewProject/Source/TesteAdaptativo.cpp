// =====================================================================
//  TesteAdaptativo.cpp
//
//  Verificacao de sanidade da classe AdaptiveController, independente
//  de JUCE e de arquivos de audio. Gera sinais sinteticos em memoria e
//  confere se cada lei de adaptacao responde a metrica que a governa.
//
//  NAO e o ensaio de validacao do TCC -- esse usa os sinais em WAV e o
//  CompressorOffline. Este programa serve para confirmar, em segundos,
//  que o codigo compila e que os quatro modos reagem no sentido certo
//  antes de integra-los ao plugin.
//
//  Compilar (prompt de comando do desenvolvedor, Windows):
//      cl /O2 /EHsc /std:c++17 TesteAdaptativo.cpp CompressorCore.cpp
//         AdaptiveController.cpp /Fe:TesteAdaptativo.exe
//
//  Compilar (GCC):
//      g++ -O2 -std=c++17 TesteAdaptativo.cpp CompressorCore.cpp
//          AdaptiveController.cpp -o TesteAdaptativo
// =====================================================================

#include <cstdio>
#include <cmath>
#include <vector>
#include <string>
#include <algorithm>

#include "CompressorCore.h"
#include "AdaptiveController.h"

namespace
{
    constexpr double kPi = 3.14159265358979323846;
    constexpr double FS  = 44100.0;
    constexpr int    BLK = 512;

    struct Resultado
    {
        double limiarDb, razao, ataqueMs, makeupDb;    // valores finais
        double mediaDb, desvioDb, cristaDb, derivada;  // estimadores finais
        double picoSaida, rmsSaida;

        // Extremos observados ao longo da execucao. Para os Modos 2 e 3
        // o valor final e um instantaneo que depende de onde o sinal
        // termina dentro do seu ciclo; o extremo e a estatistica
        // significativa.
        double cristaMax, derivadaMax, razaoMax, ataqueMin;
    };

    // Processa um sinal inteiro com a mesma cadencia do plugin:
    // updateCore() uma vez por bloco, analyse() uma vez por amostra.
    Resultado processa (const std::vector<double>& x,
                        AdaptiveController::Config cfg)
    {
        CompressorCore      core;
        AdaptiveController  ad;

        core.prepare (FS);
        ad.prepare (FS);
        ad.setConfig (cfg);

        double pico = 0.0, somaSq = 0.0;
        double cristaMax = 0.0, derivadaMax = 0.0;
        double razaoMax  = 0.0, ataqueMin   = 1.0e9;
        const int N = static_cast<int> (x.size());

        for (int inicio = 0; inicio < N; inicio += BLK)
        {
            ad.updateCore (core);                       // uma vez por bloco

            razaoMax  = std::max (razaoMax,  ad.getRatio());
            ataqueMin = std::min (ataqueMin, ad.getAttackMs());

            const int fim = std::min (inicio + BLK, N);

            for (int n = inicio; n < fim; ++n)
            {
                const double det  = std::abs (x[n]);
                const double g    = core.nextGain (det);
                const double y    = x[n] * g;

                ad.analyse (det, g);                    // uma vez por amostra

                cristaMax   = std::max (cristaMax,   ad.getCrestFactorDb());
                derivadaMax = std::max (derivadaMax, ad.getSlopeDbPerMs());

                const double ay = std::abs (y);
                if (ay > pico) pico = ay;
                somaSq += y * y;
            }
        }

        Resultado r;
        r.limiarDb  = ad.getThresholdDb();
        r.razao     = ad.getRatio();
        r.ataqueMs  = ad.getAttackMs();
        r.makeupDb  = ad.getMakeupDb();
        r.mediaDb   = ad.getMeanLevelDb();
        r.desvioDb  = ad.getStdDevDb();
        r.cristaDb  = ad.getCrestFactorDb();
        r.derivada  = ad.getSlopeDbPerMs();
        r.picoSaida = 20.0 * std::log10 (pico + 1e-12);
        r.rmsSaida  = 20.0 * std::log10 (std::sqrt (somaSq / N) + 1e-12);
        r.cristaMax   = cristaMax;
        r.derivadaMax = derivadaMax;
        r.razaoMax    = razaoMax;
        r.ataqueMin   = ataqueMin;
        return r;
    }

    // Senoide de amplitude constante.
    std::vector<double> senoide (double amp, double f, double dur)
    {
        const int N = static_cast<int> (dur * FS);
        std::vector<double> x (N);
        for (int n = 0; n < N; ++n)
            x[n] = amp * std::sin (2.0 * kPi * f * n / FS);
        return x;
    }

    // Trem de impulsos percussivos: fator de crista alto.
    std::vector<double> percussivo (double amp, double dur)
    {
        const int N = static_cast<int> (dur * FS);
        std::vector<double> x (N);
        const int periodo = static_cast<int> (0.25 * FS);     // 4 golpes/s
        for (int n = 0; n < N; ++n)
        {
            const int    k    = n % periodo;
            const double env  = std::exp (-k / (0.010 * FS)); // decai em 10 ms
            x[n] = amp * env * std::sin (2.0 * kPi * 220.0 * n / FS);
        }
        return x;
    }

    void linha() { std::printf ("  %s\n", std::string (68, '-').c_str()); }
}

int main()
{
    std::printf ("\n=== VERIFICACAO DE SANIDADE -- AdaptiveController ===\n\n");

    // =================================================================
    //  MODO 1 -- limiar adaptativo
    //  O limiar deve acompanhar o nivel do sinal.
    // =================================================================
    std::printf ("MODO 1 -- LIMIAR ADAPTATIVO\n");
    std::printf ("  O limiar deve subir junto com o nivel do sinal.\n\n");
    std::printf ("  %-18s %12s %10s %10s %10s\n",
                 "Sinal", "Nivel (dBFS)", "media", "desvio", "T (dBFS)");
    linha();

    {
        AdaptiveController::Config c;
        c.adaptiveThreshold = true;

        const double amps[] = { 0.02, 0.10, 0.50 };
        for (double a : amps)
        {
            auto r = processa (senoide (a, 440.0, 3.0), c);
            std::printf ("  senoide a=%.2f   %12.2f %10.2f %10.2f %10.2f\n",
                         a, 20.0 * std::log10 (a), r.mediaDb, r.desvioDb,
                         r.limiarDb);
        }
    }

    // =================================================================
    //  MODO 2 -- razao pelo fator de crista
    //  Material percussivo tem crista alta e deve receber razao maior.
    // =================================================================
    std::printf ("\nMODO 2 -- RAZAO PELO FATOR DE CRISTA\n");
    std::printf ("  Percussivo (crista alta) deve receber razao maior.\n\n");
    std::printf ("  %-18s %14s %12s %10s\n",
                 "Sinal", "crista max", "crista fim", "R max");
    linha();

    {
        AdaptiveController::Config c;
        c.adaptiveRatio = true;

        auto rs = processa (senoide (0.5, 440.0, 3.0), c);
        std::printf ("  senoide           %14.2f %12.2f %10.2f\n",
                     rs.cristaMax, rs.cristaDb, rs.razaoMax);

        auto rp = processa (percussivo (0.9, 3.0), c);
        std::printf ("  percussivo        %14.2f %12.2f %10.2f\n",
                     rp.cristaMax, rp.cristaDb, rp.razaoMax);

        std::printf ("\n  Senoide pura tem fator de crista teorico de "
                     "3,01 dB (20*log10(raiz(2))).\n");
    }

    // =================================================================
    //  MODO 3 -- ataque pela derivada do envelope
    //  Transientes abruptos devem encurtar o tempo de ataque.
    // =================================================================
    std::printf ("\nMODO 3 -- ATAQUE PELA DERIVADA DO ENVELOPE\n");
    std::printf ("  Transiente abrupto deve encurtar o ataque.\n\n");
    std::printf ("  %-18s %18s %14s\n",
                 "Sinal", "derivada max dB/ms", "tau_A min (ms)");
    linha();

    {
        AdaptiveController::Config c;
        c.adaptiveAttack = true;

        auto rs = processa (senoide (0.5, 440.0, 3.0), c);
        std::printf ("  senoide           %18.3f %14.2f\n",
                     rs.derivadaMax, rs.ataqueMin);

        auto rp = processa (percussivo (0.9, 3.0), c);
        std::printf ("  percussivo        %18.3f %14.2f\n",
                     rp.derivadaMax, rp.ataqueMin);
    }

    // =================================================================
    //  MODO 4 -- compensacao automatica de ganho
    //  O nivel eficaz de saida deve aproximar-se do de entrada,
    //  independentemente do nivel de entrada.
    // =================================================================
    std::printf ("\nMODO 4 -- COMPENSACAO AUTOMATICA DE GANHO\n");
    std::printf ("  O RMS de saida deve acompanhar o de entrada.\n\n");
    std::printf ("  %-14s %12s %12s %10s %10s\n",
                 "Sinal", "RMS ent.", "RMS saida", "erro", "M (dB)");
    linha();

    {
        AdaptiveController::Config c;
        c.autoMakeup = true;

        const double amps[] = { 0.10, 0.30, 0.70 };
        for (double a : amps)
        {
            auto x = senoide (a, 440.0, 6.0);
            auto r = processa (x, c);

            double s = 0.0;
            for (double v : x) s += v * v;
            const double rmsIn = 20.0 * std::log10 (std::sqrt (s / x.size()));

            std::printf ("  a=%.2f        %12.3f %12.3f %10.3f %10.3f\n",
                         a, rmsIn, r.rmsSaida, r.rmsSaida - rmsIn, r.makeupDb);
        }
    }

    // =================================================================
    //  COMPARACAO -- M fixo contra M automatico
    //  Com M fixo, o pico ultrapassa 0 dBFS (resultado do Capitulo 8).
    // =================================================================
    std::printf ("\nM FIXO (+6 dB) CONTRA M AUTOMATICO\n");
    std::printf ("  Com M fixo, o pico de saida ultrapassa 0 dBFS.\n\n");
    std::printf ("  %-22s %14s %12s\n", "Configuracao", "pico (dBFS)", "M (dB)");
    linha();

    {
        auto x = senoide (0.8, 440.0, 4.0);

        AdaptiveController::Config cf;              // manual, M = +6 dB
        auto rf = processa (x, cf);
        std::printf ("  M fixo = +6 dB         %14.3f %12.2f\n",
                     rf.picoSaida, rf.makeupDb);

        AdaptiveController::Config ca;
        ca.autoMakeup = true;
        auto ra = processa (x, ca);
        std::printf ("  M automatico           %14.3f %12.2f\n",
                     ra.picoSaida, ra.makeupDb);
    }

    // =================================================================
    //  TODOS OS MODOS SIMULTANEOS -- coerencia parametrica
    // =================================================================
    std::printf ("\nQUATRO MODOS SIMULTANEOS\n");
    std::printf ("  Verificar coerencia e ausencia de valores absurdos.\n\n");

    {
        AdaptiveController::Config c;
        c.adaptiveThreshold = true;
        c.adaptiveRatio     = true;
        c.adaptiveAttack    = true;
        c.autoMakeup        = true;

        auto r = processa (percussivo (0.9, 5.0), c);
        std::printf ("  T ........... %8.2f dBFS\n", r.limiarDb);
        std::printf ("  R ........... %8.2f : 1\n",  r.razao);
        std::printf ("  tau_A ....... %8.2f ms\n",   r.ataqueMs);
        std::printf ("  M ........... %8.2f dB\n",   r.makeupDb);
        std::printf ("  pico saida .. %8.3f dBFS\n", r.picoSaida);
    }

    std::printf ("\n");
    return 0;
}
