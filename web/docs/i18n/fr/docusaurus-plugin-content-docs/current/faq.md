---
sidebar_position: 7
title: FAQ
description: Questions fréquentes sur CrocApp, incluant le coût, la sécurité, les comptes et la prise en charge des plateformes.
---

# FAQ

## Combien ça coûte ?

Rien. Pas d'achat, pas d'abonnement, pas de publicité et pas d'analytique. CrocApp est gratuit, sous licence MIT, et le restera. La monétisation se limite à un parrainage optionnel.

## Est-ce vraiment sécurisé ?

Les transferts sont chiffrés de bout en bout, la phrase de code authentifie les deux côtés, et le relais ne voit jamais que du texte chiffré. C'est toute l'affirmation, et c'est la conception de croc plutôt que quelque chose qu'ajoute CrocApp. Il n'y a eu aucun audit tiers formel de croc, et CrocApp ne prétend pas en avoir un. Le code des deux côtés est ouvert si vous voulez le consulter.

## Ai-je besoin d'un compte ?

Non. Il n'y a rien à créer et aucune identité rattachée à un transfert.

## Mon fichier passe-t-il par un serveur ?

Généralement oui, un relais, qui achemine le trafic entre deux appareils qui ne peuvent pas se joindre directement. Il ne voit que du texte chiffré et rien d'autre, et il ne stocke pas votre fichier. Vous pouvez plutôt pointer CrocApp vers votre propre relais.

## Et si nous sommes sur le même Wi-Fi ?

Alors le transfert va directement entre les deux appareils et se passe entièrement du relais. CrocApp essaie les deux voies à la fois et utilise celle qui se connecte en premier.

## En quoi est-ce différent d'AirDrop ?

AirDrop nécessite deux appareils Apple à proximité physique. CrocApp fonctionne entre deux appareils quelconques exécutant croc ou CrocApp, sur n'importe quel réseau, à n'importe quelle distance, y compris d'un Mac vers un serveur Linux à l'autre bout du monde.

## Est-ce compatible avec l'outil en ligne de commande croc ?

Oui, dans les deux sens. CrocApp intègre croc v10.5.0 comme bibliothèque, si bien qu'il parle le même protocole. `croc send` sur un ordinateur portable, réception dans l'app sur un téléphone, et inversement.

## Puis-je exécuter mon propre relais ?

Oui. Pointez CrocApp vers n'importe quel relais croc, avec un mot de passe et IPv6 si vous le souhaitez. Exécuter `croc relay` sur une machine que vous contrôlez suffit.

## Pourquoi uniquement iOS 26 et macOS 26 ?

CrocApp est une app entièrement nouvelle sans utilisateurs existants. Prendre en charge des versions plus anciennes signifierait des vérifications de disponibilité partout et renoncer aux API SwiftUI actuelles et au langage de design Liquid Glass. Le seuil est fixé exactement à `26.0`, jamais une version mineure.

## Est-ce gratuit ? Y aura-t-il un jour un palier payant ?

Gratuit, sous licence MIT, et ça le restera. La monétisation se limite à un [parrainage](https://github.com/sponsors/bakirgdev) optionnel.

## Y aura-t-il une version Windows, Linux ou Android ?

Non. CrocApp est exclusivement pour les plateformes Apple, par choix de conception. Utilisez le [CLI croc](https://github.com/schollz/croc) ailleurs, il est interopérable avec cette app.
