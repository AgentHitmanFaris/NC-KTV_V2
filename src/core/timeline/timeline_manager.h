#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVariantList>
#include "track.h"
#include "models/track_list_model.h"
#include "models/clip_list_model.h"

namespace ncktv {

class TimelineManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList mediaList READ mediaList WRITE setMediaList NOTIFY mediaListChanged)
    Q_PROPERTY(bool isDirty READ isDirty WRITE setIsDirty NOTIFY isDirtyChanged)
    
    // Subtitle styles and timeline markers properties
    Q_PROPERTY(QVariantList markers READ markers WRITE setMarkers NOTIFY markersChanged)
    Q_PROPERTY(QString subtitleFontFamily READ subtitleFontFamily WRITE setSubtitleFontFamily NOTIFY subtitleFontFamilyChanged)
    Q_PROPERTY(int subtitleFontSize READ subtitleFontSize WRITE setSubtitleFontSize NOTIFY subtitleFontSizeChanged)
    Q_PROPERTY(QString subtitleFillColor READ subtitleFillColor WRITE setSubtitleFillColor NOTIFY subtitleFillColorChanged)
    Q_PROPERTY(QString subtitleActiveColor READ subtitleActiveColor WRITE setSubtitleActiveColor NOTIFY subtitleActiveColorChanged)
    Q_PROPERTY(QString subtitleOutlineColor READ subtitleOutlineColor WRITE setSubtitleOutlineColor NOTIFY subtitleOutlineColorChanged)
    Q_PROPERTY(int subtitleOutlineWidth READ subtitleOutlineWidth WRITE setSubtitleOutlineWidth NOTIFY subtitleOutlineWidthChanged)


    Q_PROPERTY(qint64 currentPlayheadTime READ currentPlayheadTime WRITE setCurrentPlayheadTime NOTIFY currentPlayheadTimeChanged)
    Q_PROPERTY(qint64 totalDuration READ totalDuration WRITE setTotalDuration NOTIFY totalDurationChanged)
    Q_PROPERTY(double fps READ fps WRITE setFps NOTIFY fpsChanged)
    Q_PROPERTY(TrackListModel* trackListModel READ trackListModel CONSTANT)
    Q_PROPERTY(bool isSeparating READ isSeparating NOTIFY isSeparatingChanged)
    Q_PROPERTY(double separationProgress READ separationProgress NOTIFY separationProgressChanged)
    Q_PROPERTY(QString separationStatusText READ separationStatusText NOTIFY separationStatusTextChanged)
    Q_PROPERTY(bool isRendering READ isRendering NOTIFY isRenderingChanged)
    Q_PROPERTY(double renderProgress READ renderProgress NOTIFY renderProgressChanged)
    Q_PROPERTY(QString renderStatusText READ renderStatusText NOTIFY renderStatusTextChanged)
    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(QStringList discoveredModels READ discoveredModels NOTIFY discoveredModelsChanged)
    Q_PROPERTY(QStringList discoveredModelPaths READ discoveredModelPaths NOTIFY discoveredModelsChanged)
    Q_PROPERTY(QString modelsDirPath READ modelsDirPath WRITE setModelsDirPath NOTIFY modelsDirPathChanged)

public:
    explicit TimelineManager(QObject* parent = nullptr);
    virtual ~TimelineManager() override;

    [[nodiscard]] QString modelPath() const { return m_modelPath; }
    void setModelPath(const QString& path);

    [[nodiscard]] QString modelsDirPath() const { return m_modelsDirPath; }
    void setModelsDirPath(const QString& path);

    [[nodiscard]] QStringList discoveredModels() const { return m_discoveredModels; }
    [[nodiscard]] QStringList discoveredModelPaths() const { return m_discoveredModelPaths; }

    Q_INVOKABLE void scanModelsDir();

    [[nodiscard]] bool isSeparating() const { return m_isSeparating; }
    [[nodiscard]] double separationProgress() const { return m_separationProgress; }
    [[nodiscard]] QString separationStatusText() const { return m_separationStatusText; }

    [[nodiscard]] bool isRendering() const { return m_isRendering; }
    [[nodiscard]] double renderProgress() const { return m_renderProgress; }
    [[nodiscard]] QString renderStatusText() const { return m_renderStatusText; }

    [[nodiscard]] QVariantList mediaList() const { return m_mediaList; }
    void setMediaList(const QVariantList& list);

    [[nodiscard]] bool isDirty() const { return m_isDirty; }
    void setIsDirty(bool dirty);
    Q_INVOKABLE void setDirty(bool dirty = true) { setIsDirty(dirty); }

    // Subtitle style getters & setters
    [[nodiscard]] QString subtitleFontFamily() const { return m_subtitleFontFamily; }
    void setSubtitleFontFamily(const QString& family);

    [[nodiscard]] int subtitleFontSize() const { return m_subtitleFontSize; }
    void setSubtitleFontSize(int size);

    [[nodiscard]] QString subtitleFillColor() const { return m_subtitleFillColor; }
    void setSubtitleFillColor(const QString& color);

    [[nodiscard]] QString subtitleActiveColor() const { return m_subtitleActiveColor; }
    void setSubtitleActiveColor(const QString& color);

    [[nodiscard]] QString subtitleOutlineColor() const { return m_subtitleOutlineColor; }
    void setSubtitleOutlineColor(const QString& color);

    [[nodiscard]] int subtitleOutlineWidth() const { return m_subtitleOutlineWidth; }
    void setSubtitleOutlineWidth(int width);

    // Markers getter, setter, and operations
    [[nodiscard]] QVariantList markers() const { return m_markers; }
    void setMarkers(const QVariantList& list);
    Q_INVOKABLE void addMarker(qint64 timeUs, const QString& name = "Marker", const QString& color = "green");
    Q_INVOKABLE void removeMarker(const QString& markerId);
    Q_INVOKABLE void updateMarker(const QString& markerId, const QString& name, const QString& color);


    [[nodiscard]] qint64 currentPlayheadTime() const { return m_currentPlayheadTime; }
    void setCurrentPlayheadTime(qint64 timeMicroseconds);

    [[nodiscard]] qint64 totalDuration() const { return m_totalDuration; }
    void setTotalDuration(qint64 durationMicroseconds);

    [[nodiscard]] double fps() const { return m_fps; }
    void setFps(double fpsValue);

    [[nodiscard]] TrackListModel* trackListModel() const { return m_trackListModel; }

    // Track Management
    Q_INVOKABLE QString addTrack(int type, const QString& name);
    Q_INVOKABLE bool removeTrack(const QString& trackId);
    Q_INVOKABLE QObject* getClipModelForTrack(const QString& trackId);

    // Timeline Operations
    Q_INVOKABLE bool addClipToTrack(const QString& trackId, const QString& clipId, int type, qint64 startTime, qint64 duration, const QString& sourceFile = "", const QString& lyricText = "");
    Q_INVOKABLE bool importLyricsFromFile(const QString& trackId, const QString& filePath);
    Q_INVOKABLE bool splitClip(const QString& trackId, const QString& clipId, qint64 splitTimeMicroseconds);
    Q_INVOKABLE void separateStems(const QString& clipId);
    Q_INVOKABLE void separateStemsForFile(const QString& filePath);
    Q_INVOKABLE void startExport(const QString& outputPath, int width, int height, int fps, int videoBitrate, int audioBitrate);
    Q_INVOKABLE void cancelExport();
    
    // Snapping Engine
    Q_INVOKABLE qint64 checkSnapping(const QString& excludeClipId, qint64 targetTimeMicroseconds, qint64 thresholdMicroseconds) const;
    
    // Collision Engine
    Q_INVOKABLE qint64 checkCollisions(const QString& trackId, const QString& clipId, qint64 targetTimeMicroseconds) const;

    // Timecode Utilities
    Q_INVOKABLE [[nodiscard]] QString formatTimecode(qint64 microseconds) const;
    Q_INVOKABLE [[nodiscard]] qint64 parseTimecode(const QString& timecode) const;
    Q_INVOKABLE [[nodiscard]] qint64 timeToFrames(qint64 microseconds) const;
    Q_INVOKABLE [[nodiscard]] qint64 framesToTime(qint64 frames) const;

    // Project Serialization (.nctv JSON files)
    Q_INVOKABLE bool saveProject(const QString& filePath);
    Q_INVOKABLE bool loadProject(const QString& filePath);
    Q_INVOKABLE void clearProject();

signals:
    void currentPlayheadTimeChanged();
    void totalDurationChanged();
    void fpsChanged();
    void projectLoaded();
    void projectCleared();
    void isSeparatingChanged();
    void separationProgressChanged();
    void separationStatusTextChanged();
    void isRenderingChanged();
    void renderProgressChanged();
    void renderStatusTextChanged();
    void exportCompleted(const QString& outputPath);
    void exportFailed(const QString& errorMessage);
    void modelPathChanged();
    void modelsDirPathChanged();
    void discoveredModelsChanged();
    void mediaListChanged();
    void isDirtyChanged();
    void mediaSeparationCompleted(const QString& vocalsPath, const QString& instPath);
    
    // Subtitle style and markers signals
    void subtitleFontFamilyChanged();
    void subtitleFontSizeChanged();
    void subtitleFillColorChanged();
    void subtitleActiveColorChanged();
    void subtitleOutlineColorChanged();
    void subtitleOutlineWidthChanged();
    void markersChanged();


private slots:
    void onSeparationProgress(double fraction);
    void onSeparationCompleted(const QString& clipId, const QString& vocalsPath, const QString& instPath);
    void onSeparationFailed(const QString& clipId, const QString& errorMessage);
    void onRenderProgress(double fraction);
    void onRenderStatusText(const QString& text);
    void onRenderCompleted(const QString& outputPath, const QString& videoCodec, const QString& audioCodec);
    void onRenderFailed(const QString& errorMessage);

private:
    void recalculateTotalDuration();

    qint64 m_currentPlayheadTime = 0; // In Microseconds
    qint64 m_totalDuration = 0;       // In Microseconds
    double m_fps = 30.0;              // Default NLE FPS

    TrackListModel* m_trackListModel = nullptr;
    QMap<QString, ClipListModel*> m_clipModels; // Managed Clip models per trackId

    bool m_isSeparating = false;
    double m_separationProgress = 0.0;
    QString m_separationStatusText;
    class StemSeparationWorker* m_separationWorker = nullptr;

    bool m_isRendering = false;
    double m_renderProgress = 0.0;
    QString m_renderStatusText;
    class RenderWorker* m_renderWorker = nullptr;

    QString m_modelPath;
    QString m_modelsDirPath;
    QStringList m_discoveredModels;
    QStringList m_discoveredModelPaths;
    QVariantList m_mediaList;
    bool m_isDirty = false;

    // Subtitle style and markers variables
    QVariantList m_markers;
    QString m_subtitleFontFamily = "Outfit";
    int m_subtitleFontSize = 24;
    QString m_subtitleFillColor = "#4A4A5A";
    QString m_subtitleActiveColor = "#00E676";
    QString m_subtitleOutlineColor = "#08080A";
    int m_subtitleOutlineWidth = 2;
};


} // namespace ncktv
