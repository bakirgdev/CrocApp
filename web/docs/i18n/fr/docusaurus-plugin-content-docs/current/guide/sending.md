---
sidebar_position: 1
title: Envoyer des fichiers
description: Comment envoyer des fichiers, des dossiers et du texte dans CrocApp, y compris l'extension de partage et la règle du transfert actif unique.
---

# Envoyer des fichiers

Ouvrez **Send** depuis l'écran d'accueil. Le sélecteur **What to send** bascule entre deux modes :

## Fichiers (F1, F2)

- **Add Files** ouvre un sélecteur de fichiers ; vous pouvez sélectionner plusieurs fichiers à la fois.
- **Add Folder** choisit un dossier entier à envoyer.
- Sur macOS, vous pouvez aussi glisser des fichiers ou des dossiers sur la zone de dépôt.
- Les éléments choisis apparaissent dans une liste, chacun retirable via son bouton **x**.

## Texte (F3)

Tapez ou collez dans la zone de texte, ou utilisez le bouton **Paste** pour récupérer directement le contenu actuel du presse-papiers (c'est une action explicite, pas une lecture silencieuse en arrière-plan).

## Code personnalisé (F5)

Le champ **Custom code** est facultatif. Laissez-le vide pour un code généré, ou saisissez le vôtre (6 caractères minimum) afin qu'il puisse être partagé via un canal auquel vous faites déjà confiance, par exemple en le dictant au téléphone.

## Démarrer l'envoi

Appuyez sur **Send**. CrocApp affiche la phrase de code générée (ou personnalisée), un bouton **Copy Code** et un QR code (F6) que le destinataire peut scanner. L'écran affiche aussi un badge de confiance décrivant la voie de relais utilisée.

## Un seul transfert actif à la fois

CrocApp permet exactement un seul transfert actif à la fois, conformément à une limite du moteur sous-jacent. Vous ne pouvez pas démarrer un deuxième envoi ou une deuxième réception tant qu'un transfert est en cours ; terminez ou annulez le transfert actuel d'abord.

## Extension de partage (iOS uniquement, F30)

Sur iOS, vous pouvez partager des fichiers vers CrocApp depuis la feuille de partage de n'importe quelle autre app. Les éléments partagés sont mis en attente, et une feuille **Shared files** apparaît avec les boutons **Discard** et **Send** à la prochaine ouverture de CrocApp. Choisir **Send** transfère les fichiers en attente dans le déroulement normal d'envoi.

## Feuille des fichiers en attente

La feuille des fichiers en attente liste tous les éléments partagés, afin que vous puissiez vérifier ce qui sera envoyé avant de vous engager.

## Ce que voit l'expéditeur pendant le transfert

Une fois que le destinataire se connecte, CrocApp affiche **Ready to send** et attend. Si [la confirmation des deux côtés](power-options.md) est activée, une invite **Receiver connected** apparaît avec **Send** / **Cancel** avant que quoi que ce soit ne bouge. Pendant le transfert, CrocApp affiche la progression par fichier et globale avec la vitesse, ainsi qu'un bouton **Cancel**.
