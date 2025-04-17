{
  buildPythonPackage,
  dnspython,
  fetchFromGitHub,
  fqdn,
  idna,
  natsort,
  pytestCheckHook,
  python-dateutil,
  python,
  pythonOlder,
  pyyaml,
  runCommand,
  setuptools,
  ...
}:
buildPythonPackage rec {
  pname = "octodns";
  version = "unstable-2024-10-13";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "octodns";
    repo = "octodns";
    rev = "e30d91783eb0b85507605eb51fcfb75b0773fb26";
    sha256 = "Yl7266I8aH9cEsu+/6yYn6TJPKsmhHotC3y+/cYpK3M=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    dnspython
    fqdn
    idna
    natsort
    python-dateutil
    pyyaml
  ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  pythonImportsCheck = ["octodns"];

  passthru.withProviders = ps: let
    pyEnv = python.withPackages ps;
  in
    runCommand "octodns-with-providers" {} ''
      mkdir -p $out/bin
      ln -st $out/bin ${pyEnv}/bin/octodns-*
    '';
}
