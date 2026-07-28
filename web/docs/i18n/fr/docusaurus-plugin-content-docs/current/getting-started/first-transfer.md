---
sidebar_position: 2
title: Votre premier transfert
description: Un parcours d'un envoi et d'une réception dans CrocApp, avec les libellés réels affichés à l'écran dans l'app.
---

# Votre premier transfert

L'écran d'accueil de CrocApp comporte deux boutons : **Send** et **Receive**. Tout le reste découle d'un déroulement en trois étapes :

1. L'expéditeur choisit des fichiers, un dossier ou un extrait de texte.
2. CrocApp génère une phrase de code. Dites-la à voix haute, envoyez-la par message ou affichez-la sous forme de QR code.
3. Le destinataire saisit la phrase, voit la liste des fichiers et accepte.

Les deux appareils exécutent PAKE sur la phrase de code pour dériver une clé de session, si bien que la phrase ne traverse jamais le réseau en clair et que le relais ne l'apprend jamais. Les fichiers sont chiffrés avec la phrase de code ; le relais ne voit jamais que du texte chiffré. Même Wi-Fi ou continents différents, CrocApp trouve automatiquement la voie la plus rapide.

## Envoyer

1. Depuis l'écran d'accueil, appuyez sur ou cliquez sur **Send**.
2. Sous **What to send**, choisissez **Files** ou **Text**.
   - Pour des fichiers : utilisez **Add Files** ou **Add Folder**, ou glissez des fichiers sur la zone de dépôt (macOS).
   - Pour du texte : tapez ou collez dans la zone de texte.
3. Facultatif : définissez un **Custom code** (au moins 6 caractères) au lieu d'un code généré.
4. Appuyez sur **Send**.
5. CrocApp affiche **Ready to send** avec la phrase de code, un bouton **Copy Code** et un QR code. Partagez le code avec le destinataire via un canal de confiance.
6. Une fois que le destinataire se connecte et accepte, le transfert démarre. Une fois terminé, CrocApp affiche **Transfer complete**.

## Recevoir

1. Depuis l'écran d'accueil, appuyez sur ou cliquez sur **Receive**.
2. Saisissez la **Code phrase** donnée par l'expéditeur, collez-la, ou (sur iOS) appuyez sur **Scan QR Code**.
3. Vérifiez le dossier de destination affiché sous le champ de code ; modifiez-le avec **Change** si besoin.
4. Appuyez sur **Receive**.
5. CrocApp affiche **Incoming transfer** avec la liste des fichiers et la taille totale. Vérifiez-la, puis appuyez sur **Accept** ou **Decline**.
6. Une fois le transfert terminé, CrocApp affiche **Transfer complete** avec un bouton pour ouvrir le dossier de destination (**Open in Files** sur iOS, **Show in Finder** sur macOS).

Pour le détail complet de chaque étape, voir [Envoyer des fichiers](../guide/sending.md) et [Recevoir des fichiers](../guide/receiving.md).
