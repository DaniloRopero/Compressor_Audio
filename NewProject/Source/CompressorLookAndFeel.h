#pragma once

#include <JuceHeader.h>

// ============================================================================
//  Linguagem visual compartilhada do plugin.
//
//  Toda a interface e desenhada proceduralmente -- nenhuma imagem rasterizada
//  e carregada. A opcao tem tres consequencias praticas: o binario nao carrega
//  recursos graficos, a interface permanece nitida em telas de alta densidade,
//  e qualquer alteracao de cor se faz em um unico lugar.
//
//  A organizacao em um namespace de cores mais uma subclasse de LookAndFeel_V4
//  segue a pratica adotada em projetos JUCE de codigo aberto, entre eles
//  BORATO GRAVITAS (BORATO, 2026), licenciado sob MIT.
// ============================================================================

namespace CompColours
{
    // Fundo e paineis
    inline juce::Colour faceTop()     { return juce::Colour::fromRGB(0x22, 0x26, 0x2d); }
    inline juce::Colour faceBottom()  { return juce::Colour::fromRGB(0x1a, 0x1d, 0x23); }
    inline juce::Colour headerBg()    { return juce::Colour::fromRGB(0x1e, 0x21, 0x27); }
    inline juce::Colour panelBg()     { return juce::Colour::fromRGB(0x19, 0x1c, 0x21); }
    inline juce::Colour panelEdge()   { return juce::Colour::fromRGB(0x2d, 0x33, 0x3b); }
    inline juce::Colour plotBg()      { return juce::Colour::fromRGB(0x13, 0x16, 0x19); }

    // Grade
    inline juce::Colour gridMinor()   { return juce::Colour::fromRGB(0x1d, 0x22, 0x27); }
    inline juce::Colour gridMajor()   { return juce::Colour::fromRGB(0x26, 0x2c, 0x33); }
    inline juce::Colour gridUnity()   { return juce::Colour::fromRGB(0x39, 0x41, 0x4a); }

    // Texto
    inline juce::Colour textBright()  { return juce::Colour::fromRGB(0xe6, 0xed, 0xf3); }
    inline juce::Colour textLabel()   { return juce::Colour::fromRGB(0xc9, 0xd1, 0xd9); }
    inline juce::Colour textDim()     { return juce::Colour::fromRGB(0x8b, 0x94, 0x9e); }
    inline juce::Colour textFaint()   { return juce::Colour::fromRGB(0x6e, 0x76, 0x81); }
    inline juce::Colour textGhost()   { return juce::Colour::fromRGB(0x5a, 0x62, 0x6c); }

    // Acentos
    //   accent -- parametro sob controle manual
    //   adapt  -- parametro sob controle da camada adaptativa
    inline juce::Colour accent()      { return juce::Colour::fromRGB(0x45, 0xb7, 0xc4); }
    inline juce::Colour adapt()       { return juce::Colour::fromRGB(0xe0, 0xa4, 0x58); }
    inline juce::Colour adaptBright() { return juce::Colour::fromRGB(0xf0, 0xd0, 0x90); }
    inline juce::Colour ok()          { return juce::Colour::fromRGB(0x5f, 0xd3, 0x8d); }

    // Knob
    inline juce::Colour knobTrack()   { return juce::Colour::fromRGB(0x2d, 0x33, 0x3b); }
    inline juce::Colour knobFace()    { return juce::Colour::fromRGB(0x23, 0x28, 0x30); }
    inline juce::Colour knobEdge()    { return juce::Colour::fromRGB(0x36, 0x3d, 0x46); }
}

class CompressorLookAndFeel final : public juce::LookAndFeel_V4
{
public:
    CompressorLookAndFeel();

    //  Fonte tecnica da interface, em altura dada em pixels.
    static juce::Font uiFont (float height, bool bold = false);

    //  Largura de um texto na fonte dada.
    //
    //  Concentrada em um unico metodo de proposito: a API de medicao de texto
    //  do JUCE mudou na versao 8, e se o compilador recusar a chamada interna
    //  basta substitui-la aqui, sem tocar no restante da interface.
    static float textWidth (const juce::Font&, const juce::String&);

    //  Desenha texto em caixa alta com espacamento entre letras. O JUCE nao
    //  expoe tracking tipografico, de modo que cada caractere e posicionado
    //  individualmente.
    static void drawTrackedText (juce::Graphics&, const juce::String& text,
                                 juce::Rectangle<float> area, juce::Colour colour,
                                 float fontHeight, float tracking,
                                 juce::Justification just = juce::Justification::centredLeft);

    static void fillVerticalGradient (juce::Graphics&, juce::Rectangle<float> area,
                                      juce::Colour top, juce::Colour bottom);

    //  Painel padrao: fundo, contorno e legenda no canto superior esquerdo.
    //  A legenda e desenhada como recebida -- juce::String::toUpperCase nao
    //  converte todos os caracteres acentuados (o til minusculo, entre eles),
    //  de modo que a caixa alta e responsabilidade de quem chama.
    static void drawPanel (juce::Graphics&, juce::Rectangle<float> area,
                           const juce::String& caption);

    static void strokeDashed (juce::Graphics&, const juce::Path& src,
                              float thickness, float on, float off);

    //  Knob do projeto: arco de trilho, arco de valor e ponteiro. A cor do
    //  arco de valor e lida da propria Slider (colourId rotarySliderFillId),
    //  o que permite alterna-la entre accent e adapt sem subclasse.
    void drawRotarySlider (juce::Graphics&, int x, int y, int width, int height,
                           float sliderPos, float rotaryStartAngle,
                           float rotaryEndAngle, juce::Slider&) override;
};
