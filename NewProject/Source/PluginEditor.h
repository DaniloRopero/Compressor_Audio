#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "CompressorLookAndFeel.h"
#include "CompressorComponents.h"

// ============================================================================
//  Editor do plugin.
//
//  Vive na linha de MENSAGENS, separada da linha de AUDIO onde processBlock
//  executa. O editor nunca le o estado interno do processador diretamente:
//  obtem os valores de exibicao pelos acessores atomicos, a 30 Hz, por meio de
//  juce::Timer. Esse desacoplamento e o que impede que o desenho da interface
//  introduza espera na linha de audio.
//
//  O editor apenas compoe e distribui componentes; nenhum desenho de controle
//  ocorre aqui, o que mantem a classe curta e cada elemento verificavel em
//  separado.
// ============================================================================
class CompressorAudioProcessorEditor final : public juce::AudioProcessorEditor,
                                             private juce::Timer
{
public:
    explicit CompressorAudioProcessorEditor (CompressorAudioProcessor&);
    ~CompressorAudioProcessorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    void timerCallback() override;

    CompressorAudioProcessor& processor;
    CompressorLookAndFeel     lnf;

    StaticCurveComponent  curve  { lnf };
    GainReductionMeter    meter  { lnf };
    TelemetryPanel        tele   { lnf };
    LevelHistoryComponent hist   { lnf };
    LevelLadder           ladder { lnf };

    ParameterKnob knobThreshold { lnf, processor.apvts, "threshold", "Threshold", "dB", 1, "adaptThreshold" };
    ParameterKnob knobRatio     { lnf, processor.apvts, "ratio",     "Ratio",     ":1", 2, "adaptRatio"     };
    ParameterKnob knobKnee      { lnf, processor.apvts, "knee",      "Knee",      "dB", 1 };
    ParameterKnob knobAttack    { lnf, processor.apvts, "attack",    "Attack",    "ms", 1, "adaptAttack"    };
    ParameterKnob knobRelease   { lnf, processor.apvts, "release",   "Release",   "ms", 0 };
    ParameterKnob knobMakeup    { lnf, processor.apvts, "makeup",    "Make-up",   "dB", 1, "autoMakeup", true };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (CompressorAudioProcessorEditor)
};
