---
sidebar_position: 6
title: Rješavanje problema
description: "Stvarna, provjerena rješenja za česte probleme sa CrocApp-om: zaglavljeni prenosi, odbijeni kodovi, ograničenja rada u pozadini i problemi s dozvolama."
---

# Rješavanje problema

## Prenos se zaglavi ili se nikad ne poveže

CrocApp utrkuje direktnu vezu preko lokalne mreže sa relejem i koristi onu koja se prva poveže. Otkrivanje uređaja na lokalnoj mreži koristi UDP multicast, i nije zagarantovano da će raditi na svakoj mreži: neke mreže (na primjer, Wi-Fi sa izolacijom klijenata) uopšte ne vraćaju lokalne uređaje, iako relejni put i dalje radi ispravno. Ako se prenos zaglavi na "Waiting" ili "Connecting":

- Provjerite da oba uređaja imaju ispravan pristup internetu, kako bi relejni put mogao raditi čak i ako lokalni ne može.
- Provjerite [dozvolu za lokalnu mrežu](#local-network-permission-prompt) ispod.
- Ne postoji rješenje unutar aplikacije za mrežu koja u potpunosti blokira otkrivanje putem multicast-a; prenos bi ipak trebao uspjeti preko releja.

## Kod je odbijen ili dugme za prijem ostaje onemogućeno

- Kodna fraza mora imati najmanje 6 znakova. Dugme **Receive** ostaje onemogućeno dok ne unesete dovoljno znakova.
- Pogrešan kod odmah propada umjesto da visi.
- Ako koristite prilagođeni kod koji koristite i za testiranje ili skriptovanje, imajte na umu da kodovi koji dijele prva 4 znaka mogu kolidirati u istu relejnu sobu. Generisani kodovi nemaju ovaj problem.

## Druga strana koristi drugačiju verziju croc-a

CrocApp ugrađuje croc v10.5.0 kao svoj engine. Napravljen je da bude interoperabilan sa `croc` CLI-jem u oba smjera. Ako druga strana koristi jako staru ili neuobičajeno novu `croc` verziju, koristite razumno aktuelnu verziju CLI-ja kako biste izbjegli neusklađenost protokola.

## Ograničenja rada u pozadini na iOS-u

iOS ne dozvoljava da sirovi TCP prenosi proizvoljno nastave raditi u pozadini. CrocApp koristi `BGContinuedProcessingTask` (iOS 26+) kako bi prenos nastavio i prikazao sistemsku Live Activity, ali to je najbolji mogući pokušaj: sistem ga može prekinuti pod pritiskom memorije, a prenos sa malim napretkom vjerovatnije će biti prekinut od skoro završenog. Za prenos koji ne želite da bude prekinut, držite CrocApp u prvom planu dok se ne završi. Ako ipak dođe do prekida, croc-ovo vlastito ponašanje nastavka znači da ponovno pokretanje istog prenosa nastavlja odatle gdje je stao, umjesto da počinje ispočetka.

## Zahtjev za dozvolu lokalne mreže {#local-network-permission-prompt}

Pri prvoj upotrebi lokalne mreže, iOS prikazuje sistemski upit tražeći dozvolu da CrocApp pronalazi uređaje na vašoj lokalnoj mreži. Ako je odbijete, ili odobrenje ostane "zaglavljeno" (poznata iOS neobičnost gdje odobrena dozvola zapravo ne radi dok je ne isključite i uključite ili ne restartujete uređaj), CrocApp se vraća samo na relej. Ako vidite baner "Local network access is off — transfers use the relay only," koristite njegovo dugme **Open Settings** da provjerite Settings › Privacy › Local Network.

## Primljeni fajlovi nisu vidljivi tamo gdje se očekuje

- Na iOS-u, primljeni fajlovi završavaju u Documents folderu aplikacije, koji je podrazumijevano vidljiv u aplikaciji Files.
- Ako je vaše odredište za prijem postavljeno na folder odabran putem dobavljača cloud skladišta (umjesto lokalne lokacije), dugme **Open in Files** nakon prijema možda se neće ispravno otvoriti: ovo je poznato ograničenje. Umjesto toga, ručno se prebacite do foldera u aplikaciji Files.

## Relej nedostupan

CrocApp podrazumijevano koristi croc-ov javni relej. Ako je nedostupan sa vaše mreže, umjesto njega možete postaviti [prilagođeni relej](guide/settings-and-trust.md) koji vi kontrolišete, ili uključiti **Local network only** ako su oba uređaja na istoj mreži i relej vam uopšte nije potreban.

## Automatsko prihvatanje i pošiljaoci sa `--ask`

Ako imate uključeno automatsko prihvatanje, a pošiljalac koristi croc-ovu potvrdnu oznaku `--ask`, prenos može biti automatski odbijen, a CrocApp-ova poruka trenutno okrivljuje pogrešnu stranu ("the other side declined") umjesto da objasni da je to uzrokovala vaša vlastita postavka automatskog prihvatanja. Ovo je poznat problem bez rješenja za sada; isključivanje automatskog prihvatanja to izbjegava.

## Nema dugmeta za otkazivanje tokom pregleda dolaznog prenosa

Kada gledate listu dolaznih fajlova, **Decline** je jedini izlaz: na tom koraku nema posebnog dugmeta za otkazivanje, a obavještenje o završetku prenosa može malo kasniti dok croc u pozadini završava pokušaje ponovnog povezivanja. Ovo je očekivano ponašanje, a ne greška.
