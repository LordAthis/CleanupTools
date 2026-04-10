# CleanupTools
-------------------------------------

**Erősen korrupt / takarítandó Windows meghajtókhoz készült eszközkészlet**

Különösen külső meghajtók (E:, F:, stb.) gyökerében történő teljes takarításhoz optimalizálva.

# FIGYELEM!
Minden felelősség Téged terhel, használd ésszel, és csak akkor, ha tudod is, hogy mit csinálsz!



## Funkciók

- Teljes mappa takarítás (saját script kivételével)
- System Volume Information teljes kiürítése
- NTFS Reset (USN Journal, Shadow Copies, Indexing)
- Mély helyvizsgálat (rejtett foglaltságok felderítése)
- Intelligens Log Analyzer + ajánlások
- MasterCleanup – központi vezérlőpult

## Használat

1. Másold az összes fájlt a takarítandó meghajtó **gyökerébe** (pl. `E:\`)
2. Futtasd **rendszergazdaként** a `MasterCleanup.ps1` fájlt
3. Válaszd a kívánt opciót (ajánlott: 1-es teljes takarítás)

**Fontos**: Minden script automatikusan admin jogot kér, UTF-8 támogatással rendelkezik, és a `Log\` mappába írja a naplókat.

## Fájlok

- `MasterCleanup.ps1` → Központi menü
- `Takarito.ps1` → Agresszív fájl/mappa törlés
- `NTFS_Reset.ps1` → 6 GB+ rejtett foglaltságok ellen
- `SpaceDeepCheck.ps1` → Részletes helyfoglalás vizsgálat
- `LogAnalyzer.ps1` → Automatikus elemzés és javaslatok

## Tippek

- Mindig **újraindítás** után ellenőrizd a szabad helyet.
- Ha külső meghajtót takarítasz, az a legbiztonságosabb.
- Probléma esetén a `Log\` mappában található fájlokat küldd el.

---
 
**Verzió:** 2026.04  
**Cél:** Karbantartás, adatmentés előkészítés, Live Linux előtti takarítás


#MAPPASZERKEZET:
-------------------------------------

CleanupTools/                  ← Repo gyökér (vagy Cleanup-Tools)
├── Scripts/                       ← Ide kerülnek a .ps1 fájlok
│   ├── Takarito.ps1
│   ├── SVI_Cleanup_v2.ps1
│   ├── NTFS_Reset.ps1
│   ├── MasterCleanup.ps1
│   ├── SpaceDeepCheck.ps1
│   ├── LogAnalyzer.ps1
│   └── Chkdsk_Auto.ps1
│
├── Log/                           ← Ide kerülnek a futás közbeni logok (gitignored)
├── Docs/                          ← Dokumentáció
│   └── Használati_útmutató.md
├── _archive/                           ← Ide kerülnek a fájlok korábbi verziói
│
├── .gitignore
├── README.md
└── LICENSE                        ← (opcionális)






