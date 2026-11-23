// =====================================================================
//  Benchmark.cpp — medicao de desempenho do nucleo de processamento
//
//  Mede o custo computacional de CompressorCore isoladamente, sem
//  interferencia de leitura de arquivo, conversao de formato ou
//  qualquer servico do framework. O que se avalia e exclusivamente o
//  laco de processamento por amostra.
//
//  O programa reproduz a estrutura empregada em processBlock: para
//  cada amostra calcula o detector por maximo entre canais, obtem o
//  ganho pelo nucleo e aplica o resultado aos dois canais.
//
//  O programa executa DUAS medicoes na mesma sessao: a primeira com o
//  nucleo isolado, a segunda com a camada adaptativa habilitada nos
//  quatro modos. A diferenca entre as duas constitui o custo da
//  adaptacao. Medi-las em execucoes separadas seria menos defensavel:
//  a frequencia de operacao do processador varia entre execucoes, e a
//  diferenca medida poderia exprimir essa variacao, e nao o custo do
//  codigo acrescentado.
//
//  Metricas reportadas, por tamanho de bloco:
//
//    tempo por bloco     mediana e pior caso entre todas as iteracoes
//    prazo do bloco      duracao de audio que o bloco representa
//    ocupacao            razao entre os dois, em porcentagem
//
//  Em processamento de audio em tempo real a grandeza determinante e
//  o PIOR CASO, nao a media: a perda de um unico prazo produz falha
//  audivel. Por essa razao o programa reporta tambem o percentil 99.
//
//  COMPILACAO
//    Nao depende do JUCE. No Prompt de Comando do Desenvolvedor para
//    Visual Studio, na pasta que contem este arquivo:
//
//      cl /O2 /EHsc /std:c++17 Benchmark.cpp CompressorCore.cpp AdaptiveController.cpp /Fe:Benchmark.exe
//
//    A opcao /O2 e obrigatoria. Medicao em configuracao Debug nao tem
//    significado: o compilador desativa otimizacoes e o resultado
//    excede em uma ordem de grandeza o do binario distribuido.
//
//  USO
//    A taxa de amostragem e lida da linha de comando; o padrao e
//    44100 Hz. A metodologia do trabalho exige verificacao nas duas
//    taxas usuais, de modo que basta executar duas vezes:
//
//      Benchmark.exe              -> 44100 Hz
//      Benchmark.exe 48000        -> 48000 Hz
//
//    Nao ha constante a editar nem recompilacao entre as duas: o
//    prazo do bloco, os coeficientes do nucleo e a frequencia do
//    sinal de ensaio derivam todos do valor informado.
// =====================================================================

#include "CompressorCore.h"
#include "AdaptiveController.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace
{
    // Definida explicitamente: kPi nao e garantida pelo padrao e o
    // compilador da Microsoft so a expoe com _USE_MATH_DEFINES.
    constexpr double kPi = 3.14159265358979323846;

    constexpr double kTaxaPadrao   = 44100.0; // usada se nada for informado
    constexpr int    kSegundos     = 10;      // audio simulado por rodada
    constexpr int    kRepeticoes   = 5;       // rodadas por tamanho de bloco

    const int kBlocos[] = { 32, 64, 128, 256, 512, 1024 };

    // Sinal de ensaio: senoide de 1 kHz modulada em amplitude, de modo
    // que o nucleo alterne entre os ramos de ataque e de liberacao ao
    // longo da medicao. Medir com sinal constante subestimaria o custo,
    // pois exercitaria sempre o mesmo caminho de codigo.
    void preencherSinal (std::vector<float>& L, std::vector<float>& R, double fs)
    {
        const size_t n = L.size();
        for (size_t i = 0; i < n; ++i)
        {
            const double t   = static_cast<double> (i) / fs;
            const double env = 0.55 + 0.45 * std::sin (2.0 * kPi * 1.7 * t);
            const double s   = env * std::sin (2.0 * kPi * 1000.0 * t);
            L[i] = static_cast<float> (s);
            R[i] = static_cast<float> (s * 0.9);
        }
    }

    double percentil (std::vector<double> v, double p)
    {
        if (v.empty()) return 0.0;
        std::sort (v.begin(), v.end());
        const size_t idx = static_cast<size_t> (p * (v.size() - 1));
        return v[idx];
    }
}

int main (int argc, char** argv)
{
    //  Taxa de amostragem pela linha de comando. Valor fora da faixa
    //  plausivel e recusado: um erro de digitacao produziria uma tabela
    //  de numeros sem significado, e nada no relatorio denunciaria isso.
    double kSampleRate = kTaxaPadrao;
    if (argc > 1)
    {
        const double v = std::atof (argv[1]);
        if (v < 8000.0 || v > 384000.0)
        {
            std::printf ("\n  Taxa de amostragem invalida: %s\n"
                         "  Informe um valor entre 8000 e 384000 Hz.\n"
                         "  Exemplos:  Benchmark.exe        (44100 Hz)\n"
                         "             Benchmark.exe 48000\n\n", argv[1]);
            return 1;
        }
        kSampleRate = v;
    }

    const size_t nAmostras = static_cast<size_t> (kSampleRate) * kSegundos;

    std::vector<float> canalL (nAmostras), canalR (nAmostras);
    preencherSinal (canalL, canalR, kSampleRate);

    //  Resultado de uma passagem de medicao.
    struct Resultado
    {
        double mediana[8];
        double p99[8];
        double p999[8];
        double pior[8];
        double porAmostra;
        double totalUs;
    };

    double somaVerificacao = 0.0;

    //  Executa a bateria completa, com ou sem a camada adaptativa.
    //
    //  Com adaptativo == true o laco reproduz o processBlock do plugin:
    //  updateCore uma vez por bloco, analyse a cada amostra. A
    //  cronometragem inclui as duas chamadas, pois ambas integram o
    //  custo que o hospedeiro paga.
    auto medir = [&] (bool adaptativo) -> Resultado
    {
        Resultado r {};

        CompressorCore     core;
        AdaptiveController adapt;

        core.prepare (kSampleRate);
        adapt.prepare (kSampleRate);

        AdaptiveController::Config cfg;
        cfg.thresholdDb = -12.0; cfg.ratio    =   4.0;
        cfg.attackMs    =  10.0; cfg.releaseMs = 100.0;
        cfg.kneeDb      =   6.0; cfg.makeupDb  =   6.0;
        cfg.adaptiveThreshold = adaptativo;
        cfg.adaptiveRatio     = adaptativo;
        cfg.adaptiveAttack    = adaptativo;
        cfg.autoMakeup        = adaptativo;
        adapt.setConfig (cfg);

        core.setParameters (-12.0, 4.0, 10.0, 100.0, 6.0, 6.0);

        int idx = 0;
        for (int b : kBlocos)
        {
            const size_t nBlocos = nAmostras / static_cast<size_t> (b);
            std::vector<double> tempos;
            tempos.reserve (nBlocos * kRepeticoes);

            for (int rep = 0; rep < kRepeticoes; ++rep)
            {
                core.reset();
                adapt.reset();

                for (size_t blk = 0; blk < nBlocos; ++blk)
                {
                    float* pL = canalL.data() + blk * static_cast<size_t> (b);
                    float* pR = canalR.data() + blk * static_cast<size_t> (b);

                    const auto t0 = std::chrono::steady_clock::now();

                    if (adaptativo)
                        adapt.updateCore (core);

                    for (int i = 0; i < b; ++i)
                    {
                        const double det = std::max (std::abs (static_cast<double> (pL[i])),
                                                     std::abs (static_cast<double> (pR[i])));
                        const double g = core.nextGain (det);

                        if (adaptativo)
                            adapt.analyse (det, g);

                        somaVerificacao += g * static_cast<double> (pL[i]);
                    }

                    const auto t1 = std::chrono::steady_clock::now();

                    tempos.push_back (std::chrono::duration<double, std::micro> (t1 - t0).count());
                }
            }

            r.mediana[idx] = percentil (tempos, 0.50);
            r.p99    [idx] = percentil (tempos, 0.99);
            r.p999   [idx] = percentil (tempos, 0.999);
            r.pior   [idx] = *std::max_element (tempos.begin(), tempos.end());
            ++idx;
        }

        //  Custo por amostra, em passagem unica, sem a sobrecarga de
        //  cronometragem por bloco. O updateCore e chamado na cadencia
        //  de bloco de 512 amostras, a mesma do laco acima.
        core.reset();
        adapt.reset();

        const auto u0 = std::chrono::steady_clock::now();
        for (size_t i = 0; i < nAmostras; ++i)
        {
            if (adaptativo && (i % 512) == 0)
                adapt.updateCore (core);

            const double det = std::max (std::abs (static_cast<double> (canalL[i])),
                                         std::abs (static_cast<double> (canalR[i])));
            const double g = core.nextGain (det);

            if (adaptativo)
                adapt.analyse (det, g);

            somaVerificacao += g * static_cast<double> (canalL[i]);
        }
        const auto u1 = std::chrono::steady_clock::now();

        r.totalUs    = std::chrono::duration<double, std::micro> (u1 - u0).count();
        r.porAmostra = r.totalUs * 1000.0 / static_cast<double> (nAmostras);

        return r;
    };

    std::printf ("\n=== DESEMPENHO DO NUCLEO DE PROCESSAMENTO ===\n");
    std::printf ("  taxa de amostragem .. %.0f Hz\n", kSampleRate);
    std::printf ("  audio por rodada .... %d s  (%zu amostras)\n", kSegundos, nAmostras);
    std::printf ("  rodadas por bloco ... %d\n", kRepeticoes);
    std::printf ("  canais .............. 2  (ganho comum)\n");
    std::printf ("  passagens ........... 2  (nucleo isolado e com adaptacao)\n\n");

    const Resultado base  = medir (false);
    const Resultado adapt = medir (true);

    const char* titulo[2] = { "NUCLEO ISOLADO", "COM CAMADA ADAPTATIVA" };
    const Resultado* res[2] = { &base, &adapt };

    for (int k = 0; k < 2; ++k)
    {
        std::printf ("  --- %s ---\n", titulo[k]);
        std::printf ("  %6s %10s %10s %10s %10s %10s %10s\n",
                     "Bloco", "mediana", "p99", "p99,9", "maximo", "prazo", "ocupacao");
        std::printf ("  %6s %10s %10s %10s %10s %10s %10s\n",
                     "", "(us)", "(us)", "(us)", "(us)", "(us)", "(%)");
        std::printf ("  %s\n",
                     "----------------------------------------------------------------------------");

        int idx = 0;
        for (int b : kBlocos)
        {
            const double prazo = static_cast<double> (b) / kSampleRate * 1.0e6;
            std::printf ("  %6d %10.3f %10.3f %10.3f %10.3f %10.1f %10.3f\n",
                         b, res[k]->mediana[idx], res[k]->p99[idx], res[k]->p999[idx],
                         res[k]->pior[idx], prazo, 100.0 * res[k]->p999[idx] / prazo);
            ++idx;
        }
        std::printf ("\n");
    }

    std::printf (
      "  A coluna de ocupacao toma o percentil 99,9 como referencia, e nao\n"
      "  o maximo absoluto. O maximo e reportado por transparencia, mas em\n"
      "  sistema operacional de uso geral ele registra preempcao do\n"
      "  escalonador --- a suspensao da aplicacao por uma interrupcao --- e\n"
      "  nao o custo do algoritmo. Isoladas essas ocorrencias, o percentil\n"
      "  99,9 expressa o pior caso atribuivel ao processamento.\n");

    const double duracaoUs = static_cast<double> (nAmostras) / kSampleRate * 1.0e6;

    std::printf ("\n=== CUSTO UNITARIO ===\n");
    std::printf ("  %-26s %12s %12s\n", "", "nucleo", "com adapt.");
    std::printf ("  %-26s %12.2f %12.2f\n", "tempo por amostra (ns)",
                 base.porAmostra, adapt.porAmostra);
    std::printf ("  %-26s %12.1f %12.1f\n", "fator de tempo real",
                 duracaoUs / base.totalUs, duracaoUs / adapt.totalUs);
    std::printf ("  %-26s %12.4f %12.4f\n", "ocupacao de um nucleo (%)",
                 100.0 * base.totalUs / duracaoUs, 100.0 * adapt.totalUs / duracaoUs);
    std::printf ("  %-26s %12.0f %12.0f\n", "instancias simultaneas",
                 std::floor (duracaoUs / base.totalUs),
                 std::floor (duracaoUs / adapt.totalUs));

    std::printf ("\n=== CUSTO DA CAMADA ADAPTATIVA ===\n");
    std::printf ("  acrescimo por amostra ... %.2f ns\n",
                 adapt.porAmostra - base.porAmostra);
    std::printf ("  acrescimo relativo ...... %.1f %%\n",
                 100.0 * (adapt.porAmostra / base.porAmostra - 1.0));
    std::printf ("  ocupacao total .......... %.4f %% de um nucleo\n",
                 100.0 * adapt.totalUs / duracaoUs);

    // Impede que o otimizador elimine o laco de medicao.
    std::printf ("\n  [verificacao: %.6e]\n\n", somaVerificacao);

    return 0;
}
