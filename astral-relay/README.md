# Astral Relay

Une course spatiale 3D sans fin, en paysage et jouable hors ligne. Foncez à travers des tunnels lumineux et des passages à ciel ouvert au rythme de trois morceaux électroniques originaux.

## Télécharger sur Android

La version d’essai 1.1.0 est destinée aux téléphones ARM64 sous Android 7.0 ou plus récent. [**Télécharger l’APK 1.1.0**](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.1.0-android-arm64.apk)

Ouvrez le fichier téléchargé sur le téléphone. Si Android le demande, autorisez l’installation depuis l’application qui ouvre le fichier. Cette version de test est signée avec la même clé que la 1.0.0. [Empreintes SHA-256](../downloads/SHA256SUMS)

Chaque version publiée dispose d’une branche et d’un APK portant son numéro. [Sources 1.1.0](https://github.com/Elotoha/game/tree/versions/astral-relay-v1.1.0) · [Sources 1.0.0](https://github.com/Elotoha/game/tree/versions/astral-relay-v1.0.0) · [APK 1.0.0 pour ARM64](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.0.0-android-arm64.apk) · [APK 1.0.0 pour ARM64 et x86-64](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.0.0-android.apk)

## Piloter

- Sur **écran tactile**, touchez la moitié gauche ou droite. Le vaisseau reste dans le couloir choisi jusqu’au prochain changement.
- Au **clavier**, utilisez les flèches gauche et droite. Échap met en pause et Entrée lance une partie.

Le vaisseau tire automatiquement sur les obstacles fragiles. Une flèche indique le couloir libre à l’approche d’un obstacle solide. Trois cellules d’énergie déclenchent un turbo et restaurent un point de bouclier. Les embranchements sont désactivés pour cet essai et les passages ouverts restent au programme.

Pour écouter Deezer, passez en **Musique externe** depuis le menu ou la pause, puis lancez votre playlist dans l’application Deezer et revenez au jeu. Ce réglage coupe la bande-son du jeu et garde les effets sonores.

## Lancer et compiler

Avec Godot 4.6.3, importez les ressources puis lancez le jeu depuis la racine du dépôt.

```sh
godot --headless --editor --path astral-relay --import --quit
godot --path astral-relay
```

Pour vérifier les commandes, le tir et l’espacement des obstacles, lancez `godot --headless --path astral-relay --script tests/flight_test.gd`.

Pour exporter sur Android, installez les modèles d’export Godot 4.6.3, OpenJDK 17 et les outils du SDK Android (plateforme 36, Build-Tools 36.0.0 et Platform-Tools). Renseignez les chemins du JDK et du SDK dans les paramètres d’export Android de l’éditeur. [Documentation Godot](https://docs.godotengine.org/fr/4.6/tutorials/export/exporting_for_android.html)

```sh
astral-relay/tools/export-android.sh
adb install -r astral-relay/build/android/astral-relay.apk
```
