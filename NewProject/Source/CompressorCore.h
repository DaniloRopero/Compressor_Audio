#pragma once

#include <cmath>
#include <algorithm>

class CompressorCore
{
public:
    void prepare (double sampleRateHz) noexcept;
    void reset() noexcept;

    void setParameters (double thresholdDb,
                        double ratio,
                        double attackMs,
                        double releaseMs,
                        double kneeDb,
                        double makeupDb) noexcept;

    double nextGain (double detector) noexcept;

    double getGainReductionDb() const noexcept { return yL; }

private:
    double fs     { 44100.0 };
    double T      { -12.0 };
    double invR   { 0.25 };
    double W      { 6.0 };
    double halfW  { 3.0 };
    double M      { 6.0 };
    double alphaA { 0.0 };
    double alphaR { 0.0 };
    double yL     { 0.0 };
};
