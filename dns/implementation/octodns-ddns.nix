{
  buildPythonPackage,
  fetchFromGitHub,
  octodns,
  pytestCheckHook,
  pythonOlder,
  dnspython,
  setuptools,
  requests,
  requests-mock,
}:
buildPythonPackage {
  pname = "octodns-ddns";
  version = "unstable-2025-05-04";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "octodns";
    repo = "octodns-ddns";
    rev = "35a69ef528c3b0e37a9074082c6a18db1208c8d4";
    sha256 = "bcor4YZWG6RGRE1ItcuKC+aoM/F69pZTbLmyZMxehdc=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    octodns
    dnspython
    requests
  ];

  pythonImportsCheck = ["octodns_ddns"];

  nativeCheckInputs = [
    pytestCheckHook
    requests-mock
  ];
}
