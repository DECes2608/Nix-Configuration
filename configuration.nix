{ config, pkgs, lib, ... }:

# Yeni IdeaPad 5 2-in-1 (83KT004STR, Ryzen AI 7 350 + Radeon 860M)
# Kurulumda /etc/nixos/configuration.nix olarak kullan,
# hardware-configuration.nix yeni cihazdan üretileni kalsın.

let
  # Ad o sürümde yoksa/kaldırılmışsa değerlendirme hata vermesin
  tryAttr = set: n:
    let r = builtins.tryEval (set.${n} or null);
    in if r.success then r.value else null;
  tryPkg = tryAttr pkgs;

  # GNOME ile gelen, kullanmadığın varsayılan uygulamalar
  gnomeDebloat = lib.filter (p: p != null) (map tryPkg [
    "gnome-tour"
    "gnome-user-docs"
    "yelp"
    "epiphany"
    "geary"
    "gnome-music"
    "gnome-contacts"
    "gnome-maps"
    "gnome-weather"
    "gnome-clocks"
    "gnome-calendar"
    "gnome-characters"
    "gnome-connections"
    "simple-scan"
    "snapshot"
    "decibels"
    "showtime"
    "totem"
  ]);

  # GNOME uzantıları (nixpkgs'ta o GNOME sürümünü desteklemeyen sessizce atlanır)
  gnomeExts = lib.filter (e: e != null) (map (tryAttr pkgs.gnomeExtensions) [
    "dash-to-dock"         # altta dock
    "appindicator"         # tepsi ikonları (Steam, blueman vb.)
    "clipboard-indicator"  # pano geçmişi
    "caffeine"             # ekranın kapanmasını geçici engelle
    "blur-my-shell"
    "rounded-window-corners-reborn"
  ]);
in
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ryzen AI 7 350 (yeni çip) için güncel kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # BLUETOOTH
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  time.timeZone = "Europe/Istanbul";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "tr_TR.UTF-8";
    LC_IDENTIFICATION = "tr_TR.UTF-8";
    LC_MEASUREMENT = "tr_TR.UTF-8";
    LC_MONETARY = "tr_TR.UTF-8";
    LC_NAME = "tr_TR.UTF-8";
    LC_NUMERIC = "tr_TR.UTF-8";
    LC_PAPER = "tr_TR.UTF-8";
    LC_TELEPHONE = "tr_TR.UTF-8";
    LC_TIME = "tr_TR.UTF-8";
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  environment.gnome.excludePackages = gnomeDebloat;

  services.xserver.xkb = {
    layout = "tr";
    variant = "";
  };
  console.keyMap = "trq";

  # FISH SHELL
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
    '';
    vendor = {
      completions.enable = true;
      config.enable = true;
      functions.enable = true;
    };
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users."deces" = {
    isNormalUser = true;
    description = "deniz";
    shell = pkgs.fish;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------
  # Fontlar
  # ---------------------------------------------------------------
  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    # Microsoft fontları (Arial, Times New Roman, Calibri, Cambria, Consolas...)
    corefonts
    vista-fonts
    # Calibri/Cambria için metrik uyumlu yedekler (LibreOffice düzeni kaymasın)
    carlito
    caladea
    liberation_ttf
    # Kod yazma
    jetbrains-mono
    nerd-fonts.iosevka
  ];

  # ---------------------------------------------------------------
  # Paketler
  # ---------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    wget
    librewolf
    brave
    neovim
    gcc
    unzip
    git
    kitty
    libreoffice
    dotnet-sdk_10
    vscode
    gnome-tweaks

    # flex
    fastfetch
    cava
    cmatrix

    # Shell Eklentileri
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    zoxide
    eza
    bat

    # LazyVim gereksinimleri
    ripgrep
    fd
    lazygit
    tree-sitter
    nodejs
    gnumake
    wl-clipboard
    clang-tools        # clangd (C/C++ LSP)

    # Medya, belge, kitap
    mpv                # video/ses
    loupe              # resim görüntüleyici (dokunmatik yakınlaştırma destekli)
    papers             # PDF görüntüleyici (not/form desteği, GNOME'un kendisi)
    foliate            # EPUB/MOBI kitap okuyucu

    # İletişim
    teams-for-linux    # Microsoft Teams (resmi Linux uygulaması kaldırıldı)

    # SQL (veri bilimi dersi, SQL Server / T-SQL)
    dbeaver-bin        # SQL Server dahil her veritabanına bağlanan grafik istemci
    sqlite             # hafif yedek, Python/pandas denemeleri için

    # Üretim: 3D, video, resim, manga
    blender            # 3D + basit video kurgu (VSE)
    gimp               # fotoğraf/resim düzenleme
    krita              # çizim (kalem ve dokunmatik için)
    komikku            # manga/manhwa okuyucu

    # Ubuntu komutları için konteyner (apt vb.), kullanımı dosyanın altında
    distrobox

    # Geliştirme
    unityhub
    obsidian
    gdb
    cmake
    (python3.withPackages (ps: with ps; [ pandas numpy matplotlib jupyterlab ]))
  ] ++ gnomeExts;

  # LazyVim'in Mason'la indirdiği hazır programlar NixOS'ta çalışsın
  programs.nix-ld.enable = true;

  # SQL Server (ders T-SQL kullanıyor). Otomatik açılmaz, RAM'i yemesin:
  #   başlat: sudo systemctl start docker-mssql
  #   durdur: sudo systemctl stop docker-mssql
  # SA şifresini bir kez oluştur (şifre Nix store'una girmesin diye ayrı dosyada):
  #   echo 'MSSQL_SA_PASSWORD=Sifre123!x' | sudo tee /var/lib/mssql.env
  #   sudo chmod 600 /var/lib/mssql.env
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers.mssql = {
      image = "mcr.microsoft.com/mssql/server:2022-latest";
      autoStart = false;
      ports = [ "127.0.0.1:1433:1433" ];
      environment = {
        ACCEPT_EULA = "Y";
        MSSQL_PID = "Express";
        MSSQL_COLLATION = "Turkish_CI_AS";
      };
      environmentFiles = [ "/var/lib/mssql.env" ];
      volumes = [ "mssql-data:/var/opt/mssql" ];
    };
  };

  # Ubuntu konteyneri (bir kez oluştur, sonra gir):
  #   distrobox create --name ubuntu --image ubuntu:24.04
  #   distrobox enter ubuntu       # içinde: sudo apt install ...
  # Ev dizinin konteynerle paylaşılır, GUI uygulamalar da açılabilir.

  # Varsayılan uygulamalar
  xdg.mime.defaultApplications = {
    "video/mp4" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "image/png" = "org.gnome.Loupe.desktop";
    "image/jpeg" = "org.gnome.Loupe.desktop";
    "image/webp" = "org.gnome.Loupe.desktop";
    "application/pdf" = "org.gnome.Papers.desktop";
    "application/epub+zip" = "com.github.johnfactotum.Foliate.desktop";
  };

  # ---------------------------------------------------------------
  # Donanım (Ryzen AI 7 350 / Radeon 860M)
  # ---------------------------------------------------------------
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.sensor.iio.enable = true;   # ekran döndürme
  services.fwupd.enable = true;
  zramSwap.enable = true;
  services.printing.enable = true;
  services.fstrim.enable = true;

  nix.optimise.automatic = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.xwayland.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # ---------------------------------------------------------------
  # GNOME uzantıları ve dock ayarı
  # ---------------------------------------------------------------
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = map (e: e.extensionUuid) gnomeExts;
      };
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        dock-fixed = true;      # her zaman görünür, gizlenmez
        autohide = false;
        intellihide = false;
        extend-height = false;
      };
"org/gnome/shell/extensions/blur-my-shell/applications" = {
  blur = true;
  enable-all = false;
  whitelist = [ "kitty" ];
  sigma = lib.gvariant.mkInt32 30;
};
    };
  }];

  # ---------------------------------------------------------------
  # Son 3 nesil kalsın, kalanı silinsin
  # ---------------------------------------------------------------
  boot.loader.systemd-boot.configurationLimit = 3;

  systemd.services.keep-3-generations = {
    description = "Son 3 sistem nesli kalsın, eskileri sil ve store'u temizle";
    serviceConfig.Type = "oneshot";
    path = [ config.nix.package ];
    script = ''
      nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
      nix-collect-garbage
    '';
    startAt = "weekly";
  };
  systemd.timers.keep-3-generations.timerConfig.Persistent = true;

  system.stateVersion = "26.05";
}
