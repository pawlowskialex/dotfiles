#pragma once
#include <sys/types.h>

/// Spawn `command` via `/bin/zsh -l -c` inside a fresh PTY.
///
/// @param command      Shell command string to execute
/// @param master_fd_out  Populated with the master PTY file descriptor on success
/// @return  Child PID on success, -1 on error (check errno)
pid_t pty_spawn_zsh(const char *command, int *master_fd_out);
