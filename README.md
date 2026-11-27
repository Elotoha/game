# Apex — Club Circuit

Prototype de conduite 2D vu de dessus, pour Android en paysage, inspiré des courses compactes de l’époque Amiga. Graphismes procéduraux originaux, sans ressources de Super Cars. Une voiture jouable, pas encore d’adversaires.

## Télécharger sur Android

[**Télécharger l’APK 0.1.0 (ARM64)**](https://github.com/Elotoha/game/raw/refs/heads/main/downloads/apex-v0.1.0-android-arm64.apk)

Version de test signée, Android 7.0 minimum. Installation manuelle ; aucun compte requis. Voir [les instructions Android](downloads/README.md) et l’empreinte [SHA-256](downloads/SHA256SUMS). L’APK est compilé et sa signature vérifiée ; le fonctionnement sur appareil physique reste à valider.

## Jouer

Ouvrir `project.godot` avec **Godot 4.6.3**, puis F6 depuis `scenes/race.tscn` ou F5. Aucune dépendance externe, aucun compte, aucun service réseau nécessaire.

```sh
cd /workspace/game
godot --editor --path .
# ou lancer directement :
godot --path .
```

- Flèches ou ZQSD / WASD : direction, accélérateur, frein.
- Espace : frein à main, qui réduit fortement l’adhérence arrière.
- R / Replacer : retour au départ, chronomètre du tour réinitialisé.
- Échap / Pause : pause et reprise. Perdre le focus met en pause.
- Android : boutons tactiles simultanés direction / gaz / frein / frein à main.

La caméra garde le nord en haut et anticipe légèrement la trajectoire. Le circuit fermé mesure plusieurs centaines de mètres et dépasse largement l’écran. L’herbe offre moins d’adhérence et ralentit la voiture. Le HUD affiche la vitesse, la saturation dominante des pneus et les tours chronométrés. Les temps sont conservés uniquement pendant la session.

## Vérifier

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run.gd
```

Dans un bac à sable limitant l’écriture au workspace, définir des répertoires XDG accessibles avant de lancer Godot :

```sh
export XDG_DATA_HOME=/tmp/apex-data
export XDG_CONFIG_HOME=/tmp/apex-config
export XDG_CACHE_HOME=/tmp/apex-cache
```

Les tests vérifient la simulation de conduite, l’adhérence, les tours et le chargement de la scène. Ils ne remplacent pas une validation du toucher sur téléphone.

## Android

Un preset `Android` ARM64 est fourni. Installer les **templates d’export Godot 4.6.3**, **OpenJDK 17** et le **SDK Android** suivant la [documentation officielle Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html). Renseigner les chemins Java et Android SDK dans les paramètres de l’éditeur. Créer ou sélectionner un keystore de débogage local dans ces paramètres ; ne jamais versionner de clé de signature.

```sh
mkdir -p build/android
godot --headless --path . --export-debug Android build/android/apex.apk
adb install -r build/android/apex.apk
```

L’export nécessite le SDK et les templates. La version 0.1.0 livrée a été exportée avec Godot 4.6.3 et Java 21 ; les outils Android 36 sont utilisés pour vérifier le manifeste ciblant Android API 36. Avant diffusion : vérifier les commandes multitouch sur un appareil, le redimensionnement, les encoches, la reprise après arrière-plan et la fluidité. Les collisions entre véhicules, l’IA, les barrières et la sauvegarde des records restent à ajouter.

Voir [l’architecture et la physique](docs/architecture.md) pour modifier ou étendre le projet.

## Astral Relay

Course spatiale 3D indépendante pour Android. Foncez dans les tunnels et traversez l’espace en passant d’un couloir à l’autre. [Instructions et versions](astral-relay/README.md) · [Tester l’APK 1.1.0 ARM64](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.1.0-android-arm64.apk)
