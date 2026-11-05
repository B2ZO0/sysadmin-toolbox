# "My computer turned itself back on": diagnosing automatic wake-ups

[Français](rallumage-auto.md) · [Back to the README](../README.md)

## The problem

Users told me that several workstations they had **shut down in the evening were on again in the morning**. Nobody had touched them, and on my side I saw nothing: no ticket, no alert, nothing obvious in the event viewer when I looked by hand, and of course it never happened while I was watching.

A computer can turn itself back on for many different reasons, and each one hides in a different place: a power setting, a registry key, a scheduled task, a device driver, the BIOS. Checking them one by one, on several computers, remotely, without disturbing the users, takes a long time.

## What I did

I wrote a script that **collects everything in one pass, remotely and silently**, and only changes something when I ask it to. It is now part of this module as two commands:

```powershell
# 1. Diagnose: changes nothing
Get-WakeReport -ComputerName PC-012, PC-013

# 2. See what woke them and when
(Get-WakeReport PC-012 -Days 14).Events | Format-Table

# 3. Fix, after checking what would change
Disable-AutoWake -ComputerName PC-012, PC-013 -WhatIf
Disable-AutoWake -ComputerName PC-012, PC-013
```

No window opens on the user's screen and nothing restarts: the fixes take effect at the next shutdown.

## What is checked, and what is fixed

| Cause | Why it turns the computer back on | Fix applied by `Disable-AutoWake` |
|---|---|---|
| **Fast startup** | "Shut down" is really a hibernation: the computer is not fully off and can be woken | Turned off: shutting down really shuts down |
| **Restart after a crash** | A crash (blue screen) during shutdown makes Windows restart | Turned off |
| **Automatic maintenance** | Windows may wake the computer at night to run its maintenance | No longer allowed to wake the computer |
| **Wake timers** | Programs and updates can program a wake-up | Turned off, on mains and on battery |
| **Devices allowed to wake** | The network card (Wake on LAN), a mouse or a keyboard can wake the computer | Their right to wake it is removed; the network keeps working |
| **Scheduled tasks** "wake the computer to run" | A task can wake the computer at a set time | Listed by `Get-WakeReport`, to review |
| **Events of the last days** | 1074: who asked for the shutdown or restart (Windows Update, a program, a user) · 41: unexpected shutdown (crash, power cut) · 1: what woke the computer | Shown, to understand what happened |

## If computers still turn on

Some causes are outside Windows and must be checked in the **BIOS/UEFI**, or with your vendor's tool:

- **Restore on AC power loss / After power failure**: after a power cut, the computer starts as soon as power comes back. A night-time power cut then looks like "it turned on by itself" (event 41 is a hint).
- **Wake on LAN** at BIOS level.
- **Power on by RTC / Alarm**: a time programmed in the BIOS.

## Requirements

- An administrator account on the target computers.
- PowerShell remoting (WinRM), enabled by default on domain computers.
- Windows 10/11 or Windows Server, PowerShell 5.1 or 7.
