{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-fmt.url = "github:nix-community/nixpkgs-fmt";
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-fmt }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
	    pkg-config
	    openssl
          ];

          shellHook = ''
            mkdir -p .nix-mix
            mkdir -p .nix-hex
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export PATH=$MIX_HOME/bin:$PATH
            export PATH=$HEX_HOME/bin:$PATH
            export PATH=$MIX_HOME/escripts:$PATH
	    export ERL_AFLAGS="-kernel shell_history enabled"
          '';
        };
      });
}
