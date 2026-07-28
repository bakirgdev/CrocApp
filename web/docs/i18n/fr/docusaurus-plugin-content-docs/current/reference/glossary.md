---
sidebar_position: 3
title: Glossaire
description: Termes destinés aux utilisateurs, utilisés dans toute la documentation de CrocApp.
---

# Glossaire

| Terme | Signification |
|---|---|
| Phrase de code / secret | La chaîne `NNNN-word-word-word` que les deux côtés utilisent pour se trouver et dériver la clé de session. Les codes personnalisés comportent au moins 6 caractères. |
| PAKE | Échange de clé authentifié par mot de passe (Password-Authenticated Key Exchange). Transforme la phrase de code faible en une clé de chiffrement forte sans que le relais ne l'apprenne jamais. |
| Relais | Le serveur auquel les deux côtés se connectent quand une voie directe sur le réseau local n'est pas disponible. Ne voit que du texte chiffré, jamais la clé. |
| Salon | Le canal de rendez-vous sur le relais, dérivé des 4 premiers caractères de la phrase de code. Deux codes partageant ces caractères peuvent entrer en collision dans le même salon. |
| Courbe | La courbe elliptique sur laquelle PAKE s'exécute. CrocApp utilise celle par défaut de croc. |
| Algorithme de hachage | La vérification d'intégrité utilisée sur les fichiers transférés. |
| Découverte de pairs LAN | Le mécanisme qui permet aux transferts sur le même réseau de se passer entièrement du relais ; non garanti de fonctionner sur tous les réseaux. |
| Local uniquement | Un réglage qui force un transfert à rester sur le réseau local, refusant le relais si une voie directe n'est pas disponible. |
| Compression | Les données des fichiers sont compressées par défaut en transit ; cela peut être désactivé. |
| Badge de confiance | L'indicateur à l'écran montrant qu'un transfert est chiffré de bout en bout et quelle voie de relais il utilise. |
| Historique des transferts | Le journal local et sur l'appareil uniquement des transferts passés de CrocApp. |

Pour le glossaire complet destiné aux contributeurs et à l'architecture interne (fonctionnement interne du protocole croc, le pont Go/gomobile, l'architecture de l'app et les conventions du dépôt), voir [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) sur GitHub.
