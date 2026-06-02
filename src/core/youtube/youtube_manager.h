#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QProcess>
#include <QMap>

namespace ncktv {

class YoutubeManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isSearching READ isSearching NOTIFY isSearchingChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorOccurred)

public:
    explicit YoutubeManager(QObject* parent = nullptr);
    virtual ~YoutubeManager() override;

    [[nodiscard]] bool isSearching() const { return m_isSearching; }
    [[nodiscard]] QString lastError() const { return m_lastError; }

    Q_INVOKABLE void search(const QString& query);
    Q_INVOKABLE void download(const QString& videoId, bool audioOnly, const QString& saveDir);
    Q_INVOKABLE void cancelDownload(const QString& videoId);

signals:
    void isSearchingChanged();
    void errorOccurred(const QString& errorMessage);

    void searchCompleted(const QVariantList& results);
    void searchFailed(const QString& error);

    void downloadProgress(const QString& videoId, double progress);
    void downloadCompleted(const QString& videoId, const QString& filePath, bool audioOnly);
    void downloadFailed(const QString& videoId, const QString& errorMessage);

private slots:
    void onSearchFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onSearchReadyRead();
    void onDownloadReadyRead(const QString& videoId);
    void onDownloadFinished(const QString& videoId, int exitCode, QProcess::ExitStatus exitStatus);

private:
    bool findYtDlpCommand(QString& cmd, QStringList& fallbackArgs) const;

    bool m_isSearching = false;
    QString m_lastError;

    // Search process
    QProcess* m_searchProcess = nullptr;
    QByteArray m_searchOutputBuffer;

    // Download processes mapped by videoId
    QMap<QString, QProcess*> m_downloadProcesses;
    QMap<QString, QString> m_downloadOutputPaths;
    QMap<QString, bool> m_downloadAudioOnly;
};

} // namespace ncktv
