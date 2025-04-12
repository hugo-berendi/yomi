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
  pname = "octodns-cloudflare";
  version = "unstable-2024-10-08";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "octodns";
    repo = "octodns-cloudflare";
    rev = "61a4b404b15c0c14cb18d36b48b834490e743319";
    sha256 = "0kcih4dxgl9ihh22j6d7dbd0d1ylrjp6f60w1p5gzyini1c0a0x1";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    octodns
    dnspython
    requests
  ];

  pythonImportsCheck = ["octodns_cloudflare"];

  nativeCheckInputs = [
    pytestCheckHook
    requests-mock
  ];
}
