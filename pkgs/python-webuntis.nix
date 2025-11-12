{
  lib,
  fetchFromGitHub,
  python313,
}:
python313.pkgs.buildPythonPackage rec {
  pname = "python-webuntis";
  version = "0.1.23";

  src = fetchFromGitHub {
    owner = "python-webuntis";
    repo = "python-webuntis";
    rev = version;
    sha256 = "sha256:vrr+qnEUnMkJSu0EUrtW9Qoih0F4bNkYgCDI/nmwYW0=";
  };

  pyproject = true;
  build-system = with python313.pkgs; [setuptools];

  propagatedBuildInputs = with python313.pkgs; [
    requests
  ];

  nativeCheckInputs = with python313.pkgs; [
    pytest
  ];

  pythonImportsCheck = ["webuntis"];

  meta = with lib; {
    description = "Python bindings for the WebUntis school timetable system";
    homepage = "https://github.com/python-webuntis/python-webuntis";
    license = licenses.bsd3;
    maintainers = with maintainers; [];
    platforms = platforms.all;
  };
}
