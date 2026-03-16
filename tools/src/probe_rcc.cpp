#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QResource>
#include <QString>
#include <QStringList>
#include <QTextStream>

#include <array>
#include <cerrno>
#include <cstdio>
#include <sys/stat.h>

namespace {

constexpr std::array<const char *, 12> kTrayResourcePaths = {
    ":/img/tray/square-dark-no-outline-margins-alert.png",
    ":/img/tray/square-dark-no-outline-margins-connected.png",
    ":/img/tray/square-dark-no-outline-margins-connecting.png",
    ":/img/tray/square-dark-no-outline-margins-disconnecting.png",
    ":/img/tray/square-dark-no-outline-margins-down.png",
    ":/img/tray/square-dark-no-outline-margins-snoozed.png",
    ":/img/tray/square-light-no-outline-margins-alert.png",
    ":/img/tray/square-light-no-outline-margins-connected.png",
    ":/img/tray/square-light-no-outline-margins-connecting.png",
    ":/img/tray/square-light-no-outline-margins-disconnecting.png",
    ":/img/tray/square-light-no-outline-margins-down.png",
    ":/img/tray/square-light-no-outline-margins-snoozed.png",
};

QString relativePathFor(const QString &resourcePath)
{
    QString relative = resourcePath;
    if (relative.startsWith(":/")) {
        relative.remove(0, 2);
    }
    return relative;
}

bool ensureDir(const QString &path)
{
    QByteArray utf8 = QDir::cleanPath(path).toUtf8();
    if (utf8.isEmpty()) {
        return false;
    }

    char *cursor = utf8.data();
    for (char *p = cursor + 1; *p != '\0'; ++p) {
        if (*p != '/') {
            continue;
        }

        *p = '\0';
        if (::mkdir(cursor, 0755) != 0 && errno != EEXIST) {
            return false;
        }
        *p = '/';
    }

    return ::mkdir(cursor, 0755) == 0 || errno == EEXIST;
}

bool dumpResources(const QString &outDir)
{
    if (!ensureDir(outDir)) {
        std::fprintf(stderr, "failed to create output dir: %s\n", outDir.toUtf8().constData());
        return false;
    }

    for (const char *resource : kTrayResourcePaths) {
        const QString resourcePath = QString::fromUtf8(resource);
        QFile input(resourcePath);
        if (!input.open(QIODevice::ReadOnly)) {
            std::fprintf(stderr, "failed to open resource: %s\n", resource);
            return false;
        }

        const QString destination = QDir(outDir).absoluteFilePath(relativePathFor(resourcePath));
        if (!ensureDir(QFileInfo(destination).absolutePath())) {
            std::fprintf(stderr, "failed to create parent dir for: %s\n", destination.toUtf8().constData());
            return false;
        }

        QFile output(destination);
        if (!output.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            std::fprintf(stderr, "failed to open destination: %s\n", destination.toUtf8().constData());
            return false;
        }

        const QByteArray bytes = input.readAll();
        if (output.write(bytes) != bytes.size()) {
            std::fprintf(stderr, "failed to write destination: %s\n", destination.toUtf8().constData());
            return false;
        }
    }

    return true;
}

}  // namespace

int main(int argc, char **argv)
{
    if (argc != 3) {
        std::fprintf(stderr, "usage: %s <rcc-path> <output-dir>\n", argv[0]);
        return 1;
    }

    const QString rccPath = QString::fromUtf8(argv[1]);
    const QString outDir = QString::fromUtf8(argv[2]);

    if (!QResource::registerResource(rccPath)) {
        std::fprintf(stderr, "failed to register rcc: %s\n", rccPath.toUtf8().constData());
        return 1;
    }

    if (!dumpResources(outDir)) {
        return 1;
    }

    QTextStream(stdout) << outDir << '\n';
    return 0;
}
