{
  fetchFromGitHub,
  python3,
  buildPythonPackage,
}: let
  python = python3.override {
    self = python;
    packageOverrides = _self: super: {
      sqlalchemy = super.sqlalchemy_1_4;
    };
  };
in
  buildPythonPackage rec {
    pname = "Calibre-Web-Automated";
    version = "2.1.2";

    src = fetchFromGitHub {
      owner = "crocodilestick";
      repo = "Calibre-Web-Automated";
      rev = version;
      hash = "sha256-nWZmDasBH+DW/+Cvw510mOv11CXorRnoBwNFpoKPErY=";
    };

    propagatedBuildInputs = with python.pkgs; [
      advocate
      apscheduler
      babel
      bleach
      chardet
      flask
      flask-babel
      flask-limiter
      flask-login
      flask-principal
      flask-wtf
      iso-639
      jsonschema
      lxml
      pypdf
      python-magic
      pytz
      regex
      requests
      sqlalchemy
      tornado
      unidecode
      wand
      werkzeug
    ];

    patches = [
      # default-logger.patch switches default logger to /dev/stdout. Otherwise calibre-web tries to open a file relative
      # to its location, which can't be done as the store is read-only. Log file location can later be configured using UI
      # if needed.
      ./default-logger.patch
      # DB migrations adds an env var __RUN_MIGRATIONS_ANDEXIT that, when set, instructs calibre-web to run DB migrations
      # and exit. This is gonna be used to configure calibre-web declaratively, as most of its configuration parameters
      # are stored in the DB.
      ./db-migrations.patch
    ];

    # calibre-web doesn't follow setuptools directory structure.
    postPatch = ''
      mkdir -p src/calibreweb
      mv cps.py src/calibreweb/__init__.py
      mv cps src/calibreweb

      substituteInPlace setup.cfg \
        --replace-fail "cps = calibreweb:main" "calibre-web = calibreweb:main"
    '';

    # Upstream repo doesn't provide any tests.
    doCheck = false;
  }
