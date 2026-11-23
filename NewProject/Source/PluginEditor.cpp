#include "PluginEditor.h"

namespace
{
    //  Dimensoes fixas da janela. A escolha por tamanho fixo, e nao
    //  redimensionavel, decorre de o conteudo ser denso e de a legibilidade
    //  dos rotulos ter sido verificada nesta escala; um fator de escala
    //  arbitrario exigiria tipografia responsiva sem beneficio para os
    //  objetivos do trabalho.
    constexpr int kWidth  = 1120;
    constexpr int kHeight = 800;

    constexpr int kHeaderH = 52;
    constexpr int kMargin  = 20;
    constexpr int kGap     = 12;

    //  Faixa superior: historico temporal e escadas de nivel.
    constexpr int kHistY = 68;
    constexpr int kHistH = 200;

    //  Faixa intermediaria: curva estatica, medidor de reducao, telemetria.
    constexpr int kMidY  = 284;
    constexpr int kMidH  = 296;
}

CompressorAudioProcessorEditor::CompressorAudioProcessorEditor (CompressorAudioProcessor& p)
    : juce::AudioProcessorEditor (&p), processor (p)
{
    setLookAndFeel (&lnf);

    addAndMakeVisible (hist);
    addAndMakeVisible (ladder);
    addAndMakeVisible (curve);
    addAndMakeVisible (meter);
    addAndMakeVisible (tele);

    for (auto* k : { &knobThreshold, &knobRatio, &knobKnee,
                     &knobAttack, &knobRelease, &knobMakeup })
        addAndMakeVisible (*k);

    setSize (kWidth, kHeight);
    setResizable (false, false);

    //  30 Hz: acima da taxa em que o olho percebe salto e muito abaixo da
    //  cadencia de bloco, de modo que a interface nunca e o gargalo.
    startTimerHz (30);
}

CompressorAudioProcessorEditor::~CompressorAudioProcessorEditor()
{
    stopTimer();
    setLookAndFeel (nullptr);
}

void CompressorAudioProcessorEditor::resized()
{
    const int dispW   = kWidth - 2 * kMargin;
    const int ladderW = 120;

    hist  .setBounds (kMargin, kHistY, dispW - ladderW - kGap, kHistH);
    ladder.setBounds (kWidth - kMargin - ladderW, kHistY, ladderW, kHistH);

    const int curveW = 440, meterW = 90;
    const int teleW  = dispW - curveW - meterW - 2 * kGap;

    curve.setBounds (kMargin, kMidY, curveW, kMidH);
    meter.setBounds (kMargin + curveW + kGap, kMidY, meterW, kMidH);
    tele .setBounds (kMargin + curveW + kGap + meterW + kGap, kMidY, teleW, kMidH);

    const int rowY = kMidY + kMidH + 16;
    const int rowH = kHeight - rowY;
    const int slot = kWidth / 6;

    ParameterKnob* knobs[] = { &knobThreshold, &knobRatio, &knobKnee,
                               &knobAttack, &knobRelease, &knobMakeup };

    for (int i = 0; i < 6; ++i)
        knobs[i]->setBounds (i * slot, rowY, slot, rowH);
}

void CompressorAudioProcessorEditor::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();

    CompressorLookAndFeel::fillVerticalGradient (g, area,
        CompColours::faceTop(), CompColours::faceBottom());

    //  Cabecalho.
    const auto header = area.withHeight ((float) kHeaderH);
    g.setColour (CompColours::headerBg());
    g.fillRect (header);
    g.setColour (CompColours::panelEdge());
    g.drawHorizontalLine (kHeaderH, area.getX(), area.getRight());

    CompressorLookAndFeel::drawTrackedText (g, juce::String::fromUTF8 ("COMPRESSOR DIN\xc3\x82MICO "),
        header.withTrimmedLeft (20.0f), CompColours::textBright(), 13.5f, 2.4f);

    //  A segunda palavra recebe o acento de cor; a largura da primeira e
    //  medida para posicionar a emenda.
    {
        const auto f = CompressorLookAndFeel::uiFont (13.5f);
        float w = 0.0f;
        const juce::String first (juce::String::fromUTF8 ("COMPRESSOR DIN\xc3\x82MICO "));
        for (int i = 0; i < first.length(); ++i)
            w += CompressorLookAndFeel::textWidth (f, first.substring (i, i + 1)) + 2.4f;

        CompressorLookAndFeel::drawTrackedText (g, "ADAPTATIVO",
            header.withTrimmedLeft (20.0f + w), CompColours::accent(), 13.5f, 2.4f);
    }

    //  Fora de um hospedeiro, taxa e bloco so ficam definidos apos
    //  prepareToPlay; ate la nao se exibe numero algum, em vez de exibir zero.
    const double fs = processor.getSampleRate();
    const int    bl = processor.getBlockSize();

    const auto taxa = fs > 0.0 ? juce::String (fs / 1000.0, 1).replaceCharacter ('.', ',') + " kHz"
                               : juce::String::fromUTF8 ("\xe2\x80\x94");
    const auto bloco = bl > 0 ? juce::String (bl) : juce::String::fromUTF8 ("\xe2\x80\x94");

    CompressorLookAndFeel::drawTrackedText (g,
        taxa.toUpperCase() + "  \xc2\xb7  BLOCO " + bloco
             + juce::String::fromUTF8 ("  \xc2\xb7  LAT\xc3\x8aNCIA 0"),
        header.withTrimmedRight (20.0f), CompColours::textFaint(), 10.5f, 1.3f,
        juce::Justification::right);
}

void CompressorAudioProcessorEditor::timerCallback()
{
    //  Uma unica leitura por grandeza e por quadro: as variaveis sao atomicas
    //  e escritas pela linha de audio, de modo que leituras repetidas poderiam
    //  devolver valores de instantes diferentes dentro do mesmo desenho.
    const double thr    = processor.getAdaptThresholdDb();
    const double rat    = processor.getAdaptRatio();
    const double atk    = processor.getAdaptAttackMs();
    const double mk     = processor.getAdaptMakeupDb();
    const double gr     = processor.getGainReductionDb();
    const double level  = processor.getInputLevelDb();

    //  Os knobs sob adaptacao exibem o valor imposto; os demais ignoram a
    //  chamada e continuam a mostrar o valor do usuario.
    knobThreshold.setAdaptedValue (thr);
    knobRatio    .setAdaptedValue (rat);
    knobAttack   .setAdaptedValue (atk);
    knobMakeup   .setAdaptedValue (mk);

    //  A curva desenha os parametros EM VIGOR, sejam manuais ou adaptados.
    curve.setParameters (thr, rat, (double) *processor.apvts.getRawParameterValue ("knee"));
    curve.setOperatingPoint (level);

    meter.setReduction (gr);
    ladder.setLevels (processor.getInputPeakDb(), processor.getOutputLevelDb());

    //  Historico: copia do buffer circular, do ponto mais antigo ao mais
    //  recente. O indice de escrita e lido uma unica vez -- se a linha de
    //  audio avancar durante a copia, o quadro mostra uma amostra
    //  ligeiramente mista, sem consequencia alguma para o desenho.
    {
        const int w = processor.getHistoryWrite();
        const auto* src = processor.getHistory();
        const int n = CompressorAudioProcessor::kHistorySize;

        std::vector<LevelHistoryComponent::Point> pontos;
        pontos.reserve ((size_t) n);

        for (int i = 0; i < n; ++i)
        {
            const auto& p = src[(w + i) % n];
            pontos.push_back ({ p.inDb, p.outDb, p.grDb });
        }

        hist.setHistory (pontos, n * processor.getHistorySecondsPerPoint());
        hist.setThreshold (thr);
    }

    TelemetryPanel::Reading r;
    r.crestDb       = processor.getCrestFactorDb();
    r.levelDb       = level;
    r.meanDb        = processor.getMeanLevelDb();
    r.stdDevDb      = processor.getStdDevDb();
    r.thresholdDb   = thr;
    r.ratio         = rat;
    r.attackMs      = atk;
    r.makeupDb      = mk;
    r.reductionDb   = gr;
    r.warmedUp      = processor.isAdaptWarmedUp();
    r.autoThreshold = knobThreshold.isAutomatic();
    r.autoRatio     = knobRatio    .isAutomatic();
    r.autoAttack    = knobAttack   .isAutomatic();
    r.autoMakeup    = knobMakeup   .isAutomatic();

    tele.setReading (r);
}
