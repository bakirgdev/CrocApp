---
sidebar_position: 6
title: Historique
description: "L'historique des transferts local à CrocApp : ce qu'il enregistre, ce qu'il n'enregistre délibérément jamais, et comment l'effacer."
---

# Historique (F12)

![L'écran Historique de CrocApp sur macOS listant les transferts passés avec leur direction, le nombre de fichiers et leur statut](/img/screenshots/mac-history-light.png#gh-light-mode-only)![L'écran Historique de CrocApp sur macOS listant les transferts passés avec leur direction, le nombre de fichiers et leur statut](/img/screenshots/mac-history-dark.png#gh-dark-mode-only)

CrocApp conserve une liste locale des transferts passés, accessible depuis l'icône d'historique de l'écran d'accueil. Elle ne quitte jamais l'appareil : il n'y a ni synchronisation, ni export, ni serveur impliqué.

## Ce qui est enregistré

Pour chaque transfert terminé ou échoué :

- La direction (envoyé ou reçu) et s'il s'agissait d'un transfert de texte
- Jusqu'à 20 noms de fichiers
- Le nombre total de fichiers et la taille totale
- Un **indice de code** : uniquement le premier segment de la phrase de code (par exemple, "7291-…"), jamais la phrase complète
- La date et le statut (terminé, échoué, annulé ou refusé)
- Pour les envois, un ensemble de signets de fichiers utilisés pour prendre en charge **Send Again** : capturés en tout ou rien, et seulement jusqu'à 200 éléments ; un enregistrement sans signets ne propose simplement pas Send Again

## Ce qui n'est jamais enregistré

- Le contenu des fichiers
- La phrase de code complète, uniquement cet indice du premier segment
- Tout ce qui dépasse les plafonds de 20 noms et 200 signets

## Send Again

Pour un envoi passé, le menu contextuel de l'entrée d'historique (ou l'action de balayage sur iOS) propose **Send Again** si des signets ont été capturés pour cet envoi. Cela remet en attente les mêmes fichiers dans un nouvel envoi. Si les fichiers d'origine ont été déplacés ou supprimés depuis, CrocApp vous indique qu'ils ne sont plus disponibles plutôt que de silencieusement ne rien envoyer.

## Effacer l'historique

Appuyez sur **Clear** dans la barre d'outils de l'écran d'historique, puis confirmez. Cela ne supprime que la liste : les fichiers déjà reçus restent exactement là où ils ont été enregistrés.
