// Ayudante de música de Sintecla (spec «La isla» §4).
//
// Desde macOS 15.4, MediaRemote no responde a apps que no son de Apple, pero sí a /usr/bin/perl. Por eso esta
// biblioteca la carga `now-playing.pl` dentro de perl, y Sintecla habla con ella por la entrada y la salida estándar:
//   - salida: una línea JSON con cada cambio de lo que suena ({"empty":true} si no suena nada);
//   - entrada: una orden por línea: play, pause, toggle, next, previous o «seek <segundos>».
// Al cerrarse la entrada (Sintecla ha salido), termina.

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*GetPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*RegisterFn)(dispatch_queue_t);
typedef Boolean (*SendCommandFn)(int, CFDictionaryRef);
typedef void (*SetElapsedFn)(double);

static GetInfoFn get_info;
static GetPlayingFn get_playing;
static GetPIDFn get_pid;
static SendCommandFn send_command;
static SetElapsedFn set_elapsed;

static char *last_line;
static char last_artwork_id[64];
static int report_pending;

// MARK: - JSON

typedef struct {
  char *text;
  size_t length, capacity;
} Buffer;

static void append(Buffer *buffer, const char *text, size_t length) {
  if (buffer->length + length + 1 > buffer->capacity) {
    buffer->capacity = (buffer->length + length + 1) * 2;
    buffer->text = realloc(buffer->text, buffer->capacity);
  }
  memcpy(buffer->text + buffer->length, text, length);
  buffer->length += length;
  buffer->text[buffer->length] = 0;
}

static void append_text(Buffer *buffer, const char *text) { append(buffer, text, strlen(text)); }

static void append_string(Buffer *buffer, CFStringRef string) {
  append_text(buffer, "\"");
  if (string) {
    CFIndex size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8) + 1;
    char *utf8 = malloc(size);
    if (CFStringGetCString(string, utf8, size, kCFStringEncodingUTF8)) {
      for (const unsigned char *c = (const unsigned char *)utf8; *c; c++) {
        char escaped[8];
        if (*c == '"' || *c == '\\') {
          snprintf(escaped, sizeof escaped, "\\%c", *c);
          append_text(buffer, escaped);
        } else if (*c < 0x20) {
          snprintf(escaped, sizeof escaped, "\\u%04x", *c);
          append_text(buffer, escaped);
        } else {
          append(buffer, (const char *)c, 1);
        }
      }
    }
    free(utf8);
  }
  append_text(buffer, "\"");
}

static void append_base64(Buffer *buffer, const UInt8 *bytes, CFIndex length) {
  static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  char quad[4];
  for (CFIndex i = 0; i < length; i += 3) {
    UInt32 n = (UInt32)bytes[i] << 16;
    if (i + 1 < length) n |= (UInt32)bytes[i + 1] << 8;
    if (i + 2 < length) n |= bytes[i + 2];
    quad[0] = table[(n >> 18) & 63];
    quad[1] = table[(n >> 12) & 63];
    quad[2] = i + 1 < length ? table[(n >> 6) & 63] : '=';
    quad[3] = i + 2 < length ? table[n & 63] : '=';
    append(buffer, quad, 4);
  }
}

static CFTypeRef value(CFDictionaryRef info, const char *key) {
  CFStringRef name = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
  CFTypeRef found = CFDictionaryGetValue(info, name);
  CFRelease(name);
  return found;
}

static double number(CFDictionaryRef info, const char *key, double fallback) {
  CFTypeRef found = value(info, key);
  double result = fallback;
  if (found && CFGetTypeID(found) == CFNumberGetTypeID()) CFNumberGetValue(found, kCFNumberDoubleType, &result);
  return result;
}

static CFStringRef string(CFDictionaryRef info, const char *key) {
  CFTypeRef found = value(info, key);
  return found && CFGetTypeID(found) == CFStringGetTypeID() ? found : NULL;
}

// MARK: - Avisos

static void emit(CFDictionaryRef info, Boolean playing, int pid) {
  Buffer line = {0};
  CFStringRef title = info ? string(info, "kMRMediaRemoteNowPlayingInfoTitle") : NULL;
  if (!title || CFStringGetLength(title) == 0) {
    append_text(&line, "{\"empty\":true}");
  } else {
    char number_text[256];
    append_text(&line, playing ? "{\"playing\":true,\"title\":" : "{\"playing\":false,\"title\":");
    append_string(&line, title);
    append_text(&line, ",\"artist\":");
    append_string(&line, string(info, "kMRMediaRemoteNowPlayingInfoArtist"));
    append_text(&line, ",\"album\":");
    append_string(&line, string(info, "kMRMediaRemoteNowPlayingInfoAlbum"));
    double timestamp = CFAbsoluteTimeGetCurrent();
    CFTypeRef date = value(info, "kMRMediaRemoteNowPlayingInfoTimestamp");
    if (date && CFGetTypeID(date) == CFDateGetTypeID()) timestamp = CFDateGetAbsoluteTime(date);
    snprintf(number_text, sizeof number_text, ",\"duration\":%.3f,\"elapsed\":%.3f,\"timestamp\":%.3f,\"pid\":%d",
             number(info, "kMRMediaRemoteNowPlayingInfoDuration", 0),
             number(info, "kMRMediaRemoteNowPlayingInfoElapsedTime", 0),
             timestamp + kCFAbsoluteTimeIntervalSince1970, pid);
    append_text(&line, number_text);
    CFTypeRef artwork = value(info, "kMRMediaRemoteNowPlayingInfoArtworkData");
    if (artwork && CFGetTypeID(artwork) == CFDataGetTypeID() && CFDataGetLength(artwork) > 0) {
      // La carátula se reconoce por su tamaño y un resumen de sus primeros bytes, y solo viaja cuando cambia.
      const UInt8 *bytes = CFDataGetBytePtr(artwork);
      CFIndex length = CFDataGetLength(artwork);
      UInt32 hash = 2166136261u;
      for (CFIndex i = 0; i < length && i < 8192; i++) hash = (hash ^ bytes[i]) * 16777619u;
      char artwork_id[64];
      snprintf(artwork_id, sizeof artwork_id, "%ld-%08x", (long)length, hash);
      append_text(&line, ",\"artworkID\":\"");
      append_text(&line, artwork_id);
      append_text(&line, "\"");
      if (strcmp(artwork_id, last_artwork_id) != 0) {
        append_text(&line, ",\"artwork\":\"");
        append_base64(&line, bytes, length);
        append_text(&line, "\"");
        strlcpy(last_artwork_id, artwork_id, sizeof last_artwork_id);
      }
    } else {
      // Algunas apps (Spotify) la quitan en pausa: al volver, aunque sea la misma, se manda otra vez.
      last_artwork_id[0] = 0;
    }
    append_text(&line, "}");
  }
  if (!last_line || strcmp(line.text, last_line) != 0) {
    printf("%s\n", line.text);
    fflush(stdout);
    free(last_line);
    last_line = line.text;
  } else {
    free(line.text);
  }
}

static void report(void) {
  get_info(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
    if (info) CFRetain(info);
    get_playing(dispatch_get_main_queue(), ^(Boolean playing) {
      get_pid(dispatch_get_main_queue(), ^(int pid) {
        emit(info, playing, pid);
        if (info) CFRelease(info);
      });
    });
  });
}

/// Los avisos de MediaRemote llegan a ráfagas: se juntan en uno cada 100 ms.
static void schedule_report(double delay) {
  if (report_pending) return;
  report_pending = 1;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    report_pending = 0;
    report();
  });
}

static void changed(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object,
                    CFDictionaryRef info) {
  schedule_report(0.1);
}

// MARK: - Órdenes

static void run_command(char *command) {
  if (strcmp(command, "play") == 0) send_command(0, NULL);
  else if (strcmp(command, "pause") == 0) send_command(1, NULL);
  else if (strcmp(command, "toggle") == 0) send_command(2, NULL);
  else if (strcmp(command, "next") == 0) send_command(4, NULL);
  else if (strcmp(command, "previous") == 0) send_command(5, NULL);
  else if (strncmp(command, "seek ", 5) == 0) set_elapsed(atof(command + 5));
  else return;
  // La app tarda un poco en aplicar la orden.
  schedule_report(0.3);
}

static void listen_to_commands(void) {
  static char pending[1024];
  static size_t used;
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0,
                                                    dispatch_get_main_queue());
  dispatch_source_set_event_handler(source, ^{
    char chunk[512];
    ssize_t count = read(STDIN_FILENO, chunk, sizeof chunk);
    if (count <= 0) exit(0);  // Sintecla ha salido
    for (ssize_t i = 0; i < count; i++) {
      if (chunk[i] == '\n') {
        pending[used] = 0;
        run_command(pending);
        used = 0;
      } else if (used < sizeof pending - 1) {
        pending[used++] = chunk[i];
      }
    }
  });
  dispatch_resume(source);
}

// MARK: - Arranque

/// La llama `now-playing.pl`. No vuelve nunca: termina cuando se cierra la entrada.
void sintecla_now_playing_run(void *perl, void *cv) {
  void *media = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
  get_info = (GetInfoFn)dlsym(media, "MRMediaRemoteGetNowPlayingInfo");
  get_playing = (GetPlayingFn)dlsym(media, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
  get_pid = (GetPIDFn)dlsym(media, "MRMediaRemoteGetNowPlayingApplicationPID");
  send_command = (SendCommandFn)dlsym(media, "MRMediaRemoteSendCommand");
  set_elapsed = (SetElapsedFn)dlsym(media, "MRMediaRemoteSetElapsedTime");
  RegisterFn register_notifications = (RegisterFn)dlsym(media, "MRMediaRemoteRegisterForNowPlayingNotifications");
  if (!get_info || !get_playing || !get_pid || !send_command || !set_elapsed || !register_notifications) {
    fprintf(stderr, "MediaRemote no disponible\n");
    exit(1);
  }
  register_notifications(dispatch_get_main_queue());
  const char *names[] = {"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                         "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                         "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"};
  for (int i = 0; i < 3; i++) {
    CFStringRef name = CFStringCreateWithCString(NULL, names[i], kCFStringEncodingUTF8);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, changed, name, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFRelease(name);
  }
  // Por si algún cambio no avisa (un salto en la canción, por ejemplo): se mira también cada 3 s.
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), 3 * NSEC_PER_SEC,
                            NSEC_PER_SEC / 2);
  dispatch_source_set_event_handler(timer, ^{ report(); });
  dispatch_resume(timer);
  listen_to_commands();
  report();
  CFRunLoopRun();
}
