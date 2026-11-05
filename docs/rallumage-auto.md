# « Mon PC s'est rallumé tout seul » : diagnostiquer les rallumages automatiques

[English](auto-wake.md) · [Retour au README](../README.fr.md)

## Le problème

Des utilisateurs m'ont signalé que plusieurs postes **éteints le soir étaient rallumés le matin**. Personne n'y avait touché, et de mon côté je ne voyais rien : aucun ticket, aucune alerte, rien d'évident dans l'observateur d'événements quand je regardais à la main, et évidemment ça n'arrivait jamais pendant que je regardais.

Un ordinateur peut se rallumer pour beaucoup de raisons différentes, et chacune se cache à un endroit différent : un réglage d'alimentation, une clé de registre, une tâche planifiée, un pilote de périphérique, le BIOS. Les vérifier une par une, sur plusieurs postes, à distance, sans déranger les utilisateurs, prend un temps fou.

## Ce que j'ai fait

J'ai écrit un script qui **récupère tout en une fois, à distance et en silence**, et qui ne modifie quelque chose que si je le lui demande. Il fait maintenant partie de ce module, sous forme de deux commandes :

```powershell
# 1. Diagnostic : ne modifie rien
Get-WakeReport -ComputerName PC-012, PC-013

# 2. Voir ce qui les a réveillés, et quand
(Get-WakeReport PC-012 -Days 14).Events | Format-Table

# 3. Corriger, après avoir vérifié ce qui changerait
Disable-AutoWake -ComputerName PC-012, PC-013 -WhatIf
Disable-AutoWake -ComputerName PC-012, PC-013
```

Aucune fenêtre ne s'ouvre chez l'utilisateur et rien ne redémarre : les corrections prennent effet au prochain arrêt du poste.

## Ce qui est vérifié, et ce qui est corrigé

| Cause | Pourquoi le poste se rallume | Correction appliquée par `Disable-AutoWake` |
|---|---|---|
| **Démarrage rapide** | « Arrêter » est en fait une mise en veille prolongée : le poste n'est pas vraiment éteint et peut être réveillé | Désactivé : l'arrêt éteint vraiment le poste |
| **Redémarrage après plantage** | Un plantage (écran bleu) pendant l'arrêt fait redémarrer Windows | Désactivé |
| **Maintenance automatique** | Windows peut réveiller le poste la nuit pour faire sa maintenance | N'a plus le droit de réveiller le poste |
| **Minuteurs de réveil** | Des programmes et des mises à jour peuvent programmer un réveil | Désactivés, sur secteur et sur batterie |
| **Périphériques autorisés à réveiller** | La carte réseau (Wake on LAN), une souris ou un clavier peuvent réveiller le poste | Leur droit de réveil est retiré ; le réseau continue de fonctionner |
| **Tâches planifiées** « réveiller l'ordinateur pour exécuter » | Une tâche peut réveiller le poste à heure fixe | Listées par `Get-WakeReport`, à examiner |
| **Événements des derniers jours** | 1074 : qui a demandé l'arrêt ou le redémarrage (Windows Update, un programme, un utilisateur) · 41 : arrêt brutal (plantage, coupure de courant) · 1 : ce qui a réveillé le poste | Affichés, pour comprendre ce qui s'est passé |

## Si des postes se rallument encore

Certaines causes sont hors de Windows et se vérifient dans le **BIOS/UEFI**, ou avec l'outil du constructeur :

- **Restore on AC power loss / After power failure** : après une coupure de courant, le poste démarre dès le retour du courant. Une coupure la nuit ressemble alors à « il s'est rallumé tout seul » (l'événement 41 est un indice).
- **Wake on LAN** au niveau du BIOS.
- **Power on by RTC / Alarm** : une heure de démarrage programmée dans le BIOS.

## Prérequis

- Un compte administrateur des postes ciblés.
- La communication à distance PowerShell (WinRM), active par défaut sur les postes du domaine.
- Windows 10/11 ou Windows Server, PowerShell 5.1 ou 7.
