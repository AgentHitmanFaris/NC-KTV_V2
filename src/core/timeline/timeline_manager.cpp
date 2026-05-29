#include "timeline_manager.h"
#include "../audio/audio_engine.h"
#include "../audio/stem_separation_worker.h"
#include "../audio/render_worker.h"
#include <QFileInfo>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QUuid>
#include <QStandardPaths>
#include <QSettings>
#include <QDirIterator>
#include <cmath>
#include <algorithm>

namespace ncktv {

TimelineManager::TimelineManager(QObject* parent)
    : QObject(parent),
      m_trackListModel(new TrackListModel(this)) {
      
    // Re-calculate total timeline duration whenever track clips are updated
    connect(m_trackListModel, &TrackListModel::trackAdded, this, [this](Track* track) {
        connect(track, &Track::clipsChanged, this, &TimelineManager::recalculateTotalDuration);
        recalculateTotalDuration();
    });

    connect(m_trackListModel, &TrackListModel::trackRemoved, this, [this](const QString& trackId) {
        if (m_clipModels.contains(trackId)) {
            ClipListModel* model = m_clipModels.take(trackId);
            model->deleteLater();
        }
        recalculateTotalDuration();
    });

    // Load last selected models directory and model path from settings
    QSettings settings("NC-KTV", "NC-KTV_V2");
    m_modelsDirPath = settings.value("modelsDirPath", "").toString();
    m_modelPath = settings.value("modelPath", "").toString();

    if (m_modelsDirPath.isEmpty() || !QDir(m_modelsDirPath).exists()) {
        // Default to standard app local data location (models directory)
        QString appLocal = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
        m_modelsDirPath = QDir(appLocal).filePath("models");
    }

    scanModelsDir();
}

TimelineManager::~TimelineManager() {
    clearProject();
}

void TimelineManager::setModelPath(const QString& path) {
    if (m_modelPath != path) {
        m_modelPath = path;
        QSettings settings("NC-KTV", "NC-KTV_V2");
        settings.setValue("modelPath", m_modelPath);
        emit modelPathChanged();
    }
}

void TimelineManager::setModelsDirPath(const QString& path) {
    if (m_modelsDirPath != path) {
        m_modelsDirPath = path;
        QSettings settings("NC-KTV", "NC-KTV_V2");
        settings.setValue("modelsDirPath", m_modelsDirPath);
        emit modelsDirPathChanged();
        scanModelsDir();
    }
}

void TimelineManager::scanModelsDir() {
    m_discoveredModels.clear();
    m_discoveredModelPaths.clear();

    if (m_modelsDirPath.isEmpty()) {
        emit discoveredModelsChanged();
        return;
    }

    QDir dir(m_modelsDirPath);
    if (!dir.exists()) {
        emit discoveredModelsChanged();
        return;
    }

    // Support recursive scanning to find models in subfolders (e.g. models/Demucs_Models, models/MDX_Net_Models)
    QDirIterator it(m_modelsDirPath, QStringList() << "*.onnx", QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        QString fullPath = it.next();
        m_discoveredModelPaths.append(fullPath);
        
        // Relpath or just filename for friendly name
        QString relPath = dir.relativeFilePath(fullPath);
        m_discoveredModels.append(relPath);
    }

    emit discoveredModelsChanged();

    // If active modelPath is empty or invalid, try to pick the first discovered one
    if ((m_modelPath.isEmpty() || !QFile::exists(m_modelPath)) && !m_discoveredModelPaths.isEmpty()) {
        setModelPath(m_discoveredModelPaths.first());
    }
}

void TimelineManager::setCurrentPlayheadTime(qint64 timeMicroseconds) {
    if (timeMicroseconds < 0) {
        timeMicroseconds = 0;
    }
    if (m_currentPlayheadTime != timeMicroseconds) {
        m_currentPlayheadTime = timeMicroseconds;
        emit currentPlayheadTimeChanged();
    }
}

void TimelineManager::setTotalDuration(qint64 durationMicroseconds) {
    if (durationMicroseconds < 0) {
        durationMicroseconds = 0;
    }
    if (m_totalDuration != durationMicroseconds) {
        m_totalDuration = durationMicroseconds;
        emit totalDurationChanged();
    }
}

void TimelineManager::setFps(double fpsValue) {
    if (fpsValue <= 0.0) {
        fpsValue = 30.0;
    }
    if (std::abs(m_fps - fpsValue) > 0.0001) {
        m_fps = fpsValue;
        emit fpsChanged();
    }
}

QString TimelineManager::addTrack(int type, const QString& name) {
    auto castedType = static_cast<Track::Type>(type);
    Track* track = new Track(QString(), castedType, name, this);
    m_trackListModel->addTrack(track);
    return track->trackId();
}

bool TimelineManager::removeTrack(const QString& trackId) {
    return m_trackListModel->removeTrack(trackId);
}

QObject* TimelineManager::getClipModelForTrack(const QString& trackId) {
    if (m_clipModels.contains(trackId)) {
        return m_clipModels[trackId];
    }

    Track* track = m_trackListModel->getTrackById(trackId);
    if (!track) {
        return nullptr;
    }

    ClipListModel* model = new ClipListModel(track, this);
    m_clipModels[trackId] = model;
    return model;
}

bool TimelineManager::addClipToTrack(const QString& trackId, const QString& clipId, int type, qint64 startTime, qint64 duration, const QString& sourceFile, const QString& lyricText) {
    Track* track = m_trackListModel->getTrackById(trackId);
    if (!track || track->isLocked()) {
        return false;
    }

    qint64 clipDuration = duration;
    if ((type == 0 || type == 1) && clipDuration <= 0 && !sourceFile.isEmpty()) {
        double secs = 0.0;
        if (AudioEngine::instance()) {
            AudioReader* reader = AudioEngine::instance()->getReader(sourceFile);
            if (reader) {
                secs = reader->durationSeconds();
            }
        }
        if (secs <= 0.0) {
            AudioReader tempReader;
            if (tempReader.decodeFile(sourceFile)) {
                secs = tempReader.durationSeconds();
            }
        }
        if (secs > 0.0) {
            clipDuration = static_cast<qint64>(secs * 1000000.0);
        } else {
            clipDuration = 10000000LL; // 10 seconds default fallback
        }
    }

    Clip* clip = new Clip(clipId, static_cast<Clip::Type>(type), startTime, clipDuration, track);
    if (!sourceFile.isEmpty()) {
        clip->setSourceFile(sourceFile);
        clip->setSourceDuration(clipDuration);
    }
    if (!lyricText.isEmpty()) {
        clip->setLyricText(lyricText);
    }

    if (!track->addClip(clip)) {
        delete clip;
        return false;
    }
    return true;
}

bool TimelineManager::splitClip(const QString& trackId, const QString& clipId, qint64 splitTimeMicroseconds) {
    Track* track = m_trackListModel->getTrackById(trackId);
    if (!track || track->isLocked()) {
        return false;
    }

    Clip* clip = track->getClip(clipId);
    if (!clip) {
        return false;
    }

    // Split point must lie strictly within the clip boundary
    if (splitTimeMicroseconds <= clip->startTime() || splitTimeMicroseconds >= clip->endTime()) {
        return false;
    }

    qint64 originalEnd = clip->endTime();
    qint64 splitOffset = splitTimeMicroseconds - clip->startTime();
    qint64 newDuration = originalEnd - splitTimeMicroseconds;

    // Resize the original clip
    clip->resizeClip(splitOffset);

    // Create the second clip segment representing the right half
    Clip* nextSegment = new Clip(
        QString(), 
        clip->type(), 
        splitTimeMicroseconds, 
        newDuration, 
        track
    );
    
    // Copy primary asset references and offset source frame indices
    nextSegment->setSourceFile(clip->sourceFile());
    nextSegment->setLyricText(clip->lyricText());
    
    if (clip->sourceDuration() > 0) {
        nextSegment->setSourceStart(clip->sourceStart() + splitOffset);
        nextSegment->setSourceDuration(clip->sourceDuration() - splitOffset);
        
        // Adjust the original clip source duration to fit the left segment
        clip->setSourceDuration(splitOffset);
    }

    // Attempt to register the split segment on the track
    if (!track->addClip(nextSegment)) {
        // Rollback original clip changes on failure
        clip->resizeClip(splitOffset + newDuration);
        delete nextSegment;
        return false;
    }

    return true;
}

qint64 TimelineManager::checkSnapping(const QString& excludeClipId, qint64 targetTimeMicroseconds, qint64 thresholdMicroseconds) const {
    qint64 draggedDuration = 0;
    if (!excludeClipId.isEmpty()) {
        for (Track* track : m_trackListModel->tracks()) {
            if (Clip* c = track->getClip(excludeClipId)) {
                draggedDuration = c->duration();
                break;
            }
        }
    }

    qint64 bestSnappedStart = targetTimeMicroseconds;
    qint64 minDelta = thresholdMicroseconds + 1; // Higher than threshold to begin

    // Collect list of all timeline snap anchor locations
    QList<qint64> snapPoints;
    snapPoints.append(0LL); // Start of the timeline (0s)
    snapPoints.append(m_currentPlayheadTime);

    for (const Track* track : m_trackListModel->tracks()) {
        for (const Clip* c : track->clips()) {
            if (!excludeClipId.isEmpty() && c->clipId() == excludeClipId) {
                continue;
            }
            snapPoints.append(c->startTime());
            snapPoints.append(c->endTime());
        }
    }

    for (qint64 point : snapPoints) {
        // Option 1: Dragged clip START snaps to this anchor
        qint64 deltaStart = std::abs(targetTimeMicroseconds - point);
        if (deltaStart < minDelta) {
            minDelta = deltaStart;
            bestSnappedStart = point;
        }

        // Option 2: Dragged clip END snaps to this anchor
        if (draggedDuration > 0) {
            qint64 deltaEnd = std::abs((targetTimeMicroseconds + draggedDuration) - point);
            if (deltaEnd < minDelta) {
                minDelta = deltaEnd;
                bestSnappedStart = point - draggedDuration;
            }
        }
    }

    if (minDelta <= thresholdMicroseconds) {
        return bestSnappedStart;
    }
    return targetTimeMicroseconds;
}

qint64 TimelineManager::checkCollisions(const QString& trackId, const QString& clipId, qint64 targetTimeMicroseconds) const {
    Track* track = m_trackListModel->getTrackById(trackId);
    if (!track || track->type() == Track::Lyrics) {
        return targetTimeMicroseconds;
    }

    Clip* clip = track->getClip(clipId);
    if (!clip) {
        return targetTimeMicroseconds;
    }

    qint64 duration = clip->duration();
    qint64 oldStart = clip->startTime();
    qint64 validTime = targetTimeMicroseconds;

    if (targetTimeMicroseconds > oldStart) { // Dragging right
        qint64 closestRightClipStart = -1;
        for (const Clip* c : track->clips()) {
            if (c->clipId() == clipId) {
                continue;
            }
            if (c->startTime() >= oldStart + duration) {
                if (closestRightClipStart == -1 || c->startTime() < closestRightClipStart) {
                    closestRightClipStart = c->startTime();
                }
            }
        }
        if (closestRightClipStart != -1 && (validTime + duration) > closestRightClipStart) {
            validTime = closestRightClipStart - duration;
        }
    } else if (targetTimeMicroseconds < oldStart) { // Dragging left
        qint64 closestLeftClipEnd = -1;
        for (const Clip* c : track->clips()) {
            if (c->clipId() == clipId) {
                continue;
            }
            if (c->endTime() <= oldStart) {
                if (closestLeftClipEnd == -1 || c->endTime() > closestLeftClipEnd) {
                    closestLeftClipEnd = c->endTime();
                }
            }
        }
        if (closestLeftClipEnd != -1 && validTime < closestLeftClipEnd) {
            validTime = closestLeftClipEnd;
        }
    }

    return validTime;
}

QString TimelineManager::formatTimecode(qint64 microseconds) const {
    double totalSeconds = static_cast<double>(microseconds) / 1000000.0;
    int hh = static_cast<int>(totalSeconds) / 3600;
    int mm = (static_cast<int>(totalSeconds) % 3600) / 60;
    int ss = static_cast<int>(totalSeconds) % 60;
    double fractionalPart = totalSeconds - static_cast<int>(totalSeconds);
    int ff = static_cast<int>(std::round(fractionalPart * m_fps)) % static_cast<int>(m_fps);

    return QStringLiteral("%1:%2:%3:%4")
        .arg(hh, 2, 10, QLatin1Char('0'))
        .arg(mm, 2, 10, QLatin1Char('0'))
        .arg(ss, 2, 10, QLatin1Char('0'))
        .arg(ff, 2, 10, QLatin1Char('0'));
}

qint64 TimelineManager::parseTimecode(const QString& timecode) const {
    QString cleaned = timecode.trimmed();
    // Allow colons or semicolons for frame dividers
    QStringList parts = cleaned.split(QRegularExpression(QStringLiteral("[:;]")));
    if (parts.isEmpty()) {
        return 0;
    }

    int hh = 0, mm = 0, ss = 0, ff = 0;
    
    if (parts.size() == 4) {
        hh = parts[0].toInt();
        mm = parts[1].toInt();
        ss = parts[2].toInt();
        ff = parts[3].toInt();
    } else if (parts.size() == 3) {
        mm = parts[0].toInt();
        ss = parts[1].toInt();
        ff = parts[2].toInt();
    } else if (parts.size() == 2) {
        ss = parts[0].toInt();
        ff = parts[1].toInt();
    } else if (parts.size() == 1) {
        ss = parts[0].toInt();
    }

    double seconds = hh * 3600.0 + mm * 60.0 + ss + (static_cast<double>(ff) / m_fps);
    return static_cast<qint64>(seconds * 1000000.0);
}

qint64 TimelineManager::timeToFrames(qint64 microseconds) const {
    return std::round((static_cast<double>(microseconds) / 1000000.0) * m_fps);
}

qint64 TimelineManager::framesToTime(qint64 frames) const {
    return static_cast<qint64>(std::round((static_cast<double>(frames) / m_fps) * 1000000.0));
}

bool TimelineManager::saveProject(const QString& filePath) {
    nlohmann::json j = nlohmann::json::object();
    j["version"] = 2;
    j["fps"] = m_fps;
    j["playhead"] = m_currentPlayheadTime;
    j["totalDuration"] = m_totalDuration;

    nlohmann::json tracksJson = nlohmann::json::array();
    for (Track* track : m_trackListModel->tracks()) {
        tracksJson.push_back(track->toJson());
    }
    j["tracks"] = tracksJson;

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream out(&file);
    out << QString::fromStdString(j.dump(4));
    file.close();
    return true;
}

bool TimelineManager::loadProject(const QString& filePath) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream in(&file);
    QString rawContent = in.readAll();
    file.close();

    try {
        nlohmann::json j = nlohmann::json::parse(rawContent.toStdString());
        
        clearProject();

        m_fps = j.value("fps", 30.0);
        m_currentPlayheadTime = j.value("playhead", 0LL);
        m_totalDuration = j.value("totalDuration", 0LL);

        if (j.contains("tracks") && j["tracks"].is_array()) {
            for (const auto& trackJson : j["tracks"]) {
                Track* track = Track::fromJson(trackJson, this);
                if (track) {
                    m_trackListModel->addTrack(track);
                }
            }
        }

        emit fpsChanged();
        emit currentPlayheadTimeChanged();
        emit totalDurationChanged();
        emit projectLoaded();
        return true;
        
    } catch (...) {
        return false;
    }
}

void TimelineManager::clearProject() {
    if (m_separationWorker) {
        m_separationWorker->requestInterruption();
        m_separationWorker->wait();
        delete m_separationWorker;
        m_separationWorker = nullptr;
    }

    if (m_renderWorker) {
        m_renderWorker->requestInterruption();
        m_renderWorker->wait();
        delete m_renderWorker;
        m_renderWorker = nullptr;
    }

    // Clear list models
    m_trackListModel->clear();
    
    // Remove and delete dynamic clip list models
    qDeleteAll(m_clipModels);
    m_clipModels.clear();

    m_currentPlayheadTime = 0;
    m_totalDuration = 0;
    m_isSeparating = false;
    m_separationProgress = 0.0;
    m_separationStatusText = "";

    m_isRendering = false;
    m_renderProgress = 0.0;
    m_renderStatusText = "";
    
    emit currentPlayheadTimeChanged();
    emit totalDurationChanged();
    emit isSeparatingChanged();
    emit separationProgressChanged();
    emit separationStatusTextChanged();
    emit isRenderingChanged();
    emit renderProgressChanged();
    emit renderStatusTextChanged();
    emit projectCleared();
}

void TimelineManager::recalculateTotalDuration() {
    qint64 maxEnd = 0;
    for (const Track* track : m_trackListModel->tracks()) {
        for (const Clip* clip : track->clips()) {
            maxEnd = std::max(maxEnd, clip->endTime());
        }
    }
    setTotalDuration(maxEnd);
}

void TimelineManager::separateStems(const QString& clipId) {
    if (m_isSeparating) return;

    Clip* clip = nullptr;
    for (Track* track : m_trackListModel->tracks()) {
        if (Clip* c = track->getClip(clipId)) {
            clip = c;
            break;
        }
    }

    if (!clip) return;
    if (clip->sourceFile().isEmpty()) return;

    std::vector<float> inputSamples;
    if (AudioEngine::instance()) {
        AudioReader* reader = AudioEngine::instance()->getReader(clip->sourceFile());
        if (reader) {
            inputSamples = reader->samples();
        }
    }

    if (inputSamples.empty()) {
        AudioReader reader;
        if (reader.decodeFile(clip->sourceFile())) {
            inputSamples = reader.samples();
        }
    }

    if (inputSamples.empty()) {
        onSeparationFailed(clipId, "Could not decode audio from source file.");
        return;
    }

    QFileInfo fileInfo(clip->sourceFile());
    QDir fileDir = fileInfo.dir();
    QString vocalsPath = fileDir.filePath(fileInfo.baseName() + "_vocals.wav");
    QString instrumentalPath = fileDir.filePath(fileInfo.baseName() + "_instrumental.wav");

    m_isSeparating = true;
    m_separationProgress = 0.0;
    m_separationStatusText = "Initializing ONNX session...";
    emit isSeparatingChanged();
    emit separationProgressChanged();
    emit separationStatusTextChanged();

    if (m_separationWorker) {
        m_separationWorker->deleteLater();
    }

    m_separationWorker = new StemSeparationWorker(clipId, inputSamples, vocalsPath, instrumentalPath, m_modelPath, this);

    connect(m_separationWorker, &StemSeparationWorker::progressUpdated, this, &TimelineManager::onSeparationProgress);
    connect(m_separationWorker, &StemSeparationWorker::separationCompleted, this, &TimelineManager::onSeparationCompleted);
    connect(m_separationWorker, &StemSeparationWorker::separationFailed, this, &TimelineManager::onSeparationFailed);

    m_separationWorker->start();
}

void TimelineManager::separateStemsForFile(const QString& filePath) {
    if (m_isSeparating) return;
    if (filePath.isEmpty() || !QFile::exists(filePath)) return;

    std::vector<float> inputSamples;
    if (AudioEngine::instance()) {
        AudioReader* reader = AudioEngine::instance()->getReader(filePath);
        if (reader) {
            inputSamples = reader->samples();
        }
    }

    if (inputSamples.empty()) {
        AudioReader reader;
        if (reader.decodeFile(filePath)) {
            inputSamples = reader.samples();
        }
    }

    if (inputSamples.empty()) {
        onSeparationFailed("", "Could not decode audio from source file.");
        return;
    }

    QFileInfo fileInfo(filePath);
    QDir fileDir = fileInfo.dir();
    QString vocalsPath = fileDir.filePath(fileInfo.baseName() + "_vocals.wav");
    QString instrumentalPath = fileDir.filePath(fileInfo.baseName() + "_instrumental.wav");

    m_isSeparating = true;
    m_separationProgress = 0.0;
    m_separationStatusText = "Initializing ONNX session...";
    emit isSeparatingChanged();
    emit separationProgressChanged();
    emit separationStatusTextChanged();

    if (m_separationWorker) {
        m_separationWorker->deleteLater();
    }

    m_separationWorker = new StemSeparationWorker(QString(), inputSamples, vocalsPath, instrumentalPath, m_modelPath, this);

    connect(m_separationWorker, &StemSeparationWorker::progressUpdated, this, &TimelineManager::onSeparationProgress);
    connect(m_separationWorker, &StemSeparationWorker::separationCompleted, this, &TimelineManager::onSeparationCompleted);
    connect(m_separationWorker, &StemSeparationWorker::separationFailed, this, &TimelineManager::onSeparationFailed);

    m_separationWorker->start();
}


void TimelineManager::onSeparationProgress(double fraction) {
    m_separationProgress = fraction;
    m_separationStatusText = QString("Separating stems... %1%").arg(static_cast<int>(fraction * 100));
    emit separationProgressChanged();
    emit separationStatusTextChanged();
}

void TimelineManager::onSeparationCompleted(const QString& clipId, const QString& vocalsPath, const QString& instPath) {
    Clip* clip = nullptr;
    Track* parentTrack = nullptr;
    for (Track* track : m_trackListModel->tracks()) {
        if (Clip* c = track->getClip(clipId)) {
            clip = c;
            parentTrack = track;
            break;
        }
    }

    if (parentTrack) {
        parentTrack->setIsMuted(true);
    }

    QString fileName;
    qint64 startTime = 0;
    qint64 duration = 0;

    if (clip) {
        fileName = QFileInfo(clip->sourceFile()).fileName();
        startTime = clip->startTime();
        duration = clip->duration();
    } else {
        fileName = QFileInfo(vocalsPath).fileName().replace("_vocals.wav", "");
        startTime = m_currentPlayheadTime; // Start at the current playhead position
        duration = 0; // C++ will auto-detect full length
    }

    QString vocalsTrackId;
    QString instTrackId;

    // Search for existing matching audio tracks to reuse before making new ones
    for (Track* t : m_trackListModel->tracks()) {
        if (t->type() == Track::Audio) {
            QString nameLower = t->name().toLower();
            if (vocalsTrackId.isEmpty() && (nameLower.contains("vocals") || nameLower.contains("vocal"))) {
                vocalsTrackId = t->trackId();
            } else if (instTrackId.isEmpty() && (nameLower.contains("instrumental") || nameLower.contains("instrument") || nameLower.contains("bgm") || nameLower.contains("background"))) {
                instTrackId = t->trackId();
            }
        }
    }

    // Fall back to creating new tracks if matching ones aren't found in timeline
    if (vocalsTrackId.isEmpty()) {
        vocalsTrackId = addTrack(0, "Vocals (" + fileName + ")");
    } else {
        // Clear any existing clips on the matched track to prevent collisions
        Track* vTrack = m_trackListModel->getTrackById(vocalsTrackId);
        if (vTrack && !vTrack->isLocked()) {
            QList<Clip*> trackClips = vTrack->clips();
            for (Clip* c : trackClips) {
                vTrack->removeClip(c->clipId());
            }
        }
    }

    if (instTrackId.isEmpty()) {
        instTrackId = addTrack(0, "Instrumental (" + fileName + ")");
    } else {
        // Clear any existing clips on the matched track to prevent collisions
        Track* iTrack = m_trackListModel->getTrackById(instTrackId);
        if (iTrack && !iTrack->isLocked()) {
            QList<Clip*> trackClips = iTrack->clips();
            for (Clip* c : trackClips) {
                iTrack->removeClip(c->clipId());
            }
        }
    }

    if (AudioEngine::instance()) {
        AudioEngine::instance()->preloadFile(vocalsPath);
        AudioEngine::instance()->preloadFile(instPath);
    }

    addClipToTrack(vocalsTrackId, QString(), 0, startTime, duration, vocalsPath);
    addClipToTrack(instTrackId, QString(), 0, startTime, duration, instPath);

    if (!clip) {
        emit mediaSeparationCompleted(vocalsPath, instPath);
    }

    m_isSeparating = false;
    m_separationProgress = 1.0;
    m_separationStatusText = "Separation completed successfully!";
    emit isSeparatingChanged();
    emit separationProgressChanged();
    emit separationStatusTextChanged();
}

void TimelineManager::onSeparationFailed(const QString& clipId, const QString& errorMessage) {
    Q_UNUSED(clipId);
    m_isSeparating = false;
    m_separationProgress = 0.0;
    m_separationStatusText = "Error: " + errorMessage;
    emit isSeparatingChanged();
    emit separationProgressChanged();
    emit separationStatusTextChanged();
}

void TimelineManager::startExport(const QString& outputPath, int width, int height, int fps, int videoBitrate, int audioBitrate) {
    if (m_isRendering) return;

    m_isRendering = true;
    m_renderProgress = 0.0;
    m_renderStatusText = "Initializing export thread...";
    emit isRenderingChanged();
    emit renderProgressChanged();
    emit renderStatusTextChanged();

    if (m_renderWorker) {
        m_renderWorker->deleteLater();
    }

    m_renderWorker = new RenderWorker(this, AudioEngine::instance(), outputPath, width, height, fps, videoBitrate, audioBitrate, this);

    connect(m_renderWorker, &RenderWorker::progressUpdated, this, &TimelineManager::onRenderProgress);
    connect(m_renderWorker, &RenderWorker::statusTextChanged, this, &TimelineManager::onRenderStatusText);
    connect(m_renderWorker, &RenderWorker::renderCompleted, this, &TimelineManager::onRenderCompleted);
    connect(m_renderWorker, &RenderWorker::renderFailed, this, &TimelineManager::onRenderFailed);

    m_renderWorker->start();
}

void TimelineManager::cancelExport() {
    if (!m_isRendering || !m_renderWorker) return;
    m_renderStatusText = "Cancelling export...";
    emit renderStatusTextChanged();
    m_renderWorker->requestInterruption();
}

void TimelineManager::onRenderProgress(double fraction) {
    m_renderProgress = fraction;
    emit renderProgressChanged();
}

void TimelineManager::onRenderStatusText(const QString& text) {
    m_renderStatusText = text;
    emit renderStatusTextChanged();
}

void TimelineManager::onRenderCompleted(const QString& outputPath, const QString& videoCodec, const QString& audioCodec) {
    Q_UNUSED(videoCodec);
    Q_UNUSED(audioCodec);
    m_isRendering = false;
    m_renderProgress = 1.0;
    m_renderStatusText = "Export completed!";
    emit isRenderingChanged();
    emit renderProgressChanged();
    emit renderStatusTextChanged();
    emit exportCompleted(outputPath);
}

void TimelineManager::onRenderFailed(const QString& errorMessage) {
    m_isRendering = false;
    m_renderProgress = 0.0;
    m_renderStatusText = errorMessage;
    emit isRenderingChanged();
    emit renderProgressChanged();
    emit renderStatusTextChanged();
    emit exportFailed(errorMessage);
}

bool TimelineManager::importLyricsFromFile(const QString& trackId, const QString& filePath) {
    Track* track = m_trackListModel->getTrackById(trackId);
    if (!track || track->isLocked()) {
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream in(&file);
    QString content = in.readAll();
    file.close();

    bool isSrt = filePath.endsWith(".srt", Qt::CaseInsensitive);
    bool isLrc = filePath.endsWith(".lrc", Qt::CaseInsensitive);

    if (!isSrt && !isLrc) {
        if (content.contains("-->")) {
            isSrt = true;
        } else if (content.contains("[") && content.contains("]")) {
            isLrc = true;
        } else {
            return false;
        }
    }

    if (isLrc) {
        QStringList lines = content.split('\n');
        struct LrcEntry {
            qint64 startTimeUs;
            QString text;
        };
        QList<LrcEntry> entries;

        QRegularExpression timeRegex(R"(\[(\d+):(\d+(?:\.\d+)?)\])");

        for (const QString& line : lines) {
            QString trimmed = line.trimmed();
            if (trimmed.isEmpty()) continue;

            QRegularExpressionMatchIterator it = timeRegex.globalMatch(trimmed);
            QList<qint64> times;
            int lastTagEnd = 0;
            while (it.hasNext()) {
                QRegularExpressionMatch match = it.next();
                int mins = match.captured(1).toInt();
                double secs = match.captured(2).toDouble();
                qint64 timeUs = static_cast<qint64>((mins * 60.0 + secs) * 1000000.0);
                times.append(timeUs);
                lastTagEnd = match.capturedEnd();
            }

            if (!times.isEmpty()) {
                QString text = trimmed.mid(lastTagEnd).trimmed();
                for (qint64 timeUs : times) {
                    entries.append({timeUs, text});
                }
            }
        }

        if (entries.isEmpty()) return false;

        std::sort(entries.begin(), entries.end(), [](const LrcEntry& a, const LrcEntry& b) {
            return a.startTimeUs < b.startTimeUs;
        });

        track->blockSignals(true);
        for (int i = 0; i < entries.size(); ++i) {
            qint64 start = entries[i].startTimeUs;
            qint64 duration = 4000000LL;
            if (i < entries.size() - 1) {
                qint64 diff = entries[i + 1].startTimeUs - start;
                if (diff > 0) {
                    duration = diff;
                }
            }
            QString clipId = QString("clip_lyr_%1").arg(QUuid::createUuid().toString(QUuid::Id128));
            addClipToTrack(trackId, clipId, 2, start, duration, "", entries[i].text);
        }
        track->blockSignals(false);
        emit track->clipsChanged();

        if (m_clipModels.contains(trackId)) {
            m_clipModels[trackId]->refresh();
        }

        recalculateTotalDuration();
        return true;
    } else if (isSrt) {
        QStringList lines = content.split('\n');
        int state = 0;
        qint64 startUs = 0;
        qint64 durationUs = 0;
        QString lyricText = "";

        QRegularExpression timecodeRegex(R"((\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3}))");

        track->blockSignals(true);
        for (const QString& line : lines) {
            QString trimmed = line.trimmed();
            if (state == 0) {
                if (trimmed.isEmpty()) continue;
                bool ok = false;
                trimmed.toInt(&ok);
                if (ok) {
                    state = 1;
                }
            } else if (state == 1) {
                QRegularExpressionMatch match = timecodeRegex.match(trimmed);
                if (match.hasMatch()) {
                    int sh = match.captured(1).toInt();
                    int sm = match.captured(2).toInt();
                    int ss = match.captured(3).toInt();
                    int sms = match.captured(4).toInt();

                    int eh = match.captured(5).toInt();
                    int em = match.captured(6).toInt();
                    int es = match.captured(7).toInt();
                    int ems = match.captured(8).toInt();

                    qint64 start = (sh * 3600LL + sm * 60LL + ss) * 1000000LL + sms * 1000LL;
                    qint64 end = (eh * 3600LL + em * 60LL + es) * 1000000LL + ems * 1000LL;

                    startUs = start;
                    durationUs = (end > start) ? (end - start) : 4000000LL;
                    lyricText.clear();
                    state = 2;
                } else {
                    state = 0;
                }
            } else if (state == 2) {
                if (trimmed.isEmpty()) {
                    if (!lyricText.isEmpty()) {
                        QString clipId = QString("clip_lyr_%1").arg(QUuid::createUuid().toString(QUuid::Id128));
                        addClipToTrack(trackId, clipId, 2, startUs, durationUs, "", lyricText.trimmed());
                    }
                    state = 0;
                } else {
                    if (!lyricText.isEmpty()) lyricText += " ";
                    lyricText += trimmed;
                }
            }
        }
        if (state == 2 && !lyricText.isEmpty()) {
            QString clipId = QString("clip_lyr_%1").arg(QUuid::createUuid().toString(QUuid::Id128));
            addClipToTrack(trackId, clipId, 2, startUs, durationUs, "", lyricText.trimmed());
        }
        track->blockSignals(false);
        emit track->clipsChanged();

        if (m_clipModels.contains(trackId)) {
            m_clipModels[trackId]->refresh();
        }

        recalculateTotalDuration();
        return true;
    }

    return false;
}

} // namespace ncktv
