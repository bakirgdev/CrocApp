---
sidebar_position: 3
title: Phrases de code
description: Ce qu'est une phrase de code CrocApp, pourquoi elle sert à la fois d'adresse et de mot de passe, et les façons sûres d'en partager une.
---

# Phrases de code

Une phrase de code ressemble à `8412-mirage-cobalt-fresco` : un court code PIN suivi de quelques mots. Elle est générée à neuf pour chaque transfert, sauf si vous en définissez une personnalisée sur l'[écran d'envoi](sending.md).

## C'est à la fois l'adresse et le mot de passe

Saisir le code sur l'autre appareil est tout ce qu'il faut : c'est à la fois ce qui permet aux deux appareils de se trouver et le secret qui sécurise le transfert. Il n'y a rien d'autre à configurer pour un transfert normal.

## Comment elle sécurise le transfert

Les deux appareils exécutent **PAKE** (échange de clé authentifié par mot de passe) sur la phrase de code pour la transformer en une clé de chiffrement forte :

- Le code lui-même ne traverse jamais le réseau en clair.
- Un code erroné échoue immédiatement, avant que la moindre donnée de fichier ne bouge.
- Tout est chiffré sur l'appareil expéditeur et déchiffré uniquement sur celui du destinataire ; rien entre les deux ne peut le lire.

## À usage unique et expirant

Chaque transfert utilise une phrase de code à usage unique. Quiconque a le code est considéré comme le partenaire de ce transfert, et le code expire avec lui : il n'est pas réutilisable pour un transfert ultérieur.

## Le partager : QR code et collage

CrocApp affiche le code en texte et sous forme de QR code (F6). La charge utile du QR code est `croc://<code>`, donc le scanner fonctionne aussi avec d'autres outils qui comprennent le même format de lien profond.

Pour faire entrer un code dans le champ **Receive**, vous avez deux options explicites : utiliser le bouton **Paste**, ou (iOS) appuyer sur **Scan QR Code**. CrocApp ne lit jamais silencieusement le presse-papiers ; coller est toujours quelque chose que vous déclenchez vous-même. Le texte collé ou scanné peut inclure le préfixe `croc://` ou être un code nu, les deux sont acceptés, tant que ce qu'il reste comporte au moins 6 caractères sans espace.

## Codes personnalisés

Un code personnalisé doit comporter au moins 6 caractères. Définissez-le dans le champ **Custom code** de l'écran d'envoi afin de pouvoir le partager via un canal auquel vous faites déjà confiance (un appel téléphonique, une discussion déjà chiffrée) plutôt que de dépendre du code généré.

## Partager un code en toute sécurité

Partagez-le via un canal de confiance, de la même façon que vous partageriez un code d'accès à usage unique : dites-le à voix haute, envoyez-le via une discussion déjà de confiance, ou laissez le destinataire scanner le QR code directement sur votre écran. Comme le code est à la fois l'adresse et le mot de passe, quiconque l'obtient avant la fin du transfert peut le rejoindre.
