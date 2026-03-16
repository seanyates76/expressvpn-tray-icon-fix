#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QString>
#include <QStringList>
#include <QTextStream>

#include <array>
#include <atomic>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#include <sys/stat.h>
#include <sys/types.h>

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

using RegisterResourceDataFn = bool (*)(int, const unsigned char *, const unsigned char *, const unsigned char *);

std::atomic<int> g_dumpState{0};

QString dumpRoot()
{
    const QByteArray env = qgetenv("EXPRESSVPN_TRAY_DUMP_DIR");
    if (!env.isEmpty()) {
        return QString::fromUtf8(env);
    }

    return QDir::current().absoluteFilePath("resources/original");
}

QString relativePathFor(const QString &resourcePath)
{
    QString relative = resourcePath;
    if (relative.startsWith(":/")) {
        relative.remove(0, 2);
    }
    return relative;
}

QString destinationFor(const QString &root, const QString &resourcePath)
{
    return QDir(root).absoluteFilePath(relativePathFor(resourcePath));
}

void writeManifest(const QString &root, const QStringList &saved)
{
    QFile manifest(QDir(root).absoluteFilePath("manifest.txt"));
    if (!manifest.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        std::fprintf(stderr, "failed to write manifest: %s\n", manifest.fileName().toUtf8().constData());
        return;
    }

    QTextStream out(&manifest);
    out << "Embedded ExpressVPN tray resources\n";
    out << "Source binary: /opt/expressvpn/bin/expressvpn-client\n";
    out << '\n';
    for (const QString &path : saved) {
        out << path << '\n';
    }
}

bool allTrayResourcesAvailable()
{
    for (const char *resource : kTrayResourcePaths) {
        if (!QFile::exists(QString::fromUtf8(resource))) {
            return false;
        }
    }

    return true;
}

bool ensureDirectory(const QString &path)
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
            std::fprintf(stderr, "failed to create directory: %s\n", cursor);
            return false;
        }
        *p = '/';
    }

    if (::mkdir(cursor, 0755) != 0 && errno != EEXIST) {
        std::fprintf(stderr, "failed to create directory: %s\n", cursor);
        return false;
    }

    return true;
}

bool dumpTrayResources()
{
    const QString root = dumpRoot();
    QStringList saved;
    if (!ensureDirectory(root)) {
        return false;
    }

    for (const char *resource : kTrayResourcePaths) {
        const QString resourcePath = QString::fromUtf8(resource);
        const QString destination = destinationFor(root, resourcePath);
        QFile input(resourcePath);
        if (!input.open(QIODevice::ReadOnly)) {
            std::fprintf(stderr, "failed to open resource: %s\n", resource);
            return false;
        }

        const QByteArray bytes = input.readAll();
        if (!ensureDirectory(QFileInfo(destination).absolutePath())) {
            return false;
        }

        QFile output(destination);
        if (!output.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            std::fprintf(stderr, "failed to open destination: %s\n", destination.toUtf8().constData());
            return false;
        }

        if (output.write(bytes) != bytes.size()) {
            std::fprintf(stderr, "failed to write resource: %s -> %s\n",
                         resource,
                         destination.toUtf8().constData());
            return false;
        }

        saved << relativePathFor(resourcePath);
    }

    writeManifest(root, saved);
    std::fprintf(stderr,
                 "dumped %lld tray resources into %s\n",
                 static_cast<long long>(saved.size()),
                 root.toUtf8().constData());
    return true;
}

RegisterResourceDataFn resolveRealRegisterResourceData()
{
    static RegisterResourceDataFn fn = [] {
        void *symbol = dlvsym(RTLD_NEXT, "_Z21qRegisterResourceDataiPKhS0_S0_", "Qt_6");
        if (symbol == nullptr) {
            symbol = dlsym(RTLD_NEXT, "_Z21qRegisterResourceDataiPKhS0_S0_");
        }
        return reinterpret_cast<RegisterResourceDataFn>(symbol);
    }();

    return fn;
}

} // namespace

bool qRegisterResourceData(int version,
                           const unsigned char *tree,
                           const unsigned char *name,
                           const unsigned char *data)
{
    RegisterResourceDataFn realRegister = resolveRealRegisterResourceData();
    if (realRegister == nullptr) {
        std::fprintf(stderr, "failed to resolve qRegisterResourceData\n");
        return false;
    }

    const bool result = realRegister(version, tree, name, data);
    if (!result || g_dumpState.load(std::memory_order_acquire) == 2 || !allTrayResourcesAvailable()) {
        return result;
    }

    int expected = 0;
    if (!g_dumpState.compare_exchange_strong(expected, 1, std::memory_order_acq_rel)) {
        return result;
    }

    if (dumpTrayResources()) {
        g_dumpState.store(2, std::memory_order_release);
        std::fflush(stderr);
        std::_Exit(EXIT_SUCCESS);
    }

    g_dumpState.store(0, std::memory_order_release);
    return result;
}
