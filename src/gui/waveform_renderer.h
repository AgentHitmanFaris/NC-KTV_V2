#pragma once

#include <QQuickPaintedItem>
#include <QString>
#include <QColor>
#include <QPen>
#include <QBrush>
#include <QPainter>
#include <QLinearGradient>

namespace ncktv {

class WaveformRenderer : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString sourceFile READ sourceFile WRITE setSourceFile NOTIFY sourceFileChanged)
    Q_PROPERTY(qint64 sourceStart READ sourceStart WRITE setSourceStart NOTIFY sourceStartChanged)
    Q_PROPERTY(qint64 duration READ duration WRITE setDuration NOTIFY durationChanged)

public:
    explicit WaveformRenderer(QQuickItem* parent = nullptr);
    virtual ~WaveformRenderer() override = default;

    // Getters and Setters
    [[nodiscard]] QString sourceFile() const { return m_sourceFile; }
    void setSourceFile(const QString& filePath);

    [[nodiscard]] qint64 sourceStart() const { return m_sourceStart; }
    void setSourceStart(qint64 startUs);

    [[nodiscard]] qint64 duration() const { return m_duration; }
    void setDuration(qint64 durationUs);

    // Overridden QQuickPaintedItem paint method
    virtual void paint(QPainter* painter) override;

signals:
    void sourceFileChanged();
    void sourceStartChanged();
    void durationChanged();

private:
    QString m_sourceFile;
    qint64 m_sourceStart = 0; // Microseconds offset inside source file
    qint64 m_duration = 0;    // Microseconds duration of this clip
};

} // namespace ncktv
