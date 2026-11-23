#include "CompressorComponents.h"

namespace
{
    //  Virgula decimal, conforme a convencao brasileira.
    juce::String numero (double v, int casas)
    {
        return juce::String (v, casas).replaceCharacter ('.', ',');
    }
}

// ============================================================================
//  ParameterKnob
// ============================================================================

ParameterKnob::ParameterKnob (CompressorLookAndFeel& l,
                              juce::AudioProcessorValueTreeState& a,
                              const juce::String& pid,
                              juce::String cap,
                              juce::String un,
                              int dec,
                              const juce::String& autoPid,
                              bool comSinal)
    : lnf (l), apvts (a), paramId (pid), caption (std::move (cap)),
      unit (std::move (un)), decimals (dec), mostraSinal (comSinal)
{
    knob.setLookAndFeel (&lnf);
    knob.setRotaryParameters (juce::MathConstants<float>::pi * 1.25f,
                              juce::MathConstants<float>::pi * 2.75f,
                              true);
    knob.setColour (juce::Slider::rotarySliderFillColourId, CompColours::accent());
    knob.onValueChange = [this] { repaint(); };
    addAndMakeVisible (knob);

    knobAttach = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>
                     (apvts, paramId, knob);

    hasAuto = autoPid.isNotEmpty();

    if (hasAuto)
    {
        autoButton.setClickingTogglesState (true);
        autoButton.setLookAndFeel (&lnf);
        autoButton.setColour (juce::TextButton::buttonColourId,
                              juce::Colour::fromRGB (0x1b, 0x1e, 0x23));
        autoButton.setColour (juce::TextButton::buttonOnColourId,
                              juce::Colour::fromRGB (0x2b, 0x24, 0x19));
        autoButton.setColour (juce::TextButton::textColourOffId, CompColours::textFaint());
        autoButton.setColour (juce::TextButton::textColourOnId,  CompColours::adapt());
        autoButton.onClick = [this] { refreshMode(); };
        addAndMakeVisible (autoButton);

        autoAttach = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>
                         (apvts, autoPid, autoButton);
    }

    refreshMode();
}

bool ParameterKnob::isAutomatic() const noexcept
{
    return hasAuto && autoButton.getToggleState();
}

void ParameterKnob::refreshMode()
{
    const bool automatic = isAutomatic();

    //  Sob adaptacao o knob nao aceita o mouse: o valor exibido deixa de ser
    //  o do usuario e passa a ser o do algoritmo. O parametro no APVTS nao e
    //  tocado, de modo que o ajuste manual sobrevive ao ciclo liga/desliga.
    knob.setInterceptsMouseClicks (! automatic, false);
    knob.setColour (juce::Slider::rotarySliderFillColourId,
                    automatic ? CompColours::adapt() : CompColours::accent());

    //  Ao sair do modo automatico o anel precisa voltar ao valor do usuario.
    //  Enquanto a adaptacao vigorava, a posicao visual foi movida sem avisar o
    //  APVTS -- e o parametro permaneceu onde o usuario o deixou. Sem esta
    //  releitura o knob continuaria exibindo o ultimo valor imposto pelo
    //  algoritmo, divergindo do valor efetivamente aplicado.
    if (! automatic)
        if (auto* p = apvts.getParameter (paramId))
            knob.setValue (p->convertFrom0to1 (p->getValue()), juce::dontSendNotification);

    repaint();
}

void ParameterKnob::setAdaptedValue (double value)
{
    if (! isAutomatic())
        return;

    if (std::abs (value - adaptedValue) < 1.0e-4)
        return;

    adaptedValue = value;

    //  Move apenas a posicao visual do anel; nao notifica o APVTS.
    if (auto* p = apvts.getParameter (paramId))
        knob.setValue (juce::jlimit ((double) p->getNormalisableRange().start,
                                     (double) p->getNormalisableRange().end,
                                     value),
                       juce::dontSendNotification);
    repaint();
}

juce::String ParameterKnob::formatValue (double v) const
{
    //  Sinal de menos tipografico (U+2212), e nao o hifen, para que a leitura
    //  do knob coincida com a do painel de telemetria.
    const auto menos = juce::String::fromUTF8 ("\xe2\x88\x92");

    auto s = numero (std::abs (v), decimals);

    if (v < 0.0)       s = menos + s;
    else if (mostraSinal) s = "+" + s;

    return s;
}

void ParameterKnob::resized()
{
    auto r = getLocalBounds();
    r.removeFromTop (20);                       // legenda
    knob.setBounds (r.removeFromTop (78).withSizeKeepingCentre (78, 78));
    r.removeFromTop (26);                       // leitura numerica
    if (hasAuto)
        autoButton.setBounds (r.removeFromTop (20).withSizeKeepingCentre (62, 20));
}

void ParameterKnob::paint (juce::Graphics& g)
{
    const auto automatic = isAutomatic();
    const auto w = (float) getWidth();

    CompressorLookAndFeel::drawTrackedText (g, caption.toUpperCase(),
        { 0.0f, 2.0f, w, 14.0f }, CompColours::textDim(), 9.5f, 1.5f,
        juce::Justification::centred);

    const double shown = automatic ? adaptedValue : knob.getValue();

    const auto txt  = formatValue (shown);
    const auto font = CompressorLookAndFeel::uiFont (13.0f);
    const auto uFont= CompressorLookAndFeel::uiFont (9.5f);

    const float tw = CompressorLookAndFeel::textWidth (font, txt);
    const float uw = CompressorLookAndFeel::textWidth (uFont, " " + unit);
    float x = (w - tw - uw) * 0.5f;
    const float y = 20.0f + 78.0f + 18.0f;

    g.setFont (font);
    g.setColour (automatic ? CompColours::adapt() : CompColours::textBright());
    g.drawSingleLineText (txt, juce::roundToInt (x), juce::roundToInt (y));

    g.setFont (uFont);
    g.setColour (CompColours::textFaint());
    g.drawSingleLineText (" " + unit, juce::roundToInt (x + tw), juce::roundToInt (y));

    //  Moldura discreta ao redor da leitura marca o valor como imposto.
    if (automatic)
    {
        g.setColour (CompColours::adapt().withAlpha (0.45f));
        g.drawRoundedRectangle ({ (w - tw - uw) * 0.5f - 10.0f, y - 14.0f,
                                  tw + uw + 20.0f, 20.0f }, 2.0f, 1.0f);
    }
}


// ============================================================================
//  StaticCurveComponent
// ============================================================================

void StaticCurveComponent::setParameters (double t, double r, double k)
{
    if (std::abs (t - thresholdDb) < 1.0e-4
     && std::abs (r - ratio)       < 1.0e-4
     && std::abs (k - kneeDb)      < 1.0e-4)
        return;

    thresholdDb = t; ratio = r; kneeDb = k;
    repaint();
}

void StaticCurveComponent::setOperatingPoint (double in)
{
    if (std::abs (in - inputDb) < 0.05)
        return;

    inputDb = in;
    repaint();
}

double StaticCurveComponent::gainComputer (double xG) const
{
    const double W = kneeDb, T = thresholdDb, R = ratio;

    //  Joelho abrupto (W = 0): a forma quadratica divide por 2W e produziria
    //  NaN sobre o proprio limiar. A guarda reproduz a do nucleo de
    //  processamento, onde o ramo do joelho so e avaliado se W > 0.
    if (W <= 0.0)
        return xG > T ? T + (xG - T) / R : xG;

    if (2.0 * (xG - T) < -W)                 // Regiao A -- ganho unitario
        return xG;

    if (2.0 * std::abs (xG - T) <= W)        // Regiao B -- joelho quadratico
        return xG + (1.0 / R - 1.0) * std::pow (xG - T + W * 0.5, 2.0) / (2.0 * W);

    return T + (xG - T) / R;                 // Regiao C -- compressao plena
}

void StaticCurveComponent::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    CompressorLookAndFeel::drawPanel (g, area, juce::String::fromUTF8 ("CURVA EST\xc3\x81TICA DE COMPRESS\xc3\x83O"));

    const auto plot = juce::Rectangle<float> (area.getX() + 46.0f, area.getY() + 30.0f,
                                              area.getWidth()  - 62.0f,
                                              area.getHeight() - 66.0f);

    auto sx = [&] (double db) { return plot.getX() + (float) ((db - loDb) / (hiDb - loDb)) * plot.getWidth(); };
    auto sy = [&] (double db) { return plot.getBottom() - (float) ((db - loDb) / (hiDb - loDb)) * plot.getHeight(); };

    g.setColour (CompColours::plotBg());
    g.fillRect (plot);

    //  Grade a cada 5 dB; rotulos a cada 10 dB.
    for (int v = -55; v <= -5; v += 5)
    {
        const bool major = (v % 10 == 0);
        g.setColour (major ? CompColours::gridMajor() : CompColours::gridMinor());
        g.drawVerticalLine   (juce::roundToInt (sx (v)), plot.getY(), plot.getBottom());
        g.drawHorizontalLine (juce::roundToInt (sy (v)), plot.getX(), plot.getRight());

        if (major)
        {
            g.setColour (CompColours::textGhost());
            g.setFont (CompressorLookAndFeel::uiFont (9.0f));
            g.drawText (juce::String (v), juce::Rectangle<float> (sx (v) - 20.0f, plot.getBottom() + 3.0f, 40.0f, 12.0f),
                        juce::Justification::centred);
            g.drawText (juce::String (v), juce::Rectangle<float> (plot.getX() - 40.0f, sy (v) - 6.0f, 34.0f, 12.0f),
                        juce::Justification::centredRight);
        }
    }

    g.setColour (CompColours::panelEdge());
    g.drawRect (plot, 1.0f);

    //  Faixa do joelho.
    g.setColour (CompColours::accent().withAlpha (0.07f));
    g.fillRect (juce::Rectangle<float> (sx (thresholdDb - kneeDb * 0.5), plot.getY(),
                                        sx (thresholdDb + kneeDb * 0.5) - sx (thresholdDb - kneeDb * 0.5),
                                        plot.getHeight()));

    //  Reta 1:1.
    {
        juce::Path unity;
        unity.startNewSubPath (sx (loDb), sy (loDb));
        unity.lineTo          (sx (hiDb), sy (hiDb));
        g.setColour (CompColours::gridUnity());
        CompressorLookAndFeel::strokeDashed (g, unity, 1.0f, 3.0f, 3.0f);
    }

    //  Marca do limiar.
    {
        juce::Path tl;
        tl.startNewSubPath (sx (thresholdDb), plot.getY());
        tl.lineTo          (sx (thresholdDb), plot.getBottom());
        g.setColour (CompColours::adapt().withAlpha (0.5f));
        CompressorLookAndFeel::strokeDashed (g, tl, 1.0f, 4.0f, 3.0f);
        g.setFont (CompressorLookAndFeel::uiFont (9.0f));
        g.drawSingleLineText ("T", juce::roundToInt (sx (thresholdDb) + 5.0f),
                                   juce::roundToInt (plot.getY() + 12.0f));
    }

    //  Curva.
    {
        juce::Path curve;
        for (int i = 0; i <= 240; ++i)
        {
            const double x = loDb + (hiDb - loDb) * i / 240.0;
            const auto px = sx (x), py = sy (gainComputer (x));
            if (i == 0) curve.startNewSubPath (px, py);
            else        curve.lineTo          (px, py);
        }
        g.setColour (CompColours::accent());
        g.strokePath (curve, juce::PathStrokeType (2.2f));
    }

    //  Ponto de operacao.
    if (inputDb > loDb + 0.5)
    {
        const auto px = sx (inputDb), py = sy (gainComputer (inputDb));
        g.setColour (CompColours::textBright().withAlpha (0.28f));
        g.drawEllipse (px - 9.0f, py - 9.0f, 18.0f, 18.0f, 1.2f);
        g.setColour (CompColours::textBright());
        g.fillEllipse (px - 4.5f, py - 4.5f, 9.0f, 9.0f);
    }

    //  Rotulos dos eixos.
    CompressorLookAndFeel::drawTrackedText (g, "ENTRADA (dBFS)",
        { plot.getX(), area.getBottom() - 18.0f, plot.getWidth(), 12.0f },
        CompColours::textFaint(), 9.5f, 1.2f, juce::Justification::centred);

    {
        juce::Graphics::ScopedSaveState ss (g);
        g.addTransform (juce::AffineTransform::rotation (-juce::MathConstants<float>::halfPi,
                                                         area.getX() + 14.0f, plot.getCentreY()));
        g.setColour (CompColours::textFaint());
        g.setFont (CompressorLookAndFeel::uiFont (9.5f));
        g.drawText (juce::String::fromUTF8 ("SA\xc3\x8d" "DA (dBFS)"),
                    juce::Rectangle<float> (area.getX() + 14.0f - plot.getHeight() * 0.5f,
                                            plot.getCentreY() - 7.0f,
                                            plot.getHeight(), 14.0f),
                    juce::Justification::centred);
    }
}


// ============================================================================
//  GainReductionMeter
// ============================================================================

void GainReductionMeter::setReduction (double r)
{
    current = juce::jlimit (0.0, maxDb, std::abs (r));

    //  Retencao de pico: segura por cerca de um segundo a 30 Hz de
    //  atualizacao e depois decai, para que atenuacoes rapidas sejam legiveis.
    if (current >= peakHold)
    {
        peakHold = current;
        holdCounter = 30;
    }
    else if (holdCounter > 0)
    {
        --holdCounter;
    }
    else
    {
        peakHold = juce::jmax (current, peakHold - 0.35);
    }

    repaint();
}

void GainReductionMeter::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    CompressorLookAndFeel::drawPanel (g, area, juce::String::fromUTF8 ("REDU\xc3\x87\xc3\x83O"));

    const auto bar = juce::Rectangle<float> (area.getX() + 14.0f, area.getY() + 30.0f,
                                             30.0f, area.getHeight() - 72.0f);

    g.setColour (CompColours::plotBg());
    g.fillRect (bar);
    g.setColour (CompColours::panelEdge());
    g.drawRect (bar, 1.0f);

    auto sy = [&] (double db) { return bar.getY() + (float) (db / maxDb) * bar.getHeight(); };

    for (int d = 0; d <= (int) maxDb; d += 6)
    {
        g.setColour (CompColours::textGhost());
        g.drawLine (bar.getRight(), sy (d), bar.getRight() + 5.0f, sy (d), 1.0f);
        g.setFont (CompressorLookAndFeel::uiFont (8.0f));
        g.drawSingleLineText ("-" + juce::String (d),
                              juce::roundToInt (bar.getRight() + 8.0f),
                              juce::roundToInt (sy (d) + 3.0f));
    }

    //  Barra pendurada no topo: a reducao cresce para baixo.
    g.setColour (CompColours::adapt());
    g.fillRect (juce::Rectangle<float> (bar.getX() + 1.0f, bar.getY() + 1.0f,
                                        bar.getWidth() - 2.0f,
                                        juce::jmax (0.0f, (float) (sy (current) - bar.getY() - 1.0f))));

    if (peakHold > 0.05)
    {
        g.setColour (CompColours::adaptBright());
        g.drawLine (bar.getX(), sy (peakHold), bar.getRight(), sy (peakHold), 2.0f);
    }

    g.setColour (CompColours::textBright());
    g.setFont (CompressorLookAndFeel::uiFont (12.0f));
    g.drawText (juce::String::fromUTF8 ("\xe2\x88\x92") + numero (current, 1),
                juce::Rectangle<float> (area.getX(), bar.getBottom() + 8.0f, area.getWidth(), 16.0f),
                juce::Justification::centred);
}


// ============================================================================
//  LevelHistoryComponent
// ============================================================================

void LevelHistoryComponent::setHistory (const std::vector<Point>& pontos, double segundos)
{
    dados = pontos;
    janelaSegundos = segundos;
    repaint();
}

void LevelHistoryComponent::setThreshold (double t)
{
    if (std::abs (t - thresholdDb) < 1.0e-4)
        return;

    thresholdDb = t;
    repaint();
}

void LevelHistoryComponent::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    CompressorLookAndFeel::drawPanel (g, area, juce::String::fromUTF8 ("HIST\xc3\x93RICO TEMPORAL"));

    const auto plot = juce::Rectangle<float> (area.getX() + 14.0f, area.getY() + 28.0f,
                                              area.getWidth()  - 54.0f,
                                              area.getHeight() - 60.0f);

    g.setColour (CompColours::plotBg());
    g.fillRect (plot);

    auto sy = [&] (double db)
    {
        const double u = juce::jlimit (0.0, 1.0, (db - loDb) / (hiDb - loDb));
        return plot.getBottom() - (float) u * plot.getHeight();
    };

    //  Grade e rotulos de nivel.
    for (int v = -48; v <= -6; v += 6)
    {
        g.setColour (CompColours::gridMinor());
        g.drawHorizontalLine (juce::roundToInt (sy (v)), plot.getX(), plot.getRight());
        g.setColour (CompColours::textGhost());
        g.setFont (CompressorLookAndFeel::uiFont (8.0f));
        g.drawText (juce::String (v),
                    juce::Rectangle<float> (plot.getRight() + 4.0f, sy (v) - 6.0f, 30.0f, 12.0f),
                    juce::Justification::centredLeft);
    }

    const int n = (int) dados.size();

    if (n >= 2)
    {
        auto sx = [&] (int i) { return plot.getX() + (float) i / (float) (n - 1) * plot.getWidth(); };

        //  Entrada -- area preenchida, discreta, para servir de leito.
        {
            juce::Path p;
            p.startNewSubPath (plot.getX(), plot.getBottom());
            for (int i = 0; i < n; ++i)
                p.lineTo (sx (i), sy (dados[(size_t) i].inDb));
            p.lineTo (plot.getRight(), plot.getBottom());
            p.closeSubPath();
            g.setColour (CompColours::textDim().withAlpha (0.28f));
            g.fillPath (p);
        }

        //  Saida -- traco.
        {
            juce::Path p;
            for (int i = 0; i < n; ++i)
            {
                const auto px = sx (i), py = sy (dados[(size_t) i].outDb);
                if (i == 0) p.startNewSubPath (px, py);
                else        p.lineTo          (px, py);
            }
            g.setColour (CompColours::accent());
            g.strokePath (p, juce::PathStrokeType (1.4f));
        }

        //  Reducao de ganho -- pendurada no topo, crescendo para baixo.
        {
            juce::Path area2;
            area2.startNewSubPath (plot.getX(), plot.getY());
            for (int i = 0; i < n; ++i)
                area2.lineTo (sx (i), sy (hiDb + dados[(size_t) i].grDb));
            area2.lineTo (plot.getRight(), plot.getY());
            area2.closeSubPath();
            g.setColour (CompColours::adapt().withAlpha (0.15f));
            g.fillPath (area2);

            juce::Path p;
            for (int i = 0; i < n; ++i)
            {
                const auto px = sx (i), py = sy (hiDb + dados[(size_t) i].grDb);
                if (i == 0) p.startNewSubPath (px, py);
                else        p.lineTo          (px, py);
            }
            g.setColour (CompColours::adapt());
            g.strokePath (p, juce::PathStrokeType (1.5f));
        }
    }

    //  Limiar em vigor.
    {
        juce::Path t;
        t.startNewSubPath (plot.getX(),     sy (thresholdDb));
        t.lineTo          (plot.getRight(), sy (thresholdDb));
        g.setColour (CompColours::adapt().withAlpha (0.4f));
        CompressorLookAndFeel::strokeDashed (g, t, 1.0f, 4.0f, 3.0f);
    }

    g.setColour (CompColours::panelEdge());
    g.drawRect (plot, 1.0f);

    //  Legenda e extensao da janela.
    const struct { juce::String txt; juce::Colour cor; } chaves[] = {
        { juce::String ("ENTRADA"),                          CompColours::textDim() },
        { juce::String::fromUTF8 ("SA\xc3\x8d" "DA"),         CompColours::accent()  },
        { juce::String::fromUTF8 ("REDU\xc3\x87\xc3\x83O"),  CompColours::adapt()   }
    };

    float lx = plot.getX() + 2.0f;
    const float ly = area.getBottom() - 16.0f;

    for (const auto& c : chaves)
    {
        g.setColour (c.cor);
        g.fillRect (juce::Rectangle<float> (lx, ly + 2.0f, 7.0f, 7.0f));
        const juce::String& txt = c.txt;
        CompressorLookAndFeel::drawTrackedText (g, txt,
            { lx + 11.0f, ly, 90.0f, 12.0f }, CompColours::textFaint(), 8.0f, 1.0f);
        lx += 11.0f + CompressorLookAndFeel::textWidth (
                          CompressorLookAndFeel::uiFont (8.0f), txt)
              + txt.length() * 1.0f + 18.0f;
    }

    g.setColour (CompColours::textGhost());
    g.setFont (CompressorLookAndFeel::uiFont (8.0f));
    g.drawText (numero (janelaSegundos, 1) + " s",
                juce::Rectangle<float> (plot.getRight() - 60.0f, ly, 60.0f, 12.0f),
                juce::Justification::centredRight);
}


// ============================================================================
//  LevelLadder
// ============================================================================

void LevelLadder::setLevels (double inDb, double outDb)
{
    auto atualiza = [] (Coluna& c, double v)
    {
        c.nivel = v;

        if (v >= c.pico)
        {
            c.pico  = v;
            c.reter = 30;              // cerca de um segundo a 30 Hz
        }
        else if (c.reter > 0)
        {
            --c.reter;
        }
        else
        {
            c.pico = juce::jmax (v, c.pico - 0.5);
        }
    };

    atualiza (entrada, inDb);
    atualiza (saida,   outDb);
    repaint();
}

void LevelLadder::desenhaColuna (juce::Graphics& g, juce::Rectangle<float> r,
                                 const Coluna& c, const juce::String& rotulo) const
{
    constexpr int segmentos = 26;

    g.setColour (CompColours::plotBg());
    g.fillRect (r);

    const float hSeg = r.getHeight() / (float) segmentos;

    for (int i = 0; i < segmentos; ++i)
    {
        //  Segmento i conta de baixo para cima; db e o topo da sua faixa.
        const double db = minDb * (1.0 - (double) (i + 1) / segmentos);
        const bool aceso = (c.nivel >= db);

        juce::Colour cor = (db > -3.0)  ? juce::Colour::fromRGB (0xc8, 0x45, 0x2f)
                         : (db > -9.0)  ? CompColours::adapt()
                                        : CompColours::ok();

        g.setColour (aceso ? cor : juce::Colour::fromRGB (0x1a, 0x1c, 0x20));
        g.fillRect (juce::Rectangle<float> (r.getX() + 1.5f,
                                            r.getBottom() - (i + 1) * hSeg + 1.0f,
                                            r.getWidth() - 3.0f,
                                            hSeg - 1.6f));
    }

    //  Retencao de pico.
    if (c.pico > minDb)
    {
        const float y = r.getBottom() - (float) ((c.pico - minDb) / -minDb) * r.getHeight();
        g.setColour (CompColours::adaptBright());
        g.fillRect (juce::Rectangle<float> (r.getX() + 1.5f, y - 1.0f, r.getWidth() - 3.0f, 2.0f));
    }

    g.setColour (CompColours::panelEdge());
    g.drawRect (r, 1.0f);

    CompressorLookAndFeel::drawTrackedText (g, rotulo,
        { r.getX(), r.getY() - 15.0f, r.getWidth(), 12.0f },
        CompColours::textFaint(), 8.5f, 1.2f, juce::Justification::centred);

    const auto menos = juce::String::fromUTF8 ("\xe2\x88\x92");
    g.setColour (CompColours::textLabel());
    g.setFont (CompressorLookAndFeel::uiFont (9.5f));
    g.drawText ((c.nivel <= minDb ? menos + juce::String::fromUTF8 ("\xe2\x88\x9e")
                                  : (c.nivel < 0 ? menos : juce::String())
                                    + numero (std::abs (c.nivel), 1)),
                juce::Rectangle<float> (r.getX() - 6.0f, r.getBottom() + 4.0f,
                                        r.getWidth() + 12.0f, 13.0f),
                juce::Justification::centred);
}

void LevelLadder::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    CompressorLookAndFeel::drawPanel (g, area, juce::String::fromUTF8 ("N\xc3\x8dVEL"));

    const float topo = area.getY() + 44.0f;
    const float base = area.getBottom() - 34.0f;
    const float larg = 26.0f;

    desenhaColuna (g, { area.getX() + 16.0f, topo, larg, base - topo }, entrada, "IN");
    desenhaColuna (g, { area.getRight() - 16.0f - larg, topo, larg, base - topo }, saida, "OUT");

    //  Escala entre as duas colunas.
    g.setFont (CompressorLookAndFeel::uiFont (7.5f));
    g.setColour (CompColours::textGhost());

    for (int db : { -6, -18, -30, -42 })
    {
        const float y = base - (float) ((db - minDb) / -minDb) * (base - topo);
        g.drawText (juce::String (db),
                    juce::Rectangle<float> (area.getCentreX() - 14.0f, y - 6.0f, 28.0f, 12.0f),
                    juce::Justification::centred);
    }

    CompressorLookAndFeel::drawTrackedText (g, juce::String::fromUTF8 ("dBFS \xc2\xb7 PICO"),
        { area.getX(), area.getBottom() - 16.0f, area.getWidth(), 12.0f },
        CompColours::textFaint(), 8.0f, 1.2f, juce::Justification::centred);
}


// ============================================================================
//  TelemetryPanel
// ============================================================================

void TelemetryPanel::setReading (const Reading& r)
{
    data = r;
    repaint();
}

void TelemetryPanel::row (juce::Graphics& g, juce::Rectangle<float>& area,
                          const juce::String& key, const juce::String& value,
                          juce::Colour valueColour) const
{
    const auto line = area.removeFromTop (27.0f).reduced (12.0f, 0.0f);

    g.setColour (CompColours::textDim());
    g.setFont (CompressorLookAndFeel::uiFont (10.5f));
    g.drawText (key, line, juce::Justification::centredLeft);

    g.setColour (valueColour);
    g.setFont (CompressorLookAndFeel::uiFont (12.5f));
    g.drawText (value, line, juce::Justification::centredRight);
}

void TelemetryPanel::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    CompressorLookAndFeel::drawPanel (g, area, "TELEMETRIA DA CAMADA ADAPTATIVA");

    const auto menosS = juce::String::fromUTF8 ("\xe2\x88\x92");
    auto dbs = [&] (double v, int c)
    {
        return (v < 0 ? menosS : juce::String()) + numero (std::abs (v), c);
    };

    //  Duas colunas: o que o sistema MEDE a esquerda, o que ele DECIDE a
    //  direita. A separacao espelha a propria arquitetura -- estimadores de
    //  um lado, leis de adaptacao do outro.
    auto corpo = area.withTrimmedTop (30.0f).withTrimmedBottom (10.0f);
    auto esq = corpo.removeFromLeft (corpo.getWidth() * 0.5f);
    auto dir = corpo;

    CompressorLookAndFeel::drawTrackedText (g, "ESTIMATIVAS",
        esq.removeFromTop (14.0f).withTrimmedLeft (12.0f), CompColours::textFaint(), 9.0f, 1.6f);
    esq.removeFromTop (6.0f);

    row (g, esq, "Fator de crista",      dbs (data.crestDb, 1) + " dB",   CompColours::textBright());
    row (g, esq, juce::String::fromUTF8 ("N\xc3\xadvel de curto prazo"),
                                         dbs (data.levelDb, 1) + " dBFS", CompColours::textBright());
    row (g, esq, juce::String::fromUTF8 ("M\xc3\xa9""dia \xc2\xb7 desvio"),
                                         dbs (data.meanDb, 1) + " \xc2\xb7 " + numero (data.stdDevDb, 1) + " dB",
                                         CompColours::textBright());
    row (g, esq, juce::String::fromUTF8 ("Redu\xc3\xa7\xc3\xa3o de ganho"),
                                         dbs (data.reductionDb, 1) + " dB", CompColours::adapt());
    row (g, esq, "Estado", data.warmedUp ? "AQUECIDO" : "AQUECENDO",
                                         data.warmedUp ? CompColours::ok() : CompColours::textFaint());

    CompressorLookAndFeel::drawTrackedText (g, juce::String::fromUTF8 ("PAR\xc3\x82METROS EM VIGOR"),
        dir.removeFromTop (14.0f).withTrimmedLeft (12.0f), CompColours::textFaint(), 9.0f, 1.6f);
    dir.removeFromTop (6.0f);

    row (g, dir, "Limiar T",       dbs (data.thresholdDb, 1) + " dB",
         data.autoThreshold ? CompColours::adapt() : CompColours::textBright());
    row (g, dir, juce::String::fromUTF8 ("Raz\xc3\xa3o R"), numero (data.ratio, 2) + " : 1",
         data.autoRatio ? CompColours::adapt() : CompColours::textBright());
    row (g, dir, juce::String::fromUTF8 ("Ataque \xcf\x84\xe2\x82\x90"), numero (data.attackMs, 1) + " ms",
         data.autoAttack ? CompColours::adapt() : CompColours::textBright());
    row (g, dir, juce::String::fromUTF8 ("Compensa\xc3\xa7\xc3\xa3o M"),
         (data.makeupDb >= 0 ? "+" : menosS) + numero (std::abs (data.makeupDb), 1) + " dB",
         data.autoMakeup ? CompColours::adapt() : CompColours::textBright());

    //  Resumo dos modos: a cor ja distingue manual de adaptado nos valores
    //  acima, de modo que basta uma linha dizendo quais estao em vigor.
    juce::StringArray ativos;
    if (data.autoThreshold) ativos.add ("T");
    if (data.autoRatio)     ativos.add ("R");
    if (data.autoAttack)    ativos.add (juce::String::fromUTF8 ("\xcf\x84\xe2\x82\x90"));
    if (data.autoMakeup)    ativos.add ("M");

    row (g, dir, "Modos ativos",
         ativos.isEmpty() ? juce::String ("nenhum") : ativos.joinIntoString (juce::String::fromUTF8 (" \xc2\xb7 ")),
         ativos.isEmpty() ? CompColours::textGhost() : CompColours::adapt());
}
