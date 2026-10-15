# Me Admin (me_mobile)

## Versionnage des builds (règle permanente)

Tout build release est versionné. Avant chaque `flutter build apk --release`, incrémente la version dans `pubspec.yaml` (`version: X.Y.Z+N`) :

- N, le numéro de build, augmente toujours de 1 au-dessus de la valeur `next_build_number` renvoyée par l'outil MCP `list-app-releases` (sinon, au-dessus de la valeur actuelle) ;
- X.Y.Z suit semver : correctif → Z, fonctionnalité → Y, rupture → X ;
- on ne recompile jamais un numéro de build déjà envoyé ;
- commiter la nouvelle version dans un commit dédié (« Version X.Y.Z+N »).

L'APK est toujours signé avec la même clé de release (jamais la clé de debug), sinon Android refuse la mise à jour. La clé est décrite dans `android/key.properties` (non versionné) ; sans ce fichier, `android/app/build.gradle.kts` fait échouer le build release.

## Procédure « compile et envoie »

Quand on me demande de compiler et d'envoyer :

1. Appeler `list-app-releases`, monter la version dans `pubspec.yaml` comme indiqué plus haut, puis lancer `flutter test`.
2. Lancer `flutter build apk --release`, puis calculer le SHA-256 de `build/app/outputs/flutter-apk/app-release.apk`.
3. Appeler `prepare-app-release` avec `version_name`, `build_number`, des notes de version courtes en français (tirées des commits depuis la version précédente) et le `sha256`.
4. Lancer la commande `curl` renvoyée et vérifier que la réponse indique `has_file: true` avec le même `sha256`.
5. Appeler `publish-app-release` sans attendre de validation (une version finale compilée est toujours publiée), puis résumer la version, la taille et les notes. Ne pas publier si la vérification de l'étape 4 échoue.

Les outils `list-app-releases`, `prepare-app-release` et `publish-app-release` viennent du serveur MCP du portfolio (connecteur claude.ai « Mon Portfolio », ou serveur « portfolio » du projet). Si aucun des deux n'est disponible, demander de lancer :

```
claude mcp add --transport http portfolio https://<domaine-du-portfolio>/mcp/portfolio --header "Authorization: Bearer <jeton MCP de l'admin>"
```

## Mise à jour hors store

`lib/core/updates/` : au démarrage une fois connecté, au déverrouillage et au retour au premier plan (au plus toutes les 6 h), l'app appelle `GET /v1/app/latest`, compare `build_number` au build installé, télécharge l'APK, vérifie son SHA-256 et ouvre l'installeur. Android seulement.
