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
  version = "0.0.10";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "octodns";
    repo = "octodns-cloudflare";
    rev = "a306f9a83c1b1a89c7a7fca545618644ed50f869";
    sha256 = "0kcih4dxgl9ihh22j6d7dbd0d1ylrjp6f60w1p5gzyini1c0a0x1";
  };

  nativeBuildInputs = [setuptools];

  propagatedBuildInputs = [
    octodns
    dnspython
    requests
  ];

  env.OCTODNS_RELEASE = 1;

  pythonImportsCheck = ["octodns_cloudflare"];

  nativeCheckInputs = [
    pytestCheckHook
    requests-mock
  ];
}
