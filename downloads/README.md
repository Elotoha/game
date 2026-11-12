# Android — version de test 0.1.0

Télécharger `apex-v0.1.0-android-arm64.apk` et ouvrir le fichier sur le téléphone. Si Android le demande, autoriser temporairement l’installation depuis l’application utilisée pour ouvrir le fichier.

- Architecture : ARM64 (arm64-v8a).
- Orientation : paysage ; commandes tactiles simultanées.
- Signature : clé de débogage, pour essais manuels, pas pour Google Play.
- SHA-256 : voir `SHA256SUMS`.
- Pas de validation sur appareil physique lors de cette livraison.

La clé privée reste hors du dépôt. Une prochaine version signée avec une autre clé nécessitera de désinstaller cette version avant installation.

Sources : racine du dépôt ; procédure de compilation : `tools/export-android.sh` et `README.md`.
