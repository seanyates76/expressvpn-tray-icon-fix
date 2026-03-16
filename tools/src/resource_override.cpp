#include <QCoreApplication>
#include <QEvent>
#include <QFile>
#include <QIcon>
#include <QImage>
#include <QMetaObject>
#include <QObject>
#include <QPixmapCache>
#include <QQmlApplicationEngine>
#include <QResource>
#include <QSize>
#include <QString>
#include <QStringList>
#include <QTimerEvent>
#include <QVariant>

#include <dlfcn.h>
#include <sys/stat.h>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <limits>
#include <thread>

namespace {

class QSystemTrayIcon;

constexpr char kBinaryPath[] = "/opt/expressvpn/bin/expressvpn-client";
constexpr char kSyncEnabledEnv[] = "EXPRESSVPN_TRAY_SYNC_ICONSET";
constexpr char kExpectedSizeEnv[] = "EXPRESSVPN_TRAY_SYNC_APP_SIZE";
constexpr char kExpectedMtimeEnv[] = "EXPRESSVPN_TRAY_SYNC_APP_MTIME";
constexpr char kThemeFileEnv[] = "EXPRESSVPN_TRAY_SYSTEM_THEME_FILE";
constexpr char kRccDarkEnv[] = "TRAY_OVERRIDE_RCC_DARK";
constexpr char kRccLightEnv[] = "TRAY_OVERRIDE_RCC_LIGHT";
constexpr char kAssetRootEnv[] = "TRAY_OVERRIDE_ASSET_ROOT";
constexpr char kDebugEnv[] = "EXPRESSVPN_TRAY_DEBUG";
constexpr auto kAppPollInterval = std::chrono::milliseconds(200);
constexpr int kSyncIntervalMs = 500;
constexpr int kCompareLargeIconPx = 88;
constexpr int kCompareSmallIconPx = 22;

QString g_registered_resource_path;
QString g_registered_icon_set;
QString g_last_tray_state;
QString g_last_tray_theme;
QSystemTrayIcon *g_tray_icon = nullptr;

QString append_ascii(const QString &base, const char *suffix)
{
    QString combined(base);
    combined.append(QString::fromLatin1(suffix));
    return combined;
}

bool parse_expected_value(const char *raw_value, unsigned long long *parsed_value)
{
    if (!raw_value || !*raw_value || !parsed_value) {
        return false;
    }

    char *end = nullptr;
    const unsigned long long value = std::strtoull(raw_value, &end, 10);
    if (!end || *end != '\0') {
        return false;
    }

    *parsed_value = value;
    return true;
}

bool sync_is_enabled()
{
    const char *enabled = std::getenv(kSyncEnabledEnv);
    return enabled && enabled[0] == '1' && enabled[1] == '\0';
}

bool debug_is_enabled()
{
    const char *enabled = std::getenv(kDebugEnv);
    return enabled && enabled[0] == '1' && enabled[1] == '\0';
}

void debug_log(const char *message)
{
    if (!debug_is_enabled() || !message) {
        return;
    }

    if (FILE *stream = std::fopen("/tmp/expressvpn-tray-override-debug.log", "a")) {
        std::fprintf(stream, "%s\n", message);
        std::fclose(stream);
    }
}

void debug_logf(const char *format, const char *a = "", const char *b = "", const char *c = "")
{
    if (!debug_is_enabled() || !format) {
        return;
    }

    char buffer[512];
    std::snprintf(buffer, sizeof(buffer), format, a ? a : "", b ? b : "", c ? c : "");
    debug_log(buffer);
}

bool binary_version_matches()
{
    unsigned long long expected_size = 0;
    unsigned long long expected_mtime = 0;
    if (!parse_expected_value(std::getenv(kExpectedSizeEnv), &expected_size) ||
        !parse_expected_value(std::getenv(kExpectedMtimeEnv), &expected_mtime)) {
        return false;
    }

    struct stat st {};
    if (stat(kBinaryPath, &st) != 0) {
        return false;
    }

    return static_cast<unsigned long long>(st.st_size) == expected_size &&
           static_cast<unsigned long long>(st.st_mtime) == expected_mtime;
}

QString env_path(const char *name)
{
    if (const char *value = std::getenv(name); value && *value) {
        return QString::fromUtf8(value);
    }

    return {};
}

QString theme_config_path()
{
    if (const char *override_path = std::getenv(kThemeFileEnv); override_path && *override_path) {
        return QString::fromUtf8(override_path);
    }

    if (const char *xdg_config_home = std::getenv("XDG_CONFIG_HOME"); xdg_config_home && *xdg_config_home) {
        return append_ascii(QString::fromUtf8(xdg_config_home), "/kdeglobals");
    }

    if (const char *home = std::getenv("HOME"); home && *home) {
        return append_ascii(QString::fromUtf8(home), "/.config/kdeglobals");
    }

    return QString::fromUtf8("/nonexistent");
}

QString detect_icon_set_from_file(const QString &path)
{
    QFile theme_file(path);
    if (!theme_file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    const QByteArray raw_data = theme_file.readAll().toLower();
    for (const QByteArray &line : raw_data.split('\n')) {
        const QByteArray trimmed = line.trimmed();
        if (trimmed.startsWith("gtk-application-prefer-dark-theme=")) {
            return trimmed.contains("true") ? QStringLiteral("dark") : QStringLiteral("light");
        }

        if (trimmed.startsWith("gtk-icon-theme-name=")) {
            if (trimmed.contains("dark")) {
                return QStringLiteral("dark");
            }

            if (trimmed.endsWith("=breeze") || trimmed.contains("light")) {
                return QStringLiteral("light");
            }
        }

        if (trimmed.startsWith("gtk-theme-name=")) {
            if (trimmed.contains("dark")) {
                return QStringLiteral("dark");
            }
            continue;
        }

        if (trimmed.startsWith("net/themename ") ||
            trimmed.startsWith("net/iconthemename ") ||
            trimmed.startsWith("lookandfeelpackage=") ||
            trimmed.startsWith("colorscheme=")) {
            if (trimmed.contains("dark")) {
                return QStringLiteral("dark");
            }

            if (trimmed.contains("light") ||
                trimmed.contains("\"breeze\"") ||
                trimmed.endsWith("=breeze") ||
                trimmed.endsWith(" breeze")) {
                return QStringLiteral("light");
            }
        }
    }

    return {};
}

QString desired_icon_set_from_system_theme()
{
    if (const QString override_path = theme_config_path(); !override_path.isEmpty()) {
        if (const QString detected = detect_icon_set_from_file(override_path); !detected.isEmpty()) {
            return detected;
        }
    }

    QStringList candidate_paths;
    if (const char *xdg_config_home = std::getenv("XDG_CONFIG_HOME"); xdg_config_home && *xdg_config_home) {
        const QString config_home = QString::fromUtf8(xdg_config_home);
        candidate_paths << append_ascii(config_home, "/xsettingsd/xsettingsd.conf")
                        << append_ascii(config_home, "/kdeglobals")
                        << append_ascii(config_home, "/gtk-3.0/settings.ini")
                        << append_ascii(config_home, "/gtk-4.0/settings.ini");
    } else if (const char *home = std::getenv("HOME"); home && *home) {
        const QString config_home = append_ascii(QString::fromUtf8(home), "/.config");
        candidate_paths << append_ascii(config_home, "/xsettingsd/xsettingsd.conf")
                        << append_ascii(config_home, "/kdeglobals")
                        << append_ascii(config_home, "/gtk-3.0/settings.ini")
                        << append_ascii(config_home, "/gtk-4.0/settings.ini");
    }

    for (const QString &path : candidate_paths) {
        if (const QString detected = detect_icon_set_from_file(path); !detected.isEmpty()) {
            return detected;
        }
    }

    return QStringLiteral("light");
}

QString theme_variant_name(const QString &icon_set)
{
    if (icon_set == QStringLiteral("dark")) {
        return QStringLiteral("dark-no-outline-margins");
    }

    return QStringLiteral("light-no-outline-margins");
}

QString tray_resource_path(const QString &icon_set, const QString &state_name)
{
    QString path = QStringLiteral(":/img/tray/square-");
    path.append(theme_variant_name(icon_set));
    path.append(QStringLiteral("-"));
    path.append(state_name);
    path.append(QStringLiteral(".png"));
    return path;
}

QString tray_asset_path(const QString &icon_set, const QString &state_name)
{
    const QString asset_root = env_path(kAssetRootEnv);
    if (asset_root.isEmpty()) {
        return {};
    }

    QString path = asset_root;
    path.append(QStringLiteral("/"));
    path.append(icon_set);
    path.append(QStringLiteral("/square-"));
    path.append(theme_variant_name(icon_set));
    path.append(QStringLiteral("-"));
    path.append(state_name);
    path.append(QStringLiteral(".png"));
    return path;
}

QIcon tray_override_icon(const QString &icon_set, const QString &state_name)
{
    const QString asset_path = tray_asset_path(icon_set, state_name);
    if (!asset_path.isEmpty() && QFile::exists(asset_path)) {
        return QIcon(asset_path);
    }

    return QIcon(tray_resource_path(icon_set, state_name));
}

QString resource_path_for_icon_set(const QString &icon_set)
{
    if (icon_set == QStringLiteral("dark")) {
        if (const QString path = env_path(kRccDarkEnv); !path.isEmpty()) {
            return path;
        }
    } else if (icon_set == QStringLiteral("light")) {
        if (const QString path = env_path(kRccLightEnv); !path.isEmpty()) {
            return path;
        }
    }

    return env_path("TRAY_OVERRIDE_RCC");
}

using ObjectMatcher = bool (*)(QObject *);

using QSystemTrayIconSetIconFn = void (*)(QSystemTrayIcon *, const QIcon &);

QSystemTrayIconSetIconFn original_qsystemtrayicon_seticon()
{
    static const auto fn = reinterpret_cast<QSystemTrayIconSetIconFn>(
        dlsym(RTLD_NEXT, "_ZN15QSystemTrayIcon7setIconERK5QIcon"));
    return fn;
}

QImage normalized_icon_image(const QIcon &icon, int side_px)
{
    return icon.pixmap(QSize(side_px, side_px))
        .toImage()
        .convertToFormat(QImage::Format_RGBA8888);
}

long long image_distance(const QImage &left, const QImage &right)
{
    if (left.isNull() || right.isNull() || left.size() != right.size()) {
        return std::numeric_limits<long long>::max();
    }

    const qsizetype byte_count = static_cast<qsizetype>(left.sizeInBytes());
    const uchar *left_bits = left.constBits();
    const uchar *right_bits = right.constBits();
    long long distance = 0;
    for (qsizetype i = 0; i < byte_count; ++i) {
        distance += std::llabs(static_cast<long long>(left_bits[i]) - static_cast<long long>(right_bits[i]));
    }

    return distance;
}

struct IconMatch
{
    QString icon_set;
    QString state_name;
    long long distance = std::numeric_limits<long long>::max();
};

IconMatch detect_tray_icon_match(const QIcon &icon)
{
    const QImage sample_large = normalized_icon_image(icon, kCompareLargeIconPx);
    const QImage sample_small = normalized_icon_image(icon, kCompareSmallIconPx);
    if (sample_large.isNull() || sample_small.isNull()) {
        return {};
    }

    static const QStringList kIconSets{QStringLiteral("dark"), QStringLiteral("light")};
    static const QStringList kStates{
        QStringLiteral("alert"),
        QStringLiteral("connected"),
        QStringLiteral("connecting"),
        QStringLiteral("disconnecting"),
        QStringLiteral("down"),
        QStringLiteral("snoozed"),
    };

    IconMatch best_match;
    for (const QString &icon_set : kIconSets) {
        for (const QString &state_name : kStates) {
            long long distance = std::numeric_limits<long long>::max();

            const QIcon resource_icon(tray_resource_path(icon_set, state_name));
            const long long resource_distance =
                image_distance(sample_large, normalized_icon_image(resource_icon, kCompareLargeIconPx)) +
                image_distance(sample_small, normalized_icon_image(resource_icon, kCompareSmallIconPx));
            distance = std::min(distance, resource_distance);

            const QString asset_path = tray_asset_path(icon_set, state_name);
            if (!asset_path.isEmpty() && QFile::exists(asset_path)) {
                const QIcon asset_icon(asset_path);
                const long long asset_distance =
                    image_distance(sample_large, normalized_icon_image(asset_icon, kCompareLargeIconPx)) +
                    image_distance(sample_small, normalized_icon_image(asset_icon, kCompareSmallIconPx));
                distance = std::min(distance, asset_distance);
            }

            if (distance < best_match.distance) {
                best_match = IconMatch{icon_set, state_name, distance};
            }
        }
    }

    return best_match;
}

void capture_tray_icon(QSystemTrayIcon *tray_icon, const QIcon &icon)
{
    if (!tray_icon) {
        return;
    }

    g_tray_icon = tray_icon;
    const IconMatch match = detect_tray_icon_match(icon);
    if (match.state_name.isEmpty()) {
        debug_log("capture_tray_icon: failed to identify state");
        return;
    }

    g_last_tray_state = match.state_name;
    g_last_tray_theme = match.icon_set;
    debug_logf("capture_tray_icon: state=%s theme=%s",
               g_last_tray_state.toUtf8().constData(),
               g_last_tray_theme.toUtf8().constData());
}

QObject *find_matching_object(QObject *root, ObjectMatcher matcher)
{
    if (!root || !matcher) {
        return nullptr;
    }

    if (matcher(root)) {
        return root;
    }

    const QObjectList children = root->children();
    for (QObject *child : children) {
        if (QObject *found = find_matching_object(child, matcher)) {
            return found;
        }
    }

    return nullptr;
}

QObject *find_matching_object_in_qml_roots(QCoreApplication *app, ObjectMatcher matcher)
{
    if (!app || !matcher) {
        return nullptr;
    }

    QList<QQmlApplicationEngine *> engines;
    std::function<void(QObject *)> collect_engines = [&](QObject *node) {
        if (!node) {
            return;
        }

        if (node->inherits("QQmlApplicationEngine")) {
            engines.append(static_cast<QQmlApplicationEngine *>(node));
        }

        const QObjectList children = node->children();
        for (QObject *child : children) {
            collect_engines(child);
        }
    };

    collect_engines(app);
    for (QQmlApplicationEngine *engine : engines) {
        const QList<QObject *> roots = engine->rootObjects();
        for (QObject *root : roots) {
            if (QObject *found = find_matching_object(root, matcher)) {
                return found;
            }
        }
    }

    return nullptr;
}

void debug_log_trayish_objects(QObject *root)
{
    if (!debug_is_enabled() || !root) {
        return;
    }

    const QMetaObject *meta_object = root->metaObject();
    const QString class_name = meta_object ? QString::fromLatin1(meta_object->className()) : QString();
    if (class_name.contains(QStringLiteral("Tray"), Qt::CaseInsensitive) ||
        class_name.contains(QStringLiteral("ClientSettings"), Qt::CaseInsensitive)) {
        debug_logf("object-scan: class=%s name=%s",
                   class_name.toUtf8().constData(),
                   root->objectName().toUtf8().constData());
    }

    const QObjectList children = root->children();
    for (QObject *child : children) {
        debug_log_trayish_objects(child);
    }
}

void debug_log_object_roots(QCoreApplication *app)
{
    if (!debug_is_enabled() || !app) {
        return;
    }

    debug_log("object-scan: begin app tree");
    debug_log_trayish_objects(app);

    QList<QQmlApplicationEngine *> engines;
    std::function<void(QObject *)> collect_engines = [&](QObject *node) {
        if (!node) {
            return;
        }

        if (node->inherits("QQmlApplicationEngine")) {
            engines.append(static_cast<QQmlApplicationEngine *>(node));
        }

        const QObjectList children = node->children();
        for (QObject *child : children) {
            collect_engines(child);
        }
    };

    collect_engines(app);
    for (QQmlApplicationEngine *engine : engines) {
        debug_logf("object-scan: engine=%s", engine->metaObject()->className());
        const QList<QObject *> roots = engine->rootObjects();
        for (QObject *root : roots) {
            debug_log_trayish_objects(root);
        }
    }

    debug_log("object-scan: end");
}

bool is_client_settings(QObject *object)
{
    if (!object) {
        return false;
    }

    const QVariant theme_name = object->property("themeName");
    const QVariant icon_set = object->property("iconSet");
    return theme_name.isValid() && icon_set.isValid();
}

QObject *find_client_settings(QObject *root)
{
    if (QObject *found = find_matching_object(root, is_client_settings)) {
        return found;
    }

    if (QCoreApplication *app = QCoreApplication::instance()) {
        if (QObject *found = find_matching_object_in_qml_roots(app, is_client_settings)) {
            return found;
        }
    }

    return nullptr;
}

bool is_tray_icon_manager(QObject *object)
{
    if (!object) {
        return false;
    }

    if (object->inherits("TrayIconManager")) {
        return true;
    }

    const QMetaObject *meta_object = object->metaObject();
    return meta_object && QString::fromLatin1(meta_object->className()).contains(QStringLiteral("TrayIconManager"));
}

QObject *find_tray_icon_manager(QObject *root)
{
    if (QObject *found = find_matching_object(root, is_tray_icon_manager)) {
        return found;
    }

    if (QCoreApplication *app = QCoreApplication::instance()) {
        if (QObject *found = find_matching_object_in_qml_roots(app, is_tray_icon_manager)) {
            return found;
        }
    }

    return nullptr;
}

QString normalized_icon_set(QObject *settings)
{
    if (!settings) {
        return {};
    }

    return settings->property("iconSet").toString().trimmed().toLower();
}

bool sync_icon_set(QObject *settings, const QString &desired_icon_set)
{
    if (!settings || desired_icon_set.isEmpty()) {
        return false;
    }

    if (normalized_icon_set(settings) != desired_icon_set) {
        settings->setProperty("iconSet", desired_icon_set);
    }

    return normalized_icon_set(settings) == desired_icon_set;
}

bool refresh_tray_icon(QObject *root)
{
    Q_UNUSED(root);

    if (!g_tray_icon) {
        debug_log("refresh_tray_icon: QSystemTrayIcon not captured");
        return false;
    }

    if (g_last_tray_state.isEmpty()) {
        debug_log("refresh_tray_icon: current tray state unknown");
        return false;
    }

    const auto original_set_icon = original_qsystemtrayicon_seticon();
    if (!original_set_icon) {
        debug_log("refresh_tray_icon: original QSystemTrayIcon::setIcon missing");
        return false;
    }

    QPixmapCache::clear();
    const QIcon desired_icon = tray_override_icon(g_registered_icon_set, g_last_tray_state);
    original_set_icon(g_tray_icon, desired_icon);
    g_last_tray_theme = g_registered_icon_set;
    debug_logf("refresh_tray_icon: reapplied state=%s theme=%s",
               g_last_tray_state.toUtf8().constData(),
               g_last_tray_theme.toUtf8().constData());
    return true;
}

bool switch_registered_resource(const QString &desired_icon_set)
{
    const QString desired_path = resource_path_for_icon_set(desired_icon_set);
    if (desired_path.isEmpty()) {
        debug_log("switch_registered_resource: desired path empty");
        return false;
    }

    if (g_registered_resource_path == desired_path && g_registered_icon_set == desired_icon_set) {
        return true;
    }

    if (!g_registered_resource_path.isEmpty()) {
        QResource::unregisterResource(g_registered_resource_path);
    }

    if (!QResource::registerResource(desired_path)) {
        debug_logf("switch_registered_resource: register failed for %s", desired_path.toUtf8().constData());
        return false;
    }

    QPixmapCache::clear();
    g_registered_resource_path = desired_path;
    g_registered_icon_set = desired_icon_set;
    debug_logf(
        "switch_registered_resource: applied=%s path=%s",
        desired_icon_set.toUtf8().constData(),
        desired_path.toUtf8().constData());
    return true;
}

class ThemeSyncDriver final : public QObject
{
public:
    static QEvent::Type install_event_type()
    {
        static const int type = QEvent::registerEventType();
        return static_cast<QEvent::Type>(type);
    }

protected:
    bool event(QEvent *event) override
    {
        if (event && event->type() == install_event_type()) {
            if (QCoreApplication *app = QCoreApplication::instance()) {
                if (!parent()) {
                    setParent(app);
                }
                debug_log_object_roots(app);
                sync_once();
                if (timer_id_ == 0) {
                    timer_id_ = startTimer(kSyncIntervalMs);
                }
            }
            return true;
        }

        return QObject::event(event);
    }

    void timerEvent(QTimerEvent *event) override
    {
        if (event && event->timerId() == timer_id_) {
            sync_once();
            return;
        }

        QObject::timerEvent(event);
    }

private:
    void sync_once()
    {
        if (QCoreApplication *app = QCoreApplication::instance()) {
            const QString desired_icon_set = desired_icon_set_from_system_theme();
            debug_logf("sync_once: desired=%s registered=%s",
                       desired_icon_set.toUtf8().constData(),
                       g_registered_icon_set.toUtf8().constData());

            if (!switch_registered_resource(desired_icon_set)) {
                debug_log("sync_once: switch_registered_resource returned false");
                return;
            }

            if (QObject *settings = find_client_settings(app)) {
                const QString before_icon_set = normalized_icon_set(settings);
                debug_logf(
                    "sync_once: settings current=%s desired=%s",
                    before_icon_set.toUtf8().constData(),
                    desired_icon_set.toUtf8().constData());
                sync_icon_set(settings, desired_icon_set);
            } else {
                debug_log("sync_once: ClientSettings not found");
            }

            if (last_refreshed_icon_set_ == desired_icon_set && g_last_tray_theme == desired_icon_set) {
                debug_log("sync_once: desired already refreshed");
                return;
            }

            if (refresh_tray_icon(app)) {
                last_refreshed_icon_set_ = desired_icon_set;
                debug_logf("sync_once: refresh ok -> %s", desired_icon_set.toUtf8().constData());
            } else {
                debug_log("sync_once: refresh_tray_icon returned false");
            }
        }
    }

    int timer_id_ = 0;
    QString last_refreshed_icon_set_;
};

void schedule_theme_sync()
{
    if (!sync_is_enabled() || !binary_version_matches()) {
        return;
    }

    auto *driver = new ThemeSyncDriver();

    std::thread([driver]() {
        for (int attempts = 0; attempts < 600; ++attempts) {
            if (QCoreApplication::instance()) {
                QCoreApplication::postEvent(driver, new QEvent(ThemeSyncDriver::install_event_type()));
                return;
            }

            std::this_thread::sleep_for(kAppPollInterval);
        }
    }).detach();
}

}  // namespace

extern "C" void _ZN15QSystemTrayIcon7setIconERK5QIcon(QSystemTrayIcon *self, const QIcon &icon)
{
    capture_tray_icon(self, icon);

    if (const auto original_set_icon = original_qsystemtrayicon_seticon()) {
        QString state_name = g_last_tray_state;
        if (state_name.isEmpty()) {
            const IconMatch match = detect_tray_icon_match(icon);
            state_name = match.state_name;
        }

        if (!state_name.isEmpty()) {
            const QString desired_icon_set = desired_icon_set_from_system_theme();
            const QIcon desired_icon = tray_override_icon(desired_icon_set, state_name);
            g_last_tray_state = state_name;
            g_last_tray_theme = desired_icon_set;
            debug_logf("hook_setIcon: state=%s theme=%s",
                       g_last_tray_state.toUtf8().constData(),
                       g_last_tray_theme.toUtf8().constData());
            original_set_icon(self, desired_icon);
            return;
        }

        debug_log("hook_setIcon: state unknown, passing through");
        original_set_icon(self, icon);
    }
}

__attribute__((constructor))
static void register_override()
{
    const QString desired_icon_set = desired_icon_set_from_system_theme();
    const QString path = resource_path_for_icon_set(desired_icon_set);
    if (!path.isEmpty() && !QResource::registerResource(path)) {
        std::fprintf(stderr, "failed to register RCC: %s\n", path.toUtf8().constData());
    } else {
        g_registered_resource_path = path;
        g_registered_icon_set = desired_icon_set;
    }

    schedule_theme_sync();
}
