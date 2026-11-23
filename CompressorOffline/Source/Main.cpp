#include <JuceHeader.h>
#include "../../NewProject/Source/CompressorCore.h"
#include "../../NewProject/Source/AdaptiveController.h"

#include <iostream>
#include <sstream>
#include <iomanip>
#include <string>
#include <vector>
#include <cmath>
#include <algorithm>

namespace
{
    double linearToDb (double x) noexcept
    {
        return 20.0 * std::log10 (x + 1.0e-9);
    }

    juce::String num (double valor, int casas)
    {
        return juce::String (valor, casas);
    }

    void escrever (const juce::String& texto)
    {
        std::cout << texto.toStdString() << std::endl;
    }

    void imprimirUso()
    {
        juce::String t;
        t << "\n";
        t << "CompressorOffline - processamento offline do nucleo validado\n";
        t << "\n";
        t << "Uso:\n";
        t << "  CompressorOffline <entrada.wav> <saida.wav> [T R ataque release joelho makeup] [opcoes]\n";
        t << "\n";
        t << "Parametros (opcionais, todos os seis ou nenhum, nesta ordem):\n";
        t << "  T        limiar em dBFS      (padrao -12)\n";
        t << "  R        razao               (padrao 4)\n";
        t << "  ataque   constante em ms     (padrao 10)\n";
        t << "  release  constante em ms     (padrao 100)\n";
        t << "  joelho   largura em dB       (padrao 6)\n";
        t << "  makeup   ganho em dB         (padrao 6)\n";
        t << "\n";
        t << "Modos adaptativos (podem vir em qualquer posicao apos a saida):\n";
        t << "  --adapt-threshold   Modo 1: limiar pela media e desvio padrao\n";
        t << "  --adapt-ratio       Modo 2: razao pelo fator de crista\n";
        t << "  --adapt-attack      Modo 3: ataque pela derivada do envelope\n";
        t << "  --auto-makeup       Modo 4: compensacao automatica de ganho\n";
        t << "  --adapt-all         liga os quatro\n";
        t << "\n";
        t << "Opcoes:\n";
        t << "  --bloco N      amostras por bloco de processamento (padrao 512)\n";
        t << "  --decimar N    passo de gravacao da telemetria     (padrao 16)\n";
        t << "\n";
        t << "Os parametros manuais continuam valendo para os modos DESLIGADOS.\n";
        t << "Com os quatro desligados o resultado e identico ao da versao\n";
        t << "anterior deste programa, amostra a amostra.\n";
        t << "\n";
        t << "Arquivos gravados:\n";
        t << "  <saida>.wav         audio processado\n";
        t << "  <saida>.csv         amostras de saida e envelope de ganho\n";
        t << "  <saida>_adapt.csv   telemetria dos estimadores e parametros\n";
        escrever (t);
    }
}

int main (int argc, char* argv[])
{
    if (argc < 3)
    {
        imprimirUso();
        return 1;
    }

    const juce::File arquivoEntrada { juce::String (argv[1]) };
    const juce::File arquivoSaida   { juce::String (argv[2]) };

    double T  = -12.0;
    double R  =   4.0;
    double tA =  10.0;
    double tR = 100.0;
    double W  =   6.0;
    double M  =   6.0;

    bool modoLimiar = false;
    bool modoRazao  = false;
    bool modoAtaque = false;
    bool modoMakeup = false;

    int tamanhoBloco = 512;
    int decimacao    =  16;

    // -----------------------------------------------------------------
    //  Separacao entre chaves e parametros numericos.
    //
    //  As chaves podem aparecer em qualquer posicao apos o arquivo de
    //  saida; os parametros numericos, se presentes, devem ser os seis,
    //  na ordem documentada. A separacao em duas passagens evita impor
    //  ordem entre as duas classes de argumento.
    // -----------------------------------------------------------------
    std::vector<juce::String> numericos;

    for (int i = 3; i < argc; ++i)
    {
        const juce::String arg { juce::String (argv[i]) };

        if (! arg.startsWith ("--"))
        {
            numericos.push_back (arg);
            continue;
        }

        if      (arg == "--adapt-threshold") modoLimiar = true;
        else if (arg == "--adapt-ratio")     modoRazao  = true;
        else if (arg == "--adapt-attack")    modoAtaque = true;
        else if (arg == "--auto-makeup")     modoMakeup = true;
        else if (arg == "--adapt-all")
        {
            modoLimiar = modoRazao = modoAtaque = modoMakeup = true;
        }
        else if (arg == "--bloco" || arg == "--decimar")
        {
            if (i + 1 >= argc)
            {
                escrever ("ERRO: " + arg + " exige um valor.");
                return 1;
            }

            const int valor = juce::String (argv[++i]).getIntValue();

            if (valor < 1)
            {
                escrever ("ERRO: o valor de " + arg + " deve ser maior que zero.");
                return 1;
            }

            if (arg == "--bloco") tamanhoBloco = valor;
            else                  decimacao    = valor;
        }
        else
        {
            escrever ("ERRO: opcao desconhecida: " + arg);
            imprimirUso();
            return 1;
        }
    }

    if (numericos.size() == 6)
    {
        T  = numericos[0].getDoubleValue();
        R  = numericos[1].getDoubleValue();
        tA = numericos[2].getDoubleValue();
        tR = numericos[3].getDoubleValue();
        W  = numericos[4].getDoubleValue();
        M  = numericos[5].getDoubleValue();
    }
    else if (! numericos.empty())
    {
        escrever ("ERRO: informe os seis parametros ou nenhum.");
        imprimirUso();
        return 1;
    }

    if (! arquivoEntrada.existsAsFile())
    {
        escrever ("ERRO: arquivo de entrada nao encontrado:\n  "
                   + arquivoEntrada.getFullPathName());
        return 1;
    }

    if (R < 1.0)
    {
        escrever ("ERRO: a razao deve ser maior ou igual a 1.");
        return 1;
    }

    if (tA <= 0.0 || tR <= 0.0)
    {
        escrever ("ERRO: as constantes de tempo devem ser maiores que zero.");
        return 1;
    }

    juce::AudioFormatManager gerenciador;
    gerenciador.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> leitor (gerenciador.createReaderFor (arquivoEntrada));

    if (leitor == nullptr)
    {
        escrever ("ERRO: formato de audio nao reconhecido.");
        return 1;
    }

    const int    numCanais   = static_cast<int> (leitor->numChannels);
    const int    numAmostras = static_cast<int> (leitor->lengthInSamples);
    const double fs          = leitor->sampleRate;

    if (numAmostras < 1 || numCanais < 1)
    {
        escrever ("ERRO: arquivo de audio vazio.");
        return 1;
    }

    juce::AudioBuffer<float> entrada (numCanais, numAmostras);
    entrada.clear();
    leitor->read (&entrada, 0, numAmostras, 0, true, true);
    leitor.reset();

    CompressorCore      nucleo;
    AdaptiveController  adaptativo;

    nucleo.prepare (fs);
    adaptativo.prepare (fs);

    // -----------------------------------------------------------------
    //  Configuracao, montada uma unica vez: o programa nao altera
    //  parametros durante a execucao, ao contrario do plugin, em que
    //  o usuario pode move-los.
    //
    //  A ordem de escrita no nucleo e a mesma do plugin. O updateCore
    //  escreve APENAS os parametros cujo modo esteja ligado; os demais
    //  conserva como vieram do Config. Por isso o Config carrega os
    //  seis valores manuais: ele e a referencia, e a adaptacao e a
    //  excecao. Com os quatro modos desligados o nucleo recebe
    //  exatamente os valores da linha de comando, e o resultado
    //  coincide, amostra a amostra, com o da versao anterior.
    // -----------------------------------------------------------------
    AdaptiveController::Config cfg;
    cfg.thresholdDb = T;
    cfg.ratio       = R;
    cfg.attackMs    = tA;
    cfg.releaseMs   = tR;
    cfg.kneeDb      = W;
    cfg.makeupDb    = M;

    cfg.adaptiveThreshold = modoLimiar;
    cfg.adaptiveRatio     = modoRazao;
    cfg.adaptiveAttack    = modoAtaque;
    cfg.autoMakeup        = modoMakeup;

    adaptativo.setConfig (cfg);

    const int canaisSaida = juce::jmin (numCanais, 2);

    std::vector<double> saidaL   (static_cast<size_t> (numAmostras), 0.0);
    std::vector<double> saidaR   (static_cast<size_t> (numAmostras), 0.0);
    std::vector<double> envelope (static_cast<size_t> (numAmostras), 0.0);

    const float* canalL = entrada.getReadPointer (0);
    const float* canalR = (numCanais > 1) ? entrada.getReadPointer (1) : nullptr;

    // -----------------------------------------------------------------
    //  Telemetria.
    //
    //  Gravada em arquivo proprio, e nao no CSV principal, por duas
    //  razoes. A primeira e de compatibilidade: os scripts de analise
    //  do Capitulo 8 leem o CSV principal pela posicao das colunas, e
    //  acrescentar colunas a ele invalidaria todos eles. A segunda e de
    //  tamanho: a telemetria tem dez colunas, e grava-la a cada amostra
    //  produziria arquivo de centenas de megabytes sem ganho de
    //  informacao -- as grandezas estimadas variam com constantes de
    //  tempo de 30 ms a 1 s, de modo que o passo de decimacao padrao,
    //  de dezesseis amostras, as amostra com folga de duas ordens de
    //  grandeza.
    //
    //  A excecao a observar e a derivada do envelope do Modo 3, cujo
    //  valor retido decai com constante de 80 ms. Mesmo nela o erro de
    //  decimacao e inferior a meio por cento.
    // -----------------------------------------------------------------
    struct Telemetria
    {
        int    n;
        double t;
        double limiarDb;
        double razao;
        double ataqueMs;
        double makeupDb;
        double mediaDb;
        double desvioDb;
        double cristaDb;
        double derivada;
        bool   aquecido;
    };

    std::vector<Telemetria> telemetria;
    telemetria.reserve (static_cast<size_t> (numAmostras / decimacao + 1));

    // -----------------------------------------------------------------
    //  Laco de processamento, em blocos.
    //
    //  O processamento em blocos nao e detalhe de implementacao: e
    //  condicao para que a medida reproduza o comportamento do plugin.
    //  O updateCore e chamado UMA VEZ POR BLOCO, tal como no
    //  processBlock, de modo que os parametros adaptados sao mantidos
    //  constantes ao longo do bloco. Processar o arquivo inteiro em
    //  uma unica passagem produziria adaptacao de granularidade
    //  distinta da que o plugin realiza, e os resultados do Capitulo 9
    //  nao descreveriam o sistema em operacao.
    // -----------------------------------------------------------------
    for (int inicio = 0; inicio < numAmostras; inicio += tamanhoBloco)
    {
        const int fim = juce::jmin (inicio + tamanhoBloco, numAmostras);

        adaptativo.updateCore (nucleo);

        for (int n = inicio; n < fim; ++n)
        {
            const size_t i = static_cast<size_t> (n);

            const double xL = static_cast<double> (canalL[n]);
            const double xR = (canalR != nullptr) ? static_cast<double> (canalR[n]) : xL;

            const double detector = std::max (std::abs (xL), std::abs (xR));

            const double ganho = nucleo.nextGain (detector);

            //  O controlador OBSERVA; quem escreve no nucleo e o
            //  updateCore, acima, uma vez por bloco.
            adaptativo.analyse (detector, ganho);

            saidaL[i]   = xL * ganho;
            saidaR[i]   = xR * ganho;
            envelope[i] = nucleo.getGainReductionDb();

            if (n % decimacao == 0)
            {
                Telemetria t;
                t.n        = n;
                t.t        = n / fs;
                t.limiarDb = adaptativo.getThresholdDb();
                t.razao    = adaptativo.getRatio();
                t.ataqueMs = adaptativo.getAttackMs();
                t.makeupDb = adaptativo.getMakeupDb();
                t.mediaDb  = adaptativo.getMeanLevelDb();
                t.desvioDb = adaptativo.getStdDevDb();
                t.cristaDb = adaptativo.getCrestFactorDb();
                t.derivada = adaptativo.getSlopeDbPerMs();
                t.aquecido = adaptativo.isWarmedUp();
                telemetria.push_back (t);
            }
        }
    }

    juce::AudioBuffer<float> bufferSaida (canaisSaida, numAmostras);

    for (int n = 0; n < numAmostras; ++n)
    {
        const size_t i = static_cast<size_t> (n);

        bufferSaida.setSample (0, n, static_cast<float> (saidaL[i]));

        if (canaisSaida > 1)
            bufferSaida.setSample (1, n, static_cast<float> (saidaR[i]));
    }

    arquivoSaida.deleteFile();

    std::unique_ptr<juce::FileOutputStream> fluxo = arquivoSaida.createOutputStream();

    if (fluxo == nullptr)
    {
        escrever ("ERRO: nao foi possivel gravar o arquivo de saida.");
        return 1;
    }

    {
        juce::WavAudioFormat formatoWav;

        std::unique_ptr<juce::AudioFormatWriter> escritor (
            formatoWav.createWriterFor (fluxo.get(), fs,
                                        static_cast<unsigned int> (canaisSaida),
                                        24, {}, 0));

        if (escritor == nullptr)
        {
            escrever ("ERRO: nao foi possivel criar o escritor WAV.");
            return 1;
        }

        fluxo.release();
        escritor->writeFromAudioSampleBuffer (bufferSaida, 0, numAmostras);
        escritor.reset();
    }

    const juce::File arquivoCsv = arquivoSaida.withFileExtension ("csv");
    arquivoCsv.deleteFile();

    {
        std::ostringstream oss;
        oss << std::setprecision (12);

        oss << (canaisSaida > 1 ? "saida_L,saida_R,ganho_dB\n" : "saida,ganho_dB\n");

        for (int n = 0; n < numAmostras; ++n)
        {
            const size_t i = static_cast<size_t> (n);

            oss << saidaL[i];

            if (canaisSaida > 1)
                oss << ',' << saidaR[i];

            oss << ',' << envelope[i] << '\n';
        }

        const std::string conteudo = oss.str();

        juce::FileOutputStream fluxoCsv (arquivoCsv);

        if (! fluxoCsv.openedOk())
        {
            escrever ("ERRO: nao foi possivel gravar o CSV.");
            return 1;
        }

        fluxoCsv.write (conteudo.data(), conteudo.size());
        fluxoCsv.flush();
    }

    // -----------------------------------------------------------------
    //  CSV da telemetria.
    // -----------------------------------------------------------------
    const juce::File arquivoAdapt =
        arquivoSaida.getParentDirectory()
                    .getChildFile (arquivoSaida.getFileNameWithoutExtension()
                                   + "_adapt.csv");
    arquivoAdapt.deleteFile();

    {
        std::ostringstream oss;
        oss << std::setprecision (10);

        oss << "n,t_s,T_db,R,tauA_ms,M_db,"
            << "media_db,desvio_db,crista_db,derivada_db_ms,aquecido\n";

        for (const Telemetria& t : telemetria)
        {
            oss << t.n        << ','
                << t.t        << ','
                << t.limiarDb << ','
                << t.razao    << ','
                << t.ataqueMs << ','
                << t.makeupDb << ','
                << t.mediaDb  << ','
                << t.desvioDb << ','
                << t.cristaDb << ','
                << t.derivada << ','
                << (t.aquecido ? 1 : 0) << '\n';
        }

        const std::string conteudo = oss.str();

        juce::FileOutputStream fluxoAdapt (arquivoAdapt);

        if (! fluxoAdapt.openedOk())
        {
            escrever ("ERRO: nao foi possivel gravar o CSV da telemetria.");
            return 1;
        }

        fluxoAdapt.write (conteudo.data(), conteudo.size());
        fluxoAdapt.flush();
    }

    double picoEntrada = 0.0, somaQuadEntrada = 0.0;
    double picoSaida   = 0.0, somaQuadSaida   = 0.0;
    double ganhoMinimo = 0.0, somaGanho       = 0.0;

    for (int n = 0; n < numAmostras; ++n)
    {
        const size_t i = static_cast<size_t> (n);

        const double xL = static_cast<double> (canalL[n]);
        const double xR = (canalR != nullptr) ? static_cast<double> (canalR[n]) : xL;
        const double ein = std::max (std::abs (xL), std::abs (xR));

        picoEntrada = std::max (picoEntrada, ein);
        somaQuadEntrada += ein * ein;

        const double eout = (canaisSaida > 1)
                              ? std::max (std::abs (saidaL[i]), std::abs (saidaR[i]))
                              : std::abs (saidaL[i]);

        picoSaida = std::max (picoSaida, eout);
        somaQuadSaida += eout * eout;

        ganhoMinimo = std::min (ganhoMinimo, envelope[i]);
        somaGanho  += envelope[i];
    }

    const double rmsEntrada = std::sqrt (somaQuadEntrada / numAmostras);
    const double rmsSaida   = std::sqrt (somaQuadSaida   / numAmostras);

    const double drEntrada = linearToDb (picoEntrada) - linearToDb (rmsEntrada);
    const double drSaida   = linearToDb (picoSaida)   - linearToDb (rmsSaida);

    const double alphaA = std::exp (-1.0 / (fs * tA * 1.0e-3));
    const double alphaR = std::exp (-1.0 / (fs * tR * 1.0e-3));

    const bool algumModo = modoLimiar || modoRazao || modoAtaque || modoMakeup;

    juce::String r;

    r << "\n";
    r << "=== ENTRADA ===\n";
    r << "  arquivo .......... " << arquivoEntrada.getFileName() << "\n";
    r << "  taxa ............. " << num (fs, 0) << " Hz\n";
    r << "  canais ........... " << juce::String (numCanais) << "\n";
    r << "  amostras ......... " << juce::String (numAmostras)
      << "  (" << num (numAmostras / fs, 3) << " s)\n";
    r << "  bloco ............ " << juce::String (tamanhoBloco) << " amostras  ("
      << num (1000.0 * tamanhoBloco / fs, 3) << " ms)\n";
    r << "\n";

    r << "=== PARAMETROS MANUAIS ===\n";
    r << "  T ................ " << num (T, 2) << " dBFS\n";
    r << "  R ................ " << num (R, 2) << " : 1\n";
    r << "  W ................ " << num (W, 2) << " dB\n";
    r << "  M ................ " << num (M, 2) << " dB\n";
    r << "  tau_A ............ " << num (tA, 2) << " ms\n";
    r << "  tau_R ............ " << num (tR, 2) << " ms\n";
    r << "  alpha_A .......... " << num (alphaA, 8) << "\n";
    r << "  alpha_R .......... " << num (alphaR, 8) << "\n";
    r << "\n";

    r << "=== MODOS ADAPTATIVOS ===\n";
    r << "  Modo 1  limiar ... " << (modoLimiar ? "LIGADO" : "desligado") << "\n";
    r << "  Modo 2  razao .... " << (modoRazao  ? "LIGADO" : "desligado") << "\n";
    r << "  Modo 3  ataque ... " << (modoAtaque ? "LIGADO" : "desligado") << "\n";
    r << "  Modo 4  makeup ... " << (modoMakeup ? "LIGADO" : "desligado") << "\n";

    if (algumModo)
    {
        r << "\n";
        r << "  valores em vigor ao fim do processamento:\n";
        r << "    T ............ " << num (adaptativo.getThresholdDb(), 3) << " dBFS\n";
        r << "    R ............ " << num (adaptativo.getRatio(), 3)       << " : 1\n";
        r << "    tau_A ........ " << num (adaptativo.getAttackMs(), 3)    << " ms\n";
        r << "    M ............ " << num (adaptativo.getMakeupDb(), 3)    << " dB\n";
        r << "\n";
        r << "  estimadores ao fim do processamento:\n";
        r << "    media ........ " << num (adaptativo.getMeanLevelDb(), 3)  << " dB\n";
        r << "    desvio ....... " << num (adaptativo.getStdDevDb(), 3)     << " dB\n";
        r << "    crista ....... " << num (adaptativo.getCrestFactorDb(), 3)<< " dB\n";
        r << "    derivada ..... " << num (adaptativo.getSlopeDbPerMs(), 3) << " dB/ms\n";
    }
    else
    {
        r << "\n";
        r << "  Nenhum modo ligado: o nucleo recebeu os parametros manuais\n";
        r << "  acima, e o resultado coincide com o da versao anterior.\n";
    }

    r << "\n";

    r << "=== METRICAS ===\n";
    r << "  pico entrada ..... " << num (linearToDb (picoEntrada), 3) << " dBFS\n";
    r << "  pico saida ....... " << num (linearToDb (picoSaida), 3) << " dBFS\n";
    r << "  RMS  entrada ..... " << num (linearToDb (rmsEntrada), 3) << " dBFS\n";
    r << "  RMS  saida ....... " << num (linearToDb (rmsSaida), 3) << " dBFS\n";
    r << "  DR   entrada ..... " << num (drEntrada, 3) << " dB\n";
    r << "  DR   saida ....... " << num (drSaida, 3) << " dB\n";
    r << "  reducao de DR .... " << num (drEntrada - drSaida, 3) << " dB\n";
    r << "  ganho minimo ..... " << num (ganhoMinimo, 3) << " dB\n";
    r << "  ganho medio ...... " << num (somaGanho / numAmostras, 3) << " dB\n";
    r << "\n";

    r << "=== ARQUIVOS GRAVADOS ===\n";
    r << "  " << arquivoSaida.getFullPathName() << "\n";
    r << "  " << arquivoCsv.getFullPathName() << "\n";
    r << "  " << arquivoAdapt.getFullPathName()
      << "   (" << juce::String (static_cast<int> (telemetria.size()))
      << " linhas, passo de " << juce::String (decimacao) << " amostras)\n";

    escrever (r);

    return 0;
}
