#include "CTerminal.h"
#include <util.h>
#include <unistd.h>
#include <stdlib.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <signal.h>

pid_t pty_spawn_zsh(const char *command, int *master_fd_out) {
    // Wide window avoids spurious line-wrapping in command output
    struct winsize ws = { .ws_row = 50, .ws_col = 220 };

    char *args[] = { "/bin/zsh", "-l", "-c", (char *)command, NULL };

    int master;
    pid_t pid = forkpty(&master, NULL, NULL, &ws);
    if (pid < 0) return -1;

    if (pid == 0) {
        // Child: restore default signal handlers then exec
        signal(SIGINT,  SIG_DFL);
        signal(SIGTERM, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        execv("/bin/zsh", args);
        _exit(127);
    }

    // Parent
    *master_fd_out = master;
    return pid;
}
