{
  description = "Nix overlay packaging rocq-mcp and its Python dependencies";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rocq-mcp-src.url = "github:LLM4Rocq/rocq-mcp";
    rocq-mcp-src.flake = false;
    pytanque-src.url = "github:LLM4Rocq/pytanque";
    pytanque-src.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      rocq-mcp-src,
      pytanque-src,
      ...
    }:
    {
      overlays.default = final: prev: {
        python312 = prev.python312.override (old: {
          packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: { })) (
            pyFinal: pyPrev: {
              py-key-value-aio = pyPrev.py-key-value-aio.overridePythonAttrs (_: {
                version = "0.4.4";
                src = final.fetchFromGitHub {
                  owner = "strawgate";
                  repo = "py-key-value";
                  tag = "0.4.4";
                  hash = "sha256-JznZW3FOKlhZD42Ng108tNB4bNiEad7QBiu8RmflTXM=";
                };
                sourceRoot = null;
                dependencies = [
                  pyFinal.beartype
                  pyFinal.typing-extensions
                ];
                doCheck = false;
                disabledTestPaths = [ ];
                disabledTests = [ ];
              });

              griffelib = pyFinal.buildPythonPackage rec {
                pname = "griffelib";
                version = "2.0.2";
                pyproject = true;
                src = final.fetchPypi {
                  inherit pname version;
                  hash = "sha256-PPILO8Rw6Ddj/78jbgB2sSEbrBvGfeE9r0lGQPLecH4=";
                };
                build-system = [
                  pyFinal.hatchling
                  pyFinal.pdm-backend
                  pyFinal.uv-dynamic-versioning
                ];
                pythonImportsCheck = [ "griffe" ];
                doCheck = false;
              };

              uncalled-for = pyFinal.buildPythonPackage rec {
                pname = "uncalled_for";
                version = "0.3.1";
                pyproject = true;
                src = final.fetchPypi {
                  inherit pname version;
                  hash = "sha256-XkEqxnCPBLVr71hntdz2aQ685OtzFgWNnFB4dJK7S8o=";
                };
                build-system = [
                  pyFinal.hatchling
                  pyFinal.hatch-vcs
                ];
                env.SETUPTOOLS_SCM_PRETEND_VERSION = version;
                env.HATCH_BUILD_HOOK_VERSION = version;
                pythonImportsCheck = [ "uncalled_for" ];
                doCheck = false;
              };

              fastmcp = pyPrev.fastmcp.overridePythonAttrs (_: rec {
                version = "3.2.4";
                src = final.fetchPypi {
                  pname = "fastmcp";
                  inherit version;
                  hash = "sha256-CD7LdbRKQWnn/A9jL5S3gb2w/4d8azW5h3y7Vm/U1NE=";
                };
                dependencies = [
                  pyFinal.authlib
                  pyFinal.cyclopts
                  pyFinal.exceptiongroup
                  pyFinal.griffelib
                  pyFinal.httpx
                  pyFinal.jsonref
                  pyFinal.jsonschema-path
                  pyFinal.mcp
                  pyFinal.openapi-pydantic
                  pyFinal.opentelemetry-api
                  pyFinal.packaging
                  pyFinal.platformdirs
                  pyFinal.py-key-value-aio
                  pyFinal.pydantic
                  pyFinal.pyperclip
                  pyFinal.python-dotenv
                  pyFinal.pyyaml
                  pyFinal.rich
                  pyFinal.uncalled-for
                  pyFinal.uvicorn
                  pyFinal.watchfiles
                  pyFinal.websockets
                ]
                ++ pyFinal.py-key-value-aio.optional-dependencies.filetree
                ++ pyFinal.py-key-value-aio.optional-dependencies.keyring
                ++ pyFinal.py-key-value-aio.optional-dependencies.memory
                ++ pyFinal.pydantic.optional-dependencies.email;
                doCheck = false;
                disabledTests = [ ];
                disabledTestPaths = [ ];
              });

              pytanque = pyFinal.buildPythonPackage {
                pname = "pytanque";
                version = "0.2.2";
                pyproject = true;
                src = pytanque-src;
                build-system = [ pyFinal.setuptools ];
                dependencies = [
                  pyFinal.typing-extensions
                  pyFinal.requests
                ];
                pythonImportsCheck = [ "pytanque" ];
                doCheck = false;
              };
            }
          );
        });
        python312Packages = final.python312.pkgs;

        rocq-mcp = final.python312Packages.buildPythonApplication {
          pname = "rocq-mcp";
          version = "0.3.1";
          pyproject = true;
          src = rocq-mcp-src;
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-fail \
                "pytanque @ git+https://github.com/LLM4Rocq/pytanque" \
                "pytanque"
          '';
          build-system = [ final.python312Packages.setuptools ];
          dependencies = [
            final.python312Packages.fastmcp
            final.python312Packages.pytanque
            final.python312Packages.psutil
          ];
          doCheck = false;
          pythonImportsCheck = [ "rocq_mcp" ];
        };
      };
    };
}
