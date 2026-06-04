#include "waveform_renderer.h"
#include "../core/audio/audio_engine.h"
#include <algorithm>
#include <iostream>
#include <cmath>

namespace ncktv {

WaveformRenderer::WaveformRenderer(QQuickItem* parent)
    : QQuickPaintedItem(parent) {
    setAntialiasing(true);
    setRenderTarget(QQuickPaintedItem::FramebufferObject);
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

    double w = width();
    double h = height();
    if (w <= 0.0 || h <= 0.0) {
        return;
    }

    // Clear destination rect to transparent to prevent double buffering ghosting
    painter->save();
    painter->setCompositionMode(QPainter::CompositionMode_Source);
    painter->fillRect(0, 0, w, h, Qt::transparent);
    painter->restore();

    // Check if cache is valid
    bool cacheValid = (m_cachedSourceFile == m_sourceFile &&
                       m_cachedSourceStart == m_sourceStart &&
                       m_cachedDuration == m_duration &&
                       qFuzzyCompare(m_cachedWidth, w) &&
                       qFuzzyCompare(m_cachedHeight, h) &&
                       !m_cachedImage.isNull());

    if (cacheValid) {
        painter->drawImage(0, 0, m_cachedImage);
        return;
    }

    // Cache invalid: render to QImage first
    m_cachedImage = QImage(static_cast<int>(w), static_cast<int>(h), QImage::Format_RGBA8888_Premultiplied);
    m_cachedImage.fill(Qt::transparent);

    QPainter cachePainter(&m_cachedImage);
    cachePainter.setRenderHint(QPainter::Antialiasing, true);

    AudioEngine* engine = AudioEngine::instance();
    if (!engine) {
        return;
    }

    AudioReader* reader = engine->getReader(m_sourceFile);
    if (!reader) {
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

    if (!peaks.empty()) {
        // Setup Premium Theme vertical linear gradient
        QLinearGradient gradient(0, 0, 0, h);
        gradient.setColorAt(0.0, QColor("#7C4DFF")); // Electric violet peaks
        gradient.setColorAt(0.5, QColor(26, 26, 36, 120)); // Deep translucent charcoal center zero line
        gradient.setColorAt(1.0, QColor("#7C4DFF")); // Electric violet peaks

        float barWidth = 2.0f;
        float barSpacing = 4.0f; // Gap of 2px between 2px bars

        QPen pen(QBrush(gradient), barWidth, Qt::SolidLine, Qt::RoundCap);
        cachePainter.setPen(pen);

        float max_h = (h / 2.0f) * 0.9f; // Leave 10% padding
        float y_center = h / 2.0f;

        // Draw dual-sided rounded bars in a single batched vector call for maximum GPU pipeline efficiency
        QList<QLineF> lines;
        lines.reserve(static_cast<int>(w / barSpacing) + 1);

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

            lines.append(QLineF(x, y_top, x, y_bottom));
        }
        cachePainter.drawLines(lines);
    }

    cachePainter.end();

    // Update cached parameters
    m_cachedSourceFile = m_sourceFile;
    m_cachedSourceStart = m_sourceStart;
    m_cachedDuration = m_duration;
    m_cachedWidth = w;
    m_cachedHeight = h;

    // Paint the newly cached image
    painter->drawImage(0, 0, m_cachedImage);
}

} // namespace ncktv
