# Astral Relay

Une course spatiale 3D sans fin, en paysage et jouable hors ligne. Foncez à travers des tunnels lumineux et des passages à ciel ouvert, choisissez votre route aux embranchements et battez votre record au rythme d’une bande-son électronique originale.

## Télécharger sur Android

- Pour la plupart des téléphones Android. [**Télécharger l’APK léger 1.0.0 (ARM64)**](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.0.0-android-arm64.apk)
- Pour les appareils Android et émulateurs x86-64. [Télécharger l’APK 1.0.0 (ARM64 et x86-64)](https://raw.githubusercontent.com/Elotoha/game/main/downloads/astral-relay-v1.0.0-android.apk)

Ouvrez le fichier téléchargé sur un appareil Android 7.0 ou plus récent (ARM64 ou x86-64). Si Android le demande, autorisez l’installation depuis l’application qui ouvre le fichier. Cette version de test est signée avec une clé de débogage conservée hors du dépôt. [Empreinte SHA-256](../downloads/SHA256SUMS)

## Piloter

- Sur **écran tactile**, maintenez le bord gauche, droit, haut ou bas pour vous déplacer. Les coins permettent de voler en diagonale. Maintenez le centre pour tirer et utilisez deux doigts pour piloter et tirer en même temps.
- Au **clavier**, les flèches, ZQSD ou WASD déplacent le vaisseau. Espace tire, Échap met en pause et Entrée lance une partie.

Écartez-vous du centre vers la route de votre choix avant l’embranchement. Détruisez les obstacles fragiles, esquivez les blocs solides et enchaînez les bonus pour augmenter votre multiplicateur. Trois cellules d’énergie déclenchent un turbo et restaurent un point de bouclier. Les bonus turbo s’activent dès le ramassage. Le record est conservé sur l’appareil.

## Lancer et compiler

Avec Godot 4.6.3, importez les ressources puis lancez le jeu depuis la racine du dépôt.

```sh
godot --headless --editor --path astral-relay --import --quit
godot --path astral-relay
```

Pour exporter sur Android, installez les modèles d’export Godot 4.6.3, OpenJDK 17 et les outils du SDK Android (plateforme 36, Build-Tools 36.0.0 et Platform-Tools). Renseignez les chemins du JDK et du SDK dans les paramètres d’export Android de l’éditeur. [Documentation Godot](https://docs.godotengine.org/fr/4.6/tutorials/export/exporting_for_android.html)

```sh
astral-relay/tools/export-android.sh
adb install -r astral-relay/build/android/astral-relay.apk
```
