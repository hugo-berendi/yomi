// Save this file somewhere as spotify.preload.c

// Then build the library:
// gcc -fPIC -shared  -o ~/spotify.preload.so spotify.preload.c -ldl

// When you execute spotify, you need to preload this library, which wraps the "setsockopt" function call with another function that gives spotify the results it expects:
// LD_PRELOAD=~/spotify.preload.so spotify

// To make the desktop icon work, edit: /usr/share/applications/spotify.desktop
// Change Exec=... to:
// Exec=LD_PRELOAD=~/spotify.preload.so spotify %U

#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/socket.h>
#include <netinet/in.h>

static int (*real_setsockopt)(int socket, int level, int option_name, const void *option_value, socklen_t option_len);

int setsockopt(int socket, int level, int option_name, const void *option_value, socklen_t option_len) {
 real_setsockopt = dlsym(RTLD_NEXT,"setsockopt");
 int ret = real_setsockopt(socket,level,option_name,option_value,option_len);
 if (level == SOL_IP && option_name == IP_MULTICAST_IF) {
  return 0;
 }
 return ret;
}
