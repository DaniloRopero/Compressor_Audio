#pragma once

#include <JuceHeader.h>
#include "CompressorCore.h"
#include "AdaptiveController.h"

class CompressorAudioProcessor : public juce::AudioProcessor
{
public:
    CompressorAudioProcessor();
    ~CompressorAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

#ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;
#endif

    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram(int index) override;
    const juce::String getProgramName(int index) override;
    void changeProgramName(int index, const juce::String& newName) override;

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

    static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

    float getGainReductionDb() const noexcept { return gainReductionDb.load(); }

    // -----------------------------------------------------------------
    //  Telemetria da camada adaptativa, para a interface grafica.
    //
    //  Lidas pela linha de MENSAGENS, escritas pela linha de AUDIO: por
    //  isso std::atomic. Sao grandezas de exibicao, nao de controle --
    //  uma leitura desatualizada em alguns milissegundos nao tem
    //  consequencia, e por isso memory_order relaxado basta.
    // -----------------------------------------------------------------
    float getAdaptThresholdDb() const noexcept { return mThresholdDb.load(); }
    float getAdaptRatio()       const noexcept { return mRatio.load();       }
    float getAdaptAttackMs()    const noexcept { return mAttackMs.load();    }
    float getAdaptMakeupDb()    const noexcept { return mMakeupDb.load();    }
    float getCrestFactorDb()    const noexcept { return mCrestDb.load();     }
    float getMeanLevelDb()      const noexcept { return mMeanDb.load();      }
    float getStdDevDb()         const noexcept { return mStdDevDb.load();    }
    float getInputLevelDb()     const noexcept { return mInputLevelDb.load();}
    float getOutputLevelDb()    const noexcept { return mOutLevelDb.load();  }

    //  Picos do bloco. Os medidores laterais comparam entrada e saida, e so
    //  sao comparaveis se ambos forem medidos do MESMO modo -- por isso o
    //  pico de entrada e apurado aqui, e nao tomado do nivel de curto prazo
    //  do controlador, que e grandeza suavizada e de outra natureza.
    float getInputPeakDb()      const noexcept { return mInPeakDb.load();    }
    bool  isAdaptWarmedUp()     const noexcept { return mWarmedUp.load();    }

    // -----------------------------------------------------------------
    //  Historico de niveis para o display temporal.
    //
    //  Um ponto resume uma janela de histSamplesPerPoint amostras --
    //  cerca de 5 ms, recalculada em prepareToPlay a partir da taxa real,
    //  de modo que o eixo de tempo da figura independe da taxa do
    //  hospedeiro. De cada janela guardam-se o pico de entrada, o pico de
    //  saida e a MAIOR reducao de ganho, os tres em dB.
    //
    //  O buffer e circular e escrito pela linha de AUDIO, lido pela linha
    //  de MENSAGENS. Nao ha travamento: um mutex na linha de audio seria o
    //  erro grave aqui. O unico efeito possivel da corrida e a interface
    //  desenhar um ponto a meio caminho de ser escrito, o que dura um
    //  quadro e nao altera dado algum do processamento.
    // -----------------------------------------------------------------
    struct HistoryPoint
    {
        float inDb  { -100.0f };
        float outDb { -100.0f };
        float grDb  {    0.0f };   // valor negativo: atenuacao
    };

    static constexpr int kHistorySize = 768;

    const HistoryPoint* getHistory() const noexcept { return mHistory; }
    int getHistoryWrite()            const noexcept { return mHistWrite.load(std::memory_order_acquire); }
    double getHistorySecondsPerPoint() const noexcept { return mHistSecondsPerPoint; }

    juce::AudioProcessorValueTreeState apvts;

private:
    CompressorCore      core;
    AdaptiveController  adaptive;

    std::atomic<float> gainReductionDb{ 0.0f };

    //  Espelho dos parametros em vigor apos a adaptacao.
    std::atomic<float> mThresholdDb{ -12.0f };
    std::atomic<float> mRatio      {   4.0f };
    std::atomic<float> mAttackMs   {  10.0f };
    std::atomic<float> mMakeupDb   {   6.0f };
    std::atomic<float> mCrestDb    {   0.0f };
    std::atomic<float> mMeanDb     { -60.0f };
    std::atomic<float> mStdDevDb   {   0.0f };
    std::atomic<float> mInputLevelDb { -60.0f };
    std::atomic<float> mOutLevelDb { -60.0f };
    std::atomic<float> mInPeakDb  { -60.0f };
    std::atomic<bool>  mWarmedUp   {  false };

    //  Historico de niveis -- ver comentario dos acessores acima.
    HistoryPoint      mHistory[kHistorySize] {};
    std::atomic<int>  mHistWrite { 0 };
    int    mHistCount { 0 };
    int    mHistSamplesPerPoint { 220 };
    double mHistSecondsPerPoint { 0.005 };
    double mHistInPeak  { 0.0 };
    double mHistOutPeak { 0.0 };
    double mHistGrMin   { 0.0 };

    //  Converte amplitude linear em dBFS com o mesmo piso adotado na
    //  camada adaptativa, para que as escalas coincidam.
    static float toDb (double amp) noexcept
    {
        return static_cast<float> (20.0 * std::log10 (std::max (amp, 1.0e-6)));
    }

    std::atomic<float>* pThreshold{ nullptr };
    std::atomic<float>* pRatio{ nullptr };
    std::atomic<float>* pAttack{ nullptr };
    std::atomic<float>* pRelease{ nullptr };
    std::atomic<float>* pKnee{ nullptr };
    std::atomic<float>* pMakeup{ nullptr };

    //  Chaves dos quatro modos adaptativos. Nascem desligadas: com todas
    //  em falso o plugin reproduz exatamente o comportamento validado no
    //  Capitulo 8, e aquela validacao permanece valida como caso
    //  particular desta arquitetura.
    std::atomic<float>* pAdaptThreshold{ nullptr };
    std::atomic<float>* pAdaptRatio    { nullptr };
    std::atomic<float>* pAdaptAttack   { nullptr };
    std::atomic<float>* pAutoMakeup    { nullptr };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CompressorAudioProcessor)
};
