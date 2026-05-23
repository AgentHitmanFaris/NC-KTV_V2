#include "clip.h"
#include <QUuid>
#include <algorithm>
#include <QStringList>

namespace ncktv {

Clip::Clip(QObject* parent)
    : QObject(parent),
      m_clipId(QUuid::createUuid().toString(QUuid::Id128)) {
}

Clip::Clip(const QString& id, Type type, qint64 start, qint64 dur, QObject* parent)
    : QObject(parent),
      m_clipId(id.isEmpty() ? QUuid::createUuid().toString(QUuid::Id128) : id),
      m_clipType(type),
      m_startTime(start),
      m_duration(dur) {
    if (type == Lyrics) {
        autoGenerateSyllables();
    }
}

void Clip::setTrackId(const QString& id) {
    if (m_trackId != id) {
        m_trackId = id;
        emit trackIdChanged();
    }
}

void Clip::setClipType(int type) {
    auto castedType = static_cast<Type>(type);
    if (m_clipType != castedType) {
        m_clipType = castedType;
        emit clipTypeChanged();
        if (castedType == Lyrics) {
            autoGenerateSyllables();
        }
    }
}

void Clip::setStartTime(qint64 start) {
    if (m_startTime != start) {
        m_startTime = start;
        emit startTimeChanged();
    }
}

void Clip::setDuration(qint64 dur) {
    if (m_duration != dur) {
        m_duration = dur;
        emit durationChanged();
        if (m_clipType == Lyrics) {
            autoGenerateSyllables();
        }
    }
}

void Clip::setSourceFile(const QString& path) {
    if (m_sourceFile != path) {
        m_sourceFile = path;
        emit sourceFileChanged();
    }
}

void Clip::setSourceStart(qint64 start) {
    if (m_sourceStart != start) {
        m_sourceStart = start;
        emit sourceStartChanged();
    }
}

void Clip::setSourceDuration(qint64 dur) {
    if (m_sourceDuration != dur) {
        m_sourceDuration = dur;
        emit sourceDurationChanged();
    }
}

void Clip::setLyricText(const QString& text) {
    if (m_lyricText != text) {
        if (text.contains('<') && text.contains('>')) {
            parseLrcSyllables(text);
        } else {
            m_lyricText = text;
            emit lyricTextChanged();
            autoGenerateSyllables();
        }
    }
}

void Clip::setSyllables(const QVariantList& list) {
    m_syllables = list;
    emit syllablesChanged();
}

void Clip::moveTo(qint64 newStart) {
    setStartTime(newStart);
}

void Clip::resizeClip(qint64 newDuration, bool fromStart) {
    if (newDuration < 0) newDuration = 0;
    
    if (fromStart) {
        qint64 diff = newDuration - m_duration;
        m_startTime -= diff;
        m_duration = newDuration;
        emit startTimeChanged();
        emit durationChanged();
        if (m_clipType == Lyrics) {
            autoGenerateSyllables();
        }
    } else {
        setDuration(newDuration);
    }
}

void Clip::parseLrcSyllables(const QString& rawLrc) {
    m_syllables.clear();
    
    QString cleanText;
    qint64 lastTime = 0; // Relative to clip start in microseconds
    QString currentWord;
    
    int i = 0;
    int len = rawLrc.length();
    QVariantList parsedList;
    
    while (i < len) {
        if (rawLrc[i] == '<') {
            int closingIdx = rawLrc.indexOf('>', i);
            if (closingIdx != -1) {
                QString tagContent = rawLrc.mid(i + 1, closingIdx - i - 1).trimmed();
                
                double seconds = 0.0;
                QStringList parts = tagContent.split(':');
                if (parts.size() == 2) {
                    int mins = parts[0].toInt();
                    double secs = parts[1].toDouble();
                    seconds = mins * 60.0 + secs;
                } else {
                    seconds = tagContent.toDouble();
                }
                
                qint64 absoluteMicroseconds = static_cast<qint64>(seconds * 1000000.0);
                qint64 relativeMicroseconds = (std::max)(0LL, absoluteMicroseconds - m_startTime);
                
                if (!currentWord.isEmpty()) {
                    QVariantMap syl;
                    syl["text"] = currentWord;
                    syl["relativeStart"] = lastTime;
                    syl["duration"] = (std::max)(100000LL, relativeMicroseconds - lastTime);
                    parsedList.append(syl);
                    cleanText += currentWord;
                }
                
                lastTime = relativeMicroseconds;
                currentWord.clear();
                i = closingIdx + 1;
                continue;
            }
        }
        
        currentWord.append(rawLrc[i]);
        ++i;
    }
    
    if (!currentWord.isEmpty()) {
        QVariantMap syl;
        syl["text"] = currentWord;
        syl["relativeStart"] = lastTime;
        syl["duration"] = (std::max)(100000LL, m_duration - lastTime);
        parsedList.append(syl);
        cleanText += currentWord;
    }
    
    m_syllables = parsedList;
    m_lyricText = cleanText.isEmpty() ? rawLrc : cleanText;
    
    emit lyricTextChanged();
    emit syllablesChanged();
}

void Clip::autoGenerateSyllables() {
    m_syllables.clear();
    if (m_lyricText.isEmpty() || m_duration <= 0) {
        return;
    }

    QStringList words = m_lyricText.split(' ', Qt::SkipEmptyParts);
    if (words.isEmpty()) {
        return;
    }

    qint64 wordDuration = m_duration / words.size();
    QVariantList list;
    
    for (int i = 0; i < words.size(); ++i) {
        QVariantMap syl;
        QString wordText = words[i] + (i == words.size() - 1 ? "" : " ");
        syl["text"] = wordText;
        syl["relativeStart"] = i * wordDuration;
        syl["duration"] = (i == words.size() - 1) ? (m_duration - (i * wordDuration)) : wordDuration;
        list.append(syl);
    }
    
    m_syllables = list;
    emit syllablesChanged();
}

nlohmann::json Clip::toJson() const {
    nlohmann::json j = nlohmann::json::object();
    j["clipId"] = m_clipId.toStdString();
    j["trackId"] = m_trackId.toStdString();
    j["clipType"] = static_cast<int>(m_clipType);
    j["startTime"] = m_startTime;
    j["duration"] = m_duration;
    j["sourceFile"] = m_sourceFile.toStdString();
    j["sourceStart"] = m_sourceStart;
    j["sourceDuration"] = m_sourceDuration;
    j["lyricText"] = m_lyricText.toStdString();

    nlohmann::json syllablesJson = nlohmann::json::array();
    for (const QVariant& s : m_syllables) {
        QVariantMap map = s.toMap();
        nlohmann::json sObj = nlohmann::json::object();
        sObj["text"] = map["text"].toString().toStdString();
        sObj["relativeStart"] = map["relativeStart"].toLongLong();
        sObj["duration"] = map["duration"].toLongLong();
        syllablesJson.push_back(sObj);
    }
    j["syllables"] = syllablesJson;

    return j;
}

Clip* Clip::fromJson(const nlohmann::json& j, QObject* parent) {
    QString id = QString::fromStdString(j.value("clipId", ""));
    int typeVal = j.value("clipType", 0);
    qint64 start = j.value("startTime", 0LL);
    qint64 dur = j.value("duration", 0LL);

    Clip* clip = new Clip(id, static_cast<Type>(typeVal), start, dur, parent);
    clip->setTrackId(QString::fromStdString(j.value("trackId", "")));
    clip->setSourceFile(QString::fromStdString(j.value("sourceFile", "")));
    clip->setSourceStart(j.value("sourceStart", 0LL));
    clip->setSourceDuration(j.value("sourceDuration", 0LL));
    clip->setLyricText(QString::fromStdString(j.value("lyricText", "")));

    if (j.contains("syllables") && j["syllables"].is_array()) {
        QVariantList list;
        for (const auto& sObj : j["syllables"]) {
            QVariantMap map;
            map["text"] = QString::fromStdString(sObj.value("text", ""));
            map["relativeStart"] = sObj.value("relativeStart", 0LL);
            map["duration"] = sObj.value("duration", 0LL);
            list.append(map);
        }
        clip->setSyllables(list);
    } else if (static_cast<Type>(typeVal) == Lyrics) {
        clip->autoGenerateSyllables();
    }

    return clip;
}

} // namespace ncktv
