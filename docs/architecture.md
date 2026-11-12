# Architecture

## Responsabilités

| Dossier | Responsabilité |
| --- | --- |
| `src/vehicle/vehicle_model.gd` | État et intégration de la voiture, sans Node ni dépendance au rendu |
| `src/vehicle/vehicle_config.gd` | Paramètres de masse, pneus, moteur et géométrie en unités SI |
| `src/vehicle/car_view.gd` | Dessin de la carrosserie et orientation des roues |
| `src/input/player_input.gd` | Traduction clavier/tactile en commande normalisée |
| `src/track/circuit.gd` | Centre du circuit, distance à la piste, progression et décor |
| `src/race/lap_tracker.gd` | Portes ordonnées et temps au tour |
| `src/race/race.gd` | Assemblage de la simulation, caméra, surface et traces |
| `src/ui/race_hud.gd` | HUD, mini-carte et commandes multitouch |
| `tests/run.gd` | Régressions de physique et test de scène, sans extension de test |

`VehicleModel.step(dt, command, handbrake, grip)` reçoit `Vector3(direction, accélérateur, frein)`. Direction entre −1 et +1, pédales entre 0 et 1. Un futur contrôleur IA produira les mêmes données ; la physique n’aura pas à connaître l’origine de la commande. Créer alors une instance de modèle et de vue par concurrent et extraire la gestion des concurrents de `race.gd`.

## Modèle de conduite

La simulation tourne à **120 Hz**, indépendamment du rendu. Les distances sont en mètres, les vitesses en m/s, les angles en radians. Seul le rendu applique 20 pixels/mètre. La voiture regarde selon son axe local +X ; +Y et le lacet positif tournent vers la droite dans le repère écran de Godot.

Le modèle plan à deux essieux calcule les vitesses latérales aux roues à partir du déplacement du centre de gravité et de la vitesse de lacet. Les angles de dérive alimentent une courbe de pneu continue : croissance, saturation, puis diminution vers un plateau de glissement. Les forces latérales et leurs bras de levier produisent translation et lacet ; la direction de la vitesse n’est jamais recollée artificiellement à celle de la carrosserie.

Le transfert longitudinal de charge dépend de l’accélération du pas précédent. Freinage et accélération consomment une partie du budget d’adhérence via un cercle de friction. Le frein à main freine l’essieu arrière et diminue sa force latérale : la rotation peut persister et mener au tête-à-queue. Un braquage trop important peut saturer l’avant et produire du sous-virage. Le contre-braquage agit par les mêmes forces de pneus.

Le modèle est volontairement simplifié : pas de suspension verticale, transfert latéral, différentiel, boîte de vitesses, aérodynamique d’appui ni rotation individuelle des roues. Le transfert de charge est borné pour la stabilité numérique. Les pneus ne représentent pas des données constructeur. Le ressenti nécessite encore des essais sur téléphone ; les tests garantissent des propriétés de simulation, pas un réglage définitif.

## Réglages

- Plus de raideur avant : réponse plus vive à petit angle ; saturation atteinte plus tôt.
- Moins de grip arrière / frein à main : survirage accru.
- Plus de hauteur du centre de gravité : transfert au freinage plus marqué.
- Plus d’inertie : rotation plus lente à engager et à arrêter.
- Les paramètres de référence sont centralisés dans `VehicleConfig`, pour ajouter ensuite plusieurs voitures et surfaces.

## Circuit et course

Un contour de points est interpolé par une spline de Catmull-Rom fermée, puis échantillonné. Le point le plus proche donne la distance au ruban d’asphalte et la progression. Les décors sont déterministes. La route n’est pas un mur : quitter la piste réduit le grip et ajoute une résistance. La remise en piste remet aussi le tour à zéro pour éviter les raccourcis via téléportation.

Le chronométrage exige les trois quarts du circuit dans l’ordre avant le retour au départ. Il empêche un simple va-et-vient sur la ligne, mais ce n’est pas encore un système anti-triche complet : pour une course compétitive, ajouter des portes géométriques directionnelles et invalider les raccourcis.

Les traces sont limitées à 1 600 segments. Pour des plateaux de concurrents importants, remplacer la recherche linéaire de segment par un index spatial et rendre les traces en lots.

## Prochaines extensions

1. Ressource de circuit éditable et points de grille de départ.
2. Contrôleur IA utilisant une trajectoire anticipée et une vitesse cible par courbure.
3. Gestion des concurrents, collisions, classement et départ de course.
4. Paramètres de conduite et commandes réglables, essais sur plusieurs appareils Android.

Chaque tâche cloud dispose déjà d’un checkout isolé : travailler dans le dépôt existant, sans créer de worktree sauf demande explicite.
