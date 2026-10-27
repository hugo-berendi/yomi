# Shell line that creates a Docker network unless it already exists. A restart
# of the unit, or of docker itself, must not fail because the network is there.
{
  name,
  options ? [],
}: "docker network inspect ${name} || docker network create ${builtins.concatStringsSep " " (options ++ [name])}"
