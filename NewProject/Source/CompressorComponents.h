#pragma once

#include <JuceHeader.h>
#include "CompressorLookAndFeel.h"

// ============================================================================
//  Componentes da interface.
//
//  Cada classe tem uma responsabilidade unica e nao conhece o processador:
//  recebe os valores a exibir por metodos set..., chamados pelo editor a cada
//  disparo do temporizador. A separacao mantem os componentes isentos de
//  qualquer acesso a linha de audio e torna cada um verificavel isoladamente.
// ============================================================================


// ----------------------------------------------------------------------------
//  ParameterKnob -- knob rotativo com legenda, leitura numerica e, quando o
//  parametro possui modo automatico, uma chave AUTO abaixo.
//
//  Com a chave acionada o knob deixa de responder ao mouse e passa a exibir o
//  valor imposto pela camada adaptativa, com o arco em ambar. O parametro
//  manual permanece armazenado no APVTS e volta a vigorar quando a chave e
//  desligada -- a interface nao o sobrescreve.
// ----------------------------------------------------------------------------
class ParameterKnob final : public juce::Component
{
public:
    ParameterKnob (CompressorLookAndFeel& lnf,
                   juce::AudioProcessorValueTreeState& apvts,
                   const juce::String& paramId,
                   juce::String caption,
                   juce::String unit,
                   int decimals,
                   const juce::String& autoParamId = {},
                   bool mostraSinal = false);

    //  Valor imposto pela camada adaptativa, em unidade de engenharia.
    //  Ignorado enquanto a chave AUTO estiver desligada.
    void setAdaptedValue (double value);

    bool isAutomatic() const noexcept;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    juce::String formatValue (double v) const;
    void refreshMode();

    CompressorLookAndFeel& lnf;
    juce::AudioProcessorValueTreeState& apvts;
    juce::String paramId, caption, unit;
    int decimals;
    bool mostraSinal { false };   // prefixa "+" em valores positivos

    juce::Slider      knob { juce::Slider::RotaryHorizontalVerticalDrag,
                             juce::Slider::NoTextBox };
    juce::TextButton  autoButton { "AUTO" };
    bool              hasAuto { false };

    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> knobAttach;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> autoAttach;

    double adaptedValue { 0.0 };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ParameterKnob)
};


// ----------------------------------------------------------------------------
//  StaticCurveComponent -- curva estatica de compressao.
//
//  Tracado ponto a ponto da mesma funcao do computador de ganho implementada
//  no nucleo (Equacao 4.22), de modo que a figura exibida e a funcao de fato
//  aplicada, e nao uma ilustracao aproximada. Sao desenhados ainda a reta 1:1
//  de referencia, a faixa do joelho, a marca do limiar e o ponto de operacao
//  corrente.
// ----------------------------------------------------------------------------
class StaticCurveComponent final : public juce::Component
{
public:
    explicit StaticCurveComponent (CompressorLookAndFeel& lnf) : lnf (lnf) {}

    //  Parametros em vigor -- manuais ou adaptados, conforme o estado das
    //  chaves. A curva reflete sempre o que esta sendo aplicado.
    void setParameters (double thresholdDb, double ratio, double kneeDb);

    //  Nivel de entrada corrente, para o marcador movel.
    void setOperatingPoint (double inputDb);

    void paint (juce::Graphics&) override;

private:
    //  Computador de ganho -- Equacao 4.22. Replicada aqui por ser funcao
    //  pura e de uma linha; manter a copia evita que o componente dependa do
    //  nucleo de processamento.
    double gainComputer (double xG) const;

    CompressorLookAndFeel& lnf;
    double thresholdDb { -12.0 }, ratio { 4.0 }, kneeDb { 6.0 };
    double inputDb { -60.0 };

    static constexpr double loDb = -60.0, hiDb = 0.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StaticCurveComponent)
};


// ----------------------------------------------------------------------------
//  GainReductionMeter -- barra vertical de reducao de ganho, pendurada no
//  topo da escala, com retencao de pico de decaimento lento.
// ----------------------------------------------------------------------------
class GainReductionMeter final : public juce::Component
{
public:
    explicit GainReductionMeter (CompressorLookAndFeel& lnf) : lnf (lnf) {}

    //  Reducao em dB, valor positivo (3,0 significa 3 dB de atenuacao).
    void setReduction (double reductionDb);

    void paint (juce::Graphics&) override;

private:
    CompressorLookAndFeel& lnf;
    double current { 0.0 }, peakHold { 0.0 };
    int    holdCounter { 0 };

    static constexpr double maxDb = 24.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GainReductionMeter)
};


// ----------------------------------------------------------------------------
//  LevelHistoryComponent -- display temporal.
//
//  Mostra os ultimos segundos de operacao: o pico de entrada como area
//  preenchida, o pico de saida como traco, e a reducao de ganho pendurada no
//  alto da escala. E aqui que o ataque e a liberacao se tornam visiveis -- a
//  reducao mergulha no transiente e retorna devagar, assimetria que a curva
//  estatica, por nao ter eixo de tempo, e incapaz de exibir.
//
//  O componente nao guarda estado proprio: recebe o trecho de historico ja
//  ordenado do mais antigo para o mais recente.
// ----------------------------------------------------------------------------
class LevelHistoryComponent final : public juce::Component
{
public:
    explicit LevelHistoryComponent (CompressorLookAndFeel& lnf) : lnf (lnf) {}

    struct Point { float inDb, outDb, grDb; };

    //  'pontos' vem em ordem cronologica; 'segundos' e o intervalo coberto.
    void setHistory (const std::vector<Point>& pontos, double segundos);

    //  Limiar em vigor, para a linha de referencia.
    void setThreshold (double thresholdDb);

    void paint (juce::Graphics&) override;

private:
    CompressorLookAndFeel& lnf;
    std::vector<Point> dados;
    double janelaSegundos { 0.0 };
    double thresholdDb { -12.0 };

    static constexpr double loDb = -54.0, hiDb = 0.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (LevelHistoryComponent)
};


// ----------------------------------------------------------------------------
//  LevelLadder -- medidores de pico de entrada e de saida, em escada de
//  segmentos, com retencao de pico.
//
//  Servem a uma pergunta que nenhum outro elemento responde: se o nivel que
//  CHEGA e adequado, e se o que SAI esta sob controle depois da compensacao.
// ----------------------------------------------------------------------------
class LevelLadder final : public juce::Component
{
public:
    explicit LevelLadder (CompressorLookAndFeel& lnf) : lnf (lnf) {}

    void setLevels (double inDb, double outDb);

    void paint (juce::Graphics&) override;

private:
    struct Coluna
    {
        double nivel { -60.0 };
        double pico  { -60.0 };
        int    reter {    0  };
    };

    void desenhaColuna (juce::Graphics&, juce::Rectangle<float>,
                        const Coluna&, const juce::String& rotulo) const;

    CompressorLookAndFeel& lnf;
    Coluna entrada, saida;

    static constexpr double minDb = -54.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (LevelLadder)
};


// ----------------------------------------------------------------------------
//  TelemetryPanel -- leitura das grandezas estimadas pela camada adaptativa,
//  dos parametros em vigor e do estado de cada modo.
//
//  O painel existe por uma razao de projeto, e nao de ornamento: sem ele os
//  mecanismos do Capitulo 9 operariam de forma invisivel ao usuario, que veria
//  os parametros mudarem sem saber por que. A exibicao do fator de crista, da
//  media e do desvio padrao torna a lei de adaptacao auditavel em operacao.
// ----------------------------------------------------------------------------
class TelemetryPanel final : public juce::Component
{
public:
    explicit TelemetryPanel (CompressorLookAndFeel& lnf) : lnf (lnf) {}

    struct Reading
    {
        double crestDb      { 0.0 };
        double levelDb      { -60.0 };
        double meanDb       { -60.0 };
        double stdDevDb     { 0.0 };
        double thresholdDb  { -12.0 };
        double ratio        { 4.0 };
        double attackMs     { 10.0 };
        double makeupDb     { 6.0 };
        double reductionDb  { 0.0 };
        bool   warmedUp     { false };
        bool   autoThreshold{ false };
        bool   autoRatio    { false };
        bool   autoAttack   { false };
        bool   autoMakeup   { false };
    };

    void setReading (const Reading& r);

    void paint (juce::Graphics&) override;

private:
    void row (juce::Graphics&, juce::Rectangle<float>& area,
              const juce::String& key, const juce::String& value,
              juce::Colour valueColour) const;

    CompressorLookAndFeel& lnf;
    Reading data;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (TelemetryPanel)
};
