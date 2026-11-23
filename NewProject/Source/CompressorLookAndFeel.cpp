#include "CompressorLookAndFeel.h"

CompressorLookAndFeel::CompressorLookAndFeel()
{
    setColour (juce::Slider::rotarySliderFillColourId,    CompColours::accent());
    setColour (juce::Slider::rotarySliderOutlineColourId, CompColours::knobTrack());
    setColour (juce::Label::textColourId,                 CompColours::textLabel());
    setColour (juce::TooltipWindow::backgroundColourId,   CompColours::panelBg());
    setColour (juce::TooltipWindow::textColourId,         CompColours::textLabel());
    setColour (juce::TooltipWindow::outlineColourId,      CompColours::panelEdge());
}

juce::Font CompressorLookAndFeel::uiFont (float height, bool bold)
{
    return juce::Font (juce::FontOptions()
                           .withHeight (height)
                           .withStyle (bold ? "Bold" : "Regular"));
}

float CompressorLookAndFeel::textWidth (const juce::Font& f, const juce::String& t)
{
    return juce::GlyphArrangement::getStringWidth (f, t);
}

void CompressorLookAndFeel::drawTrackedText (juce::Graphics& g, const juce::String& text,
                                             juce::Rectangle<float> area, juce::Colour colour,
                                             float fontHeight, float tracking,
                                             juce::Justification just)
{
    const auto font = uiFont (fontHeight);
    g.setFont (font);
    g.setColour (colour);

    //  Largura total = soma das larguras dos glifos + tracking entre eles.
    float total = 0.0f;
    for (int i = 0; i < text.length(); ++i)
        total += textWidth (font, text.substring (i, i + 1)) + tracking;
    total -= tracking;

    float x = area.getX();
    if (just.testFlags (juce::Justification::horizontallyCentred))
        x = area.getCentreX() - total * 0.5f;
    else if (just.testFlags (juce::Justification::right))
        x = area.getRight() - total;

    const float y = area.getCentreY() + fontHeight * 0.35f;

    for (int i = 0; i < text.length(); ++i)
    {
        const auto ch = text.substring (i, i + 1);
        g.drawSingleLineText (ch, juce::roundToInt (x), juce::roundToInt (y));
        x += textWidth (font, ch) + tracking;
    }
}

void CompressorLookAndFeel::fillVerticalGradient (juce::Graphics& g, juce::Rectangle<float> area,
                                                  juce::Colour top, juce::Colour bottom)
{
    g.setGradientFill (juce::ColourGradient (top,    area.getX(), area.getY(),
                                             bottom, area.getX(), area.getBottom(), false));
    g.fillRect (area);
}

void CompressorLookAndFeel::drawPanel (juce::Graphics& g, juce::Rectangle<float> area,
                                       const juce::String& caption)
{
    g.setColour (CompColours::panelBg());
    g.fillRoundedRectangle (area, 3.0f);
    g.setColour (CompColours::panelEdge());
    g.drawRoundedRectangle (area.reduced (0.5f), 3.0f, 1.0f);

    if (caption.isNotEmpty())
        drawTrackedText (g, caption,
                         { area.getX() + 11.0f, area.getY() + 4.0f, area.getWidth() - 22.0f, 14.0f },
                         CompColours::textFaint(), 9.0f, 1.6f);
}

void CompressorLookAndFeel::strokeDashed (juce::Graphics& g, const juce::Path& src,
                                          float thickness, float on, float off)
{
    const float dashes[] = { on, off };
    juce::Path dashed;
    juce::PathStrokeType (thickness).createDashedStroke (dashed, src, dashes, 2);
    g.fillPath (dashed);
}

void CompressorLookAndFeel::drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height,
                                              float sliderPos, float rotaryStartAngle,
                                              float rotaryEndAngle, juce::Slider& s)
{
    const auto bounds = juce::Rectangle<int> (x, y, width, height).toFloat().reduced (4.0f);
    const auto centre = bounds.getCentre();
    const float radius = juce::jmin (bounds.getWidth(), bounds.getHeight()) * 0.5f;
    const float ringR  = radius - 2.5f;
    const float angle  = rotaryStartAngle + sliderPos * (rotaryEndAngle - rotaryStartAngle);

    const auto fill = s.findColour (juce::Slider::rotarySliderFillColourId);

    //  Trilho completo.
    juce::Path track;
    track.addCentredArc (centre.x, centre.y, ringR, ringR, 0.0f,
                         rotaryStartAngle, rotaryEndAngle, true);
    g.setColour (CompColours::knobTrack());
    g.strokePath (track, juce::PathStrokeType (5.0f, juce::PathStrokeType::curved,
                                               juce::PathStrokeType::rounded));

    //  Arco de valor.
    if (angle > rotaryStartAngle + 0.001f)
    {
        juce::Path value;
        value.addCentredArc (centre.x, centre.y, ringR, ringR, 0.0f,
                             rotaryStartAngle, angle, true);
        g.setColour (fill);
        g.strokePath (value, juce::PathStrokeType (5.0f, juce::PathStrokeType::curved,
                                                   juce::PathStrokeType::rounded));
    }

    //  Corpo do knob.
    const float faceR = ringR - 8.5f;
    g.setColour (CompColours::knobFace());
    g.fillEllipse (centre.x - faceR, centre.y - faceR, faceR * 2.0f, faceR * 2.0f);
    g.setColour (CompColours::knobEdge());
    g.drawEllipse (centre.x - faceR, centre.y - faceR, faceR * 2.0f, faceR * 2.0f, 1.0f);

    //  Ponteiro.
    const float dx = std::sin (angle), dy = -std::cos (angle);
    g.setColour (fill);
    g.drawLine (centre.x + dx * faceR * 0.38f, centre.y + dy * faceR * 0.38f,
                centre.x + dx * faceR * 0.84f, centre.y + dy * faceR * 0.84f,
                2.4f);
}
