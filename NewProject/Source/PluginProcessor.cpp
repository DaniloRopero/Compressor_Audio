#include "PluginProcessor.h"
#include "PluginEditor.h"

CompressorAudioProcessor::CompressorAudioProcessor()
#ifndef JucePlugin_PreferredChannelConfigurations
    : AudioProcessor(BusesProperties()
#if ! JucePlugin_IsMidiEffect
#if ! JucePlugin_IsSynth
        .withInput("Input", juce::AudioChannelSet::stereo(), true)
#endif
        .withOutput("Output", juce::AudioChannelSet::stereo(), true)
#endif
    ),
    apvts(*this, nullptr, "PARAMETERS", createParameterLayout())
#else
    : apvts(*this, nullptr, "PARAMETERS", createParameterLayout())
#endif
{
    pThreshold = apvts.getRawParameterValue("threshold");
    pRatio = apvts.getRawParameterValue("ratio");
    pAttack = apvts.getRawParameterValue("attack");
    pRelease = apvts.getRawParameterValue("release");
    pKnee = apvts.getRawParameterValue("knee");
    pMakeup = apvts.getRawParameterValue("makeup");

    pAdaptThreshold = apvts.getRawParameterValue("adaptThreshold");
    pAdaptRatio     = apvts.getRawParameterValue("adaptRatio");
    pAdaptAttack    = apvts.getRawParameterValue("adaptAttack");
    pAutoMakeup     = apvts.getRawParameterValue("autoMakeup");
}

CompressorAudioProcessor::~CompressorAudioProcessor()
{
}

juce::AudioProcessorValueTreeState::ParameterLayout
CompressorAudioProcessor::createParameterLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "threshold", 1 },
        "Threshold",
        juce::NormalisableRange<float>(-60.0f, 0.0f, 0.1f),
        -12.0f,
        juce::AudioParameterFloatAttributes().withLabel("dB")));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "ratio", 1 },
        "Ratio",
        juce::NormalisableRange<float>(1.0f, 20.0f, 0.01f, 0.4f),
        4.0f,
        juce::AudioParameterFloatAttributes().withLabel(":1")));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "attack", 1 },
        "Attack",
        juce::NormalisableRange<float>(0.1f, 200.0f, 0.01f, 0.35f),
        10.0f,
        juce::AudioParameterFloatAttributes().withLabel("ms")));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "release", 1 },
        "Release",
        juce::NormalisableRange<float>(5.0f, 2000.0f, 0.1f, 0.35f),
        100.0f,
        juce::AudioParameterFloatAttributes().withLabel("ms")));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "knee", 1 },
        "Knee",
        juce::NormalisableRange<float>(0.0f, 24.0f, 0.1f),
        6.0f,
        juce::AudioParameterFloatAttributes().withLabel("dB")));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{ "makeup", 1 },
        "Make-up Gain",
        juce::NormalisableRange<float>(-12.0f, 24.0f, 0.1f),
        6.0f,
        juce::AudioParameterFloatAttributes().withLabel("dB")));

    // -----------------------------------------------------------------
    //  Chaves dos quatro modos adaptativos.
    //
    //  Todas nascem DESLIGADAS. Com as quatro em falso o processamento e
    //  bit a bit identico ao validado no Capitulo 8 -- o controlador
    //  apenas observa, sem escrever no nucleo. A validacao anterior
    //  passa a ser caso particular desta arquitetura, e nao algo
    //  superado por ela.
    // -----------------------------------------------------------------
    layout.add(std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID{ "adaptThreshold", 1 }, "Limiar adaptativo", false));

    layout.add(std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID{ "adaptRatio", 1 }, "Razao adaptativa", false));

    layout.add(std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID{ "adaptAttack", 1 }, "Ataque adaptativo", false));

    layout.add(std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID{ "autoMakeup", 1 }, "Compensacao automatica", false));

    return layout;
}

const juce::String CompressorAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool CompressorAudioProcessor::acceptsMidi() const
{
#if JucePlugin_WantsMidiInput
    return true;
#else
    return false;
#endif
}

bool CompressorAudioProcessor::producesMidi() const
{
#if JucePlugin_ProducesMidiOutput
    return true;
#else
    return false;
#endif
}

bool CompressorAudioProcessor::isMidiEffect() const
{
#if JucePlugin_IsMidiEffect
    return true;
#else
    return false;
#endif
}

double CompressorAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int CompressorAudioProcessor::getNumPrograms()
{
    return 1;
}

int CompressorAudioProcessor::getCurrentProgram()
{
    return 0;
}

void CompressorAudioProcessor::setCurrentProgram(int index)
{
    juce::ignoreUnused(index);
}

const juce::String CompressorAudioProcessor::getProgramName(int index)
{
    juce::ignoreUnused(index);
    return {};
}

void CompressorAudioProcessor::changeProgramName(int index, const juce::String& newName)
{
    juce::ignoreUnused(index, newName);
}

void CompressorAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    juce::ignoreUnused(samplesPerBlock);

    core.prepare(sampleRate);
    adaptive.prepare(sampleRate);

    gainReductionDb.store(0.0f);

    //  Um ponto do historico a cada 5 ms, recalculado a partir da taxa
    //  real: assim o eixo de tempo do display cobre sempre o mesmo
    //  intervalo, qualquer que seja o hospedeiro.
    mHistSecondsPerPoint = 0.005;
    mHistSamplesPerPoint = juce::jmax (1, juce::roundToInt (sampleRate * mHistSecondsPerPoint));

    for (auto& p : mHistory)
        p = HistoryPoint{};

    mHistWrite.store (0, std::memory_order_release);
    mHistCount   = 0;
    mHistInPeak  = 0.0;
    mHistOutPeak = 0.0;
    mHistGrMin   = 0.0;

    setLatencySamples(0);
}

void CompressorAudioProcessor::releaseResources()
{
}

#ifndef JucePlugin_PreferredChannelConfigurations
bool CompressorAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    const auto& mainOut = layouts.getMainOutputChannelSet();
    const auto& mainIn = layouts.getMainInputChannelSet();

    if (mainOut != juce::AudioChannelSet::mono()
        && mainOut != juce::AudioChannelSet::stereo())
        return false;

    if (mainIn != mainOut)
        return false;

    return true;
}
#endif

void CompressorAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer,
    juce::MidiBuffer& midiMessages)
{
    juce::ignoreUnused(midiMessages);
    juce::ScopedNoDenormals noDenormals;

    const int numSamples = buffer.getNumSamples();
    const int numInputs = getTotalNumInputChannels();
    const int numOutputs = getTotalNumOutputChannels();

    for (int ch = numInputs; ch < numOutputs; ++ch)
        buffer.clear(ch, 0, numSamples);

    if (numInputs < 1 || numSamples < 1)
        return;

    // -----------------------------------------------------------------
    //  Parametros manuais e chaves dos modos, uma vez por bloco.
    //
    //  A ordem importa. O updateCore escreve no nucleo APENAS os
    //  parametros cujo modo esteja ligado; os demais conserva como
    //  vieram do Config. Por isso o Config carrega os seis valores
    //  manuais: ele e a referencia, e a adaptacao e a excecao.
    // -----------------------------------------------------------------
    AdaptiveController::Config cfg;
    cfg.thresholdDb = static_cast<double>(pThreshold->load());
    cfg.ratio       = static_cast<double>(pRatio->load());
    cfg.attackMs    = static_cast<double>(pAttack->load());
    cfg.releaseMs   = static_cast<double>(pRelease->load());
    cfg.kneeDb      = static_cast<double>(pKnee->load());
    cfg.makeupDb    = static_cast<double>(pMakeup->load());

    cfg.adaptiveThreshold = (pAdaptThreshold->load() > 0.5f);
    cfg.adaptiveRatio     = (pAdaptRatio->load()     > 0.5f);
    cfg.adaptiveAttack    = (pAdaptAttack->load()    > 0.5f);
    cfg.autoMakeup        = (pAutoMakeup->load()     > 0.5f);

    adaptive.setConfig(cfg);
    adaptive.updateCore(core);

    float* left = buffer.getWritePointer(0);
    float* right = (numInputs > 1) ? buffer.getWritePointer(1) : nullptr;

    double grMin = 0.0;
    double inPeak = 0.0;

    for (int n = 0; n < numSamples; ++n)
    {
        const double xLin = static_cast<double>(left[n]);
        const double xRin = (right != nullptr) ? static_cast<double>(right[n]) : xLin;

        const double detector = std::max(std::abs(xLin), std::abs(xRin));
        inPeak = std::max (inPeak, detector);

        const double gLin = core.nextGain(detector);

        //  Unica alteracao do laco. O controlador OBSERVA; quem escreve
        //  no nucleo e o updateCore, acima, uma vez por bloco.
        adaptive.analyse(detector, gLin);

        left[n] = static_cast<float>(xLin * gLin);

        if (right != nullptr)
            right[n] = static_cast<float> (xRin * gLin);

        const double grAqui = core.getGainReductionDb();
        grMin = std::min(grMin, grAqui);

        // -------------------------------------------------------------
        //  Acumulo do historico. Dentro da janela guardam-se apenas tres
        //  comparacoes por amostra; o custo e desprezivel frente as
        //  transcendentais do nucleo.
        // -------------------------------------------------------------
        mHistInPeak  = std::max (mHistInPeak,  detector);
        mHistOutPeak = std::max (mHistOutPeak, std::abs (xLin * gLin));
        mHistGrMin   = std::min (mHistGrMin,   grAqui);

        if (++mHistCount >= mHistSamplesPerPoint)
        {
            const int w = mHistWrite.load (std::memory_order_relaxed);

            mHistory[w].inDb  = toDb (mHistInPeak);
            mHistory[w].outDb = toDb (mHistOutPeak);
            mHistory[w].grDb  = static_cast<float> (mHistGrMin);

            //  A publicacao do indice vem DEPOIS da escrita do ponto, com
            //  barreira de liberacao: a interface nunca encontra o indice
            //  novo apontando para um ponto ainda nao preenchido.
            mHistWrite.store ((w + 1) % kHistorySize, std::memory_order_release);

            mHistCount   = 0;
            mHistInPeak  = 0.0;
            mHistOutPeak = 0.0;
            mHistGrMin   = 0.0;
        }
    }

    gainReductionDb.store(static_cast<float> (grMin));

    //  Pico de saida do bloco, para o medidor lateral. O pico de entrada
    //  ja vem do controlador adaptativo, que o estima de qualquer modo.
    {
        float outPk = 0.0f;
        for (int ch = 0; ch < numInputs; ++ch)
            outPk = std::max (outPk, buffer.getMagnitude (ch, 0, numSamples));

        mOutLevelDb.store (toDb (outPk));
        mInPeakDb  .store (toDb (inPeak));
    }

    //  Espelho dos parametros em vigor, para a interface grafica.
    mThresholdDb.store(static_cast<float>(adaptive.getThresholdDb()));
    mRatio      .store(static_cast<float>(adaptive.getRatio()));
    mAttackMs   .store(static_cast<float>(adaptive.getAttackMs()));
    mMakeupDb   .store(static_cast<float>(adaptive.getMakeupDb()));
    mCrestDb    .store(static_cast<float>(adaptive.getCrestFactorDb()));
    mWarmedUp   .store(adaptive.isWarmedUp());

    //  Estatisticas de longo prazo e nivel instantaneo, exibidos no painel de
    //  telemetria. Sao estimativas ja calculadas pelo controlador -- nada aqui
    //  acrescenta operacao ao laco de audio alem da escrita atomica.
    mMeanDb     .store(static_cast<float>(adaptive.getMeanLevelDb()));
    mStdDevDb   .store(static_cast<float>(adaptive.getStdDevDb()));
    mInputLevelDb.store(static_cast<float>(adaptive.getInputLevelDb()));
}

bool CompressorAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* CompressorAudioProcessor::createEditor()
{
    return new CompressorAudioProcessorEditor(*this);
}

void CompressorAudioProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    if (auto state = apvts.copyState(); state.isValid())
    {
        if (auto xml = state.createXml())
            copyXmlToBinary(*xml, destData);
    }
}

void CompressorAudioProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    if (auto xml = getXmlFromBinary(data, sizeInBytes))
        if (xml->hasTagName(apvts.state.getType()))
            apvts.replaceState(juce::ValueTree::fromXml(*xml));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new CompressorAudioProcessor();
}
