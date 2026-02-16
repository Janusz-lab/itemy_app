# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.flutter
    pkgs.jdk17
    pkgs.chromium
  ];

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    previews = {
      enable = true;
      previews = {
        # To odblokuje panel emulatora Androida
        #android = {
        #  manager = "android";
        #};
        # To odblokuje podgląd Web (opcjonalnie)
        web = {
          # Zmieniamy manager na "flutter"
          manager = "flutter";
          command = [
            "flutter"
            "run"
            "--machine"
            "-d"
            "web-server"
            "--web-hostname"
            "0.0.0.0"
            "--web-port"
            "$PORT"
            "--web-renderer"
            "html"  # Dodajemy to na stałe tutaj
          ];
        };
      };
    };
  };
}