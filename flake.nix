{
  description = "Nix overlay packaging rocq-mcp and its Python dependencies";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs PR #563493 (python3Packages.fastmcp: 3.4.7 -> 4.x). nixos-unstable
    # ships mcp 2.x, and every fastmcp 3.x release requires mcp<2, so the
    # fastmcp in nixos-unstable is currently marked broken. Drop this input and
    # the openapi-pydantic / fastmcp-slim / fastmcp overrides below once the PR
    # has landed in nixos-unstable.
    nixpkgs-fastmcp4.url = "github:NixOS/nixpkgs/1bc434b7945cdc9aba1bb770a99ea78ad34fa65a";
    nixpkgs-fastmcp4.flake = false;
    rocq-mcp-src.url = "github:LLM4Rocq/rocq-mcp";
    rocq-mcp-src.flake = false;
    pytanque-src.url = "github:LLM4Rocq/pytanque";
    pytanque-src.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-fastmcp4,
      rocq-mcp-src,
      pytanque-src,
      ...
    }:
    {
      overlays.default = final: prev: {
        python312 = prev.python312.override (old: {
          packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: { })) (
            pyFinal: pyPrev:
            let
              fastmcp4 = "${nixpkgs-fastmcp4}/pkgs/development/python-modules";
            in
            {
              # Test suite is sensitive to the exact black/formatter version and
              # fails on nixos-unstable; inline-snapshot is only used as a build
              # tool by mcp's hatch build hooks, never exercised at runtime.
              inline-snapshot = pyPrev.inline-snapshot.overridePythonAttrs (_: {
                doCheck = false;
              });

              # fastmcp-slim 4.x requires openapi-pydantic>=0.6.0.
              openapi-pydantic = pyFinal.callPackage "${fastmcp4}/openapi-pydantic/default.nix" { };

              fastmcp-slim =
                (pyFinal.callPackage "${fastmcp4}/fastmcp-slim/default.nix" {
                  # Only needed by the `code-mode` extra, which rocq-mcp doesn't use.
                  pydantic-monty_1 = null;
                }).overridePythonAttrs
                  (_: {
                    doCheck = false;
                  });

              fastmcp =
                (pyFinal.callPackage "${fastmcp4}/fastmcp/default.nix" {
                  # Only needed by the `tasks` extra, which rocq-mcp doesn't use.
                  fastmcp-tasks = null;
                }).overridePythonAttrs
                  (_: {
                    doCheck = false;
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
