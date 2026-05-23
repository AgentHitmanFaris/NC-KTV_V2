#include "waveform_renderer.h"
#include "../core/audio/audio_engine.h"
#include <algorithm>
#include <iostream>
#include <cmath>

namespace ncktv {

WaveformRenderer::WaveformRenderer(QQuickItem* parent)
    : QQuickPaintedItem(parent) {
    setAntialiasing(true);
}

void WaveformRenderer::setSourceFile(const QString& filePath) {
    if (m_sourceFile != filePath) {
        m_sourceFile = filePath;
        emit sourceFileChanged();
        update(); // Request repaint
    }
}

void WaveformRenderer::setSourceStart(qint64 startUs) {
    if (m_sourceStart != startUs) {
        m_sourceStart = startUs;
        emit sourceStartChanged();
        update(); // Request repaint
    }
}

void WaveformRenderer::setDuration(qint64 durationUs) {
    if (m_duration != durationUs) {
        m_duration = durationUs;
        emit durationChanged();
        update(); // Request repaint
    }
}

void WaveformRenderer::paint(QPainter* painter) {
    if (m_sourceFile.isEmpty() || m_duration <= 0) {
        return;
    }

    AudioEngine* engine = AudioEngine::instance();
    if (!engine) {
        return;
    }

    AudioReader* reader = engine->getReader(m_sourceFile);
    if (!reader) {
        return;
    }

    double w = width();
    double h = height();
    if (w <= 0.0 || h <= 0.0) {
        return;
    }

    // Determine frames per pixel to choose LOD level automatically
    double clipDurationSec = m_duration / 1000000.0;
    double clipTotalFrames = clipDurationSec * 48000.0;
    double framesPerPixel = clipTotalFrames / w;

    // Use LOD 4096 if frames per pixel is very large, otherwise use LOD 256
    bool useLOD4096 = (framesPerPixel >= 2048.0);
    const auto& peaks = useLOD4096 ? reader->peaks4096() : reader->peaks256();
    qint64 N = useLOD4096 ? 4096 : 256;

    if (peaks.empty()) {
        return;
    }

    // Setup Premium Theme vertical linear gradient
    QLinearGradient gradient(0, 0, 0, h);
    gradient.setColorAt(0.0, QColor("#7C4DFF")); // Electric violet peaks
    gradient.setColorAt(0.5, QColor(26, 26, 36, 120)); // Deep translucent charcoal center zero line
    gradient.setColorAt(1.0, QColor("#7C4DFF")); // Electric violet peaks

    float barWidth = 2.0f;
    float barSpacing = 4.0f; // Gap of 2px between 2px bars

    QPen pen(QBrush(gradient), barWidth, Qt::SolidLine, Qt::RoundCap);
    painter->setPen(pen);

    float max_h = (h / 2.0f) * 0.9f; // Leave 10% padding
    float y_center = h / 2.0f;

    // Draw individual dual-sided rounded bars
    for (float x = barWidth / 2.0f; x < w; x += barSpacing) {
        // Map x coordinate to absolute microsecond time in the source file
        double progress = x / w;
        qint64 pixelTimeUs = m_sourceStart + static_cast<qint64>(progress * m_duration);

        // Compute corresponding peak index
        qint64 peakIndex = (pixelTimeUs * 48000) / (N * 1000000);
        peakIndex = (std::clamp)(peakIndex, 0LL, static_cast<qint64>(peaks.size() - 1));

        float minVal = peaks[peakIndex].minVal;
        float maxVal = peaks[peakIndex].maxVal;

        // Vertical lines coordinates
        float y_top = y_center - (maxVal * max_h);
        float y_bottom = y_center - (minVal * max_h);

        // Silence protection: make sure there is at least a 2px tall center tick so it doesn't look invisible
        if (std::abs(y_bottom - y_top) < 2.0f) {
            y_top = y_center - 1.0f;
            y_bottom = y_center + 1.0f;
        }

        painter->drawLine(QPointF(x, y_top), QPointF(x, y_bottom));
    }
}

} // namespace ncktv
