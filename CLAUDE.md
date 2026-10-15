# Me Admin (me_mobile)

## Versionnage des builds (règle permanente)

Tout build release est versionné. Avant chaque build release, incrémente la version dans `pubspec.yaml` (`version: X.Y.Z+N`) :

- N, le numéro de build, augmente toujours de 1 au-dessus de la valeur `next_build_number` renvoyée par l'outil MCP `list-app-releases` (sinon, au-dessus de la valeur actuelle) ;
- X.Y.Z suit semver : correctif → Z, fonctionnalité → Y, rupture → X ;
- on ne recompile jamais un numéro de build déjà envoyé ;
- commiter la nouvelle version dans un commit dédié (« Version X.Y.Z+N »).

L'APK est toujours signé avec la même clé de release (jamais la clé de debug), sinon Android refuse la mise à jour. La clé est décrite dans `android/key.properties` (non versionné) ; sans ce fichier, `android/app/build.gradle.kts` fait échouer le build release.

## Procédure « compile et envoie »

Quand on me demande de compiler et d'envoyer :

0. Appeler `get-signing-key-backup` et comparer son `key_fingerprint` à l'empreinte SHA-256 du keystore local (voir « Clé de signature »). S'il n'y a pas de sauvegarde ou si l'empreinte diffère, prévenir l'utilisateur et attendre sa réponse avant de continuer.
1. Appeler `list-app-releases`, monter la version dans `pubspec.yaml` comme indiqué plus haut, puis lancer `flutter test`.
2. Lancer `flutter build apk --release --target-platform android-arm64` (APK unique de ~25 Mo : au-delà d'environ 100 s d'envoi, Cloudflare coupe avec une erreur 524 ; ne pas utiliser `--split-per-abi`, qui décale le versionCode), puis calculer le SHA-256 de `build/app/outputs/flutter-apk/app-release.apk`.
3. Appeler `prepare-app-release` avec `version_name`, `build_number`, des notes de version courtes en français (tirées des commits depuis la version précédente) et le `sha256`.
4. Lancer la commande `curl` renvoyée et vérifier que la réponse indique `has_file: true` avec le même `sha256`.
5. Appeler `publish-app-release` sans attendre de validation (une version finale compilée est toujours publiée), puis résumer la version, la taille et les notes. Ne pas publier si la vérification de l'étape 4 échoue.

Les outils `list-app-releases`, `prepare-app-release` et `publish-app-release` viennent du serveur MCP du portfolio (connecteur claude.ai « Mon Portfolio », ou serveur « portfolio » du projet). Si aucun des deux n'est disponible, demander de lancer :

```
claude mcp add --transport http portfolio https://<domaine-du-portfolio>/mcp/portfolio --header "Authorization: Bearer <jeton MCP de l'admin>"
```

## Clé de signature

- Keystore de release : `C:\Users\armel.meledje\keystores\me-admin-release.jks` (alias `me-admin`), hors du dépôt. `android/key.properties` (non versionné) donne son chemin (`storeFile`) et ses mots de passe. Perdre l'un des deux rend toute mise à jour de l'app impossible.
- Une sauvegarde chiffrée (archive tar du .jks, de key.properties et d'un LISEZMOI, chiffrée avec `openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt`) est stockée sur le portfolio : outils MCP `get-signing-key-backup` / `prepare-signing-key-backup`. La phrase secrète est dans le gestionnaire de mots de passe de l'utilisateur.
- Empreinte du certificat : `keytool -list -v -keystore <jks> -alias me-admin` (keytool du JDK, demande le mot de passe), ou sans mot de passe sur un APK release : `%LOCALAPPDATA%\Android\Sdk\build-tools\<version>\apksigner.bat verify --print-certs <apk>` (ligne « SHA-256 digest »).
- Règles : le serveur et Claude ne voient jamais la clé en clair, la phrase secrète ni le mot de passe du keystore. Claude prépare les commandes de chiffrement/déchiffrement ; l'utilisateur les lance lui-même et tape la phrase au clavier. Fichiers temporaires dans le scratchpad, jamais dans le dépôt, supprimés à la fin.

### Récupération quand `android/key.properties` manque

1. Appeler `get-signing-key-backup` (adresse de téléchargement valable 15 min), télécharger le blob avec `curl` dans le scratchpad et vérifier son SHA-256.
2. Donner à l'utilisateur la commande à lancer lui-même dans Git Bash : `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in <blob> -out me-admin-signing.tar`, puis `tar -xf me-admin-signing.tar`.
3. Placer le .jks hors du dépôt (ex. `C:\Users\<vous>\keystores\`), copier `key.properties` dans `android/` et y mettre `storeFile` sur le chemin absolu du .jks (barres `/`).
4. Vérifier que l'empreinte SHA-256 du certificat restauré est égale au `key_fingerprint` de la sauvegarde, puis supprimer les fichiers temporaires.

## Mise à jour hors store

`lib/core/updates/` : au démarrage une fois connecté, au déverrouillage et au retour au premier plan (au plus toutes les 6 h), l'app appelle `GET /v1/app/latest`, compare `build_number` au build installé, télécharge l'APK, vérifie son SHA-256 et ouvre l'installeur. Android seulement.
