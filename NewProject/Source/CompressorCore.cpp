#include "CompressorCore.h"

namespace
{
    constexpr double kEpsilon = 1.0e-9;
}

void CompressorCore::prepare (double sampleRateHz) noexcept
{
    fs = sampleRateHz;
    reset();
}

void CompressorCore::reset() noexcept
{
    yL = 0.0;
}

void CompressorCore::setParameters (double thresholdDb,
                                    double ratio,
                                    double attackMs,
                                    double releaseMs,
                                    double kneeDb,
                                    double makeupDb) noexcept
{
    T     = thresholdDb;
    invR  = 1.0 / ratio;
    W     = kneeDb;
    halfW = 0.5 * kneeDb;
    M     = makeupDb;

    alphaA = std::exp (-1.0 / (fs * attackMs  * 1.0e-3));
    alphaR = std::exp (-1.0 / (fs * releaseMs * 1.0e-3));
}

double CompressorCore::nextGain (double detector) noexcept
{
    const double xG = 20.0 * std::log10 (detector + kEpsilon);

    double cG;

    if (W > 0.0 && 2.0 * std::abs (xG - T) <= W)
    {
        const double d = xG - T + halfW;
        cG = xG + (invR - 1.0) * d * d / (2.0 * W);
    }
    else if (xG > T + halfW)
    {
        cG = T + (xG - T) * invR;
    }
    else
    {
        cG = xG;
    }

    const double gainDB = cG - xG;

    if (gainDB < yL)
        yL = alphaA * yL + (1.0 - alphaA) * gainDB;
    else
        yL = alphaR * yL + (1.0 - alphaR) * gainDB;

    return std::pow (10.0, (yL + M) / 20.0);
}
