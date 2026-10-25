_: {
  # `op` keeps its account sign-in (inari, wsl) and shell-plugin links (the
  # `op plugin init gh` choice on amaterasu) here. Lost on every rollback
  # otherwise. op itself keeps the directory at 0700.
  yomi.persistence.at.state.apps.op.directories = [".config/op"];
}
