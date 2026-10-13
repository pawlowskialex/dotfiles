_: {
  # SSH agent that keeps private keys on the phone (approved over Tailscale).
  # Keys the phone does not have are forwarded to the 1Password agent.
  services.pocket-agent = {
    enable = true;
    settings.upstream_socket = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
}
