# ReSNM

## What is ReSNM?

ReSNM is a Windows batch script meant to create customized .NET 1.1, 2.0 SP2, 3.0 SP2, and 3.5 SP1 installers targeting all 32-bit NT5 OSes (Windows 2000, XP,  and Server 2003). It can process all updates and language packs meant for each version (including Service Pack 1 for .NET 1.1), and output self-extracting installers as well as T-13 and RunOnceEx add-ons meant for use in nLite and RVM Integrator.

The first iteration of the script called SNM was authored by MSFN Forums user Tomcat76, and supported up-to .NET 2.0/3.0 SP1 and 3.5, ending development in 2008. When Tomcat76 stopped development, user strel picked-up the torch, renaming the project SNMsynth and adding support for .NET 2.0/3.0 SP2 and 3.5 SP1, continuing development until 2010.  Finally, user Zilver (with the help of user gora) released a minor update to SNMsynth in 2013, but development never picked-up in earnest after strel.

## Initial Gripes with SNMsynth

When I originally discovered SNMsynth, I was impressed. Instead of having to manually install then update .NET 1.1-3.5 every time I installed XP, I could just run one pre-made, fully-updated installer and be done with it. However, one thing that already bothered me was how SNMsynth decided what order to process updates in - it simply relied on Windows' `DIR` command to create the list of updates to read from. Given that the `DIR` command does not support natural sort, that means bigger numbers with smaller-value first digits will get placed first before smaller numbers with bigger-value first digits (e.g. KB2xxxxxx first, then KB8xxxxx). This means when trying to create a .NET 1.1 SP1 installer for XP, SNMsynth would first try processing a post-SP1 update *before* processing Service Pack 1, resulting in an installer with neither.

Also, when you went to use one of the generated installers, you *actually* needed Task Manager to let you know when the installation was done, because the installation process would still be running in the background. Therefore, only when CPU utilization dropped to zero did you know it was finished installing (this was actually a feature for slipstreaming).

## Development of ReSNM

2026\. It had been quite a few months since I uploaded my update to HFSLIP, and with winter still keeping me inside, I had nothing to sink my teeth into. That's when it dawned on me - why don't I give SNMsynth a "look"? I had already made one change to it before (that it read a list of updates to process from text files to solve that one gripe), but I knew that as with HFSLIP it was most likely going to require a lot of work.

It did.

I began refactoring and cleaning-up the code, examining the logic for fixes and improvements, and just trying to understand the code better - pure static analysis. I did that until I felt like it was in a good-enough spot to start doing live trial-and-error testing under an XP virtual machine to improve the processing steps. Even more debugging, development, and research followed suit until I felt comfortable testing the resulting installers the work-in-progress script produced, setting-up Windows 2000 SP4 and XP SP3 VMs to see how the installers behaved (VirtualBox snapshots were vital).

Nearly 5 months later, and I finally had something worth releasing.

## Biggest Changes Compared to SNMsynth

Here's a quick run-down of the biggest changes made in ReSNM:

- Massive refactoring while improving/fixing existing logic.
- Standardized processing as much as possible between different .NET versions.
- Removed dependency on [Oleg Scherbakov's](https://github.com/OlegScherbakov/7zSFX) third-party `7zSD.sfx` file, instead now uses official 7-zip one. While features like a hidden console are lost, we benefit from all of the advancements made by 7-zip in the past 15-years, as well as avoiding anti-virus false flags.
- Rewrote part of the created `INSTALL.cmd` script to support 4 flags/parameters and be more dynamic. The exact number of parameters supported is arbitrary and can be easily changed.
- Added requirement of text files that list the order in which updates are applied. This was one of the first changes I made to SNMsynth.
- Added requirement of `\HFXS` and `\MSTS` directories. Keeping things orderly.
- Mandate latest Service Packs for each .NET version. This allowed me to shrink the codebase.

## Considerations before Use

Some things to know before using ReSNM.

###  Environment

I have focused all of my attention for ReSNM towards Windows 2000 and Windows XP, therefore if something does not work perfectly under Windows Server 2003 you know why. I would recommend using Windows XP SP3 as your build environment. The .NET redistributables are picky when it comes to which OS they want to interact with.

If you plan on creating a .NET 1.1 SP1 installer, you ironically need .NET 1.1 SP1 and the latest security updates (just `KB2833941` for XP) installed. I believe this is because the .NET 1.1 installer and its updates depend on .NET 1.1 itself to be extracted to some extent.

### Redistributables

For .NET 2.0, make sure to choose between which redist you want to source .NET 2.0 SP2 from - either `NetFx20SP2_x86.exe` or `dotnetfx35.exe`. I have added checks so that you can only pull from one or the other. If you purely want .NET 2.0, say, for a .NET 1.1 SP1 + 2.0 SP2 installer for 2K or XP, then go with the former redist. However, if you plan on including .NET 3.0+3.5, then you must use the later redist.

For .NET 3.0 SP2, when ReSNM processes updates `KB982168` and `KB2756918`, it is okay to click `Okay` through the error messages. Both updates contain out-of-date patches targetting .NET 2.0 SP2 that are included/replaced by individual .NET 2.0 SP2 updates. The errors are caused by ReSNM attempting to automatically apply said patches to the .NET 3.0 SP2 redist being worked-on, but obviously given said redist is not a .NET 2.0 SP2 redist, it throws an error and does not get applied (as it should not). Perhaps I could add a patch check to avoid making the user see the errors...

### Individual Components

ReSNM allows you to modify/remove different components from the .NET 2.0-3.5 redists. It should be noted that in most instances you must install any components you have chosen to remove separately prior to installing each .NET version (specifics on which components this rule applies to covered in `ReSNM.ini`). Here are some things I want to point out regarding some components:

- Visual C++ 8/9 runtime libraries
    - For .NET 2.0 and 3.5 you can remove the outdated Visual C++ 8 (2005) and 9 (2008) runtime libraries from their redits, respectively.
    - I would recommend grabbing the latest libraries from [ChuckMichael's](https://gist.github.com/ChuckMichael/7366c38f27e524add3c54f710678c98b) GitHub repository. However, for VC8, you will need to install [`KB973923`](https://www.catalog.update.microsoft.com/Search.aspx?q=KB973923) and then [`KB2538242`](https://www.catalog.update.microsoft.com/Search.aspx?q=KB2538242) afterwards from the Microsoft Update Catalog.
- Win Imaging Component (WIC)
    - For .NET 3.0, you can remove the outdated Win Imaging Component (WIC) from its redist.
    - User yumeyao made a post on the now defunt RyanVM forum with his [updated WIC packs](https://web.archive.org/web/20141212212616/https://ryanvm.net/forum/viewtopic.php?t=7787) for use under XP and Server 2003.
- MSXML6
    - For .NET 3.0 you can remove the outdated `msxml6.dll` included with the redist. This only makes sense AFAIK for Windows XP SP2, as that OS does not come with `msxml6.dll` included.
    - ReSNM can update the `msxml6.dll` bundled with .NET 3.0, in which case the newest standalone update that I know of that ReSNM can use is `KB973686` (which provides a newer version than comes with stock XP SP3). Just place the update in the `\HFXS` directory - no need to add it to `30ORDER.txt`. Do note that update `KB2757638` for XP SP3 provides the newest version of `msxml6.dll`, though, so with a fully updated SP3 install `KB973686` is not necessary.
    - You can download [`KB973686`](https://www.catalog.update.microsoft.com/Search.aspx?q=KB973686) from the Microsoft Update Catalog.
- XPS
    - For .NET 3.0 you can remove the outdated XPS driver included with the redist.
    - ReSNM can update the driver bundled with .NET 3.0 with update `KB971276`. For XP, ReSNM can either only use the XP version of the update, or replace files in the XP version with newer files from the Server 2003 version of the update. I am though unaware what the latest version of XPS drivers are for XP or whether newer ones exist from Windows Update.
    - You can download `KB971276` from Legacy Update: [XP's](https://content.legacyupdate.net/support.microsoft.com/kb/971276/) (for now) and [2003's](https://legacyupdate.net/download-center/download/17385/update-for-windows-server-2003-kb971276).
- Windows Presentation Foundation Plugin (XBAP) for Firefox
    - For .NET 3.5 you can prevent the Windows Presentation Foundation plugin (XBAP) for Firefox from being installed.
    - If you are not sure whether you want it installed, you can have this setting not defined in `ReSNM.ini` and create your custom .NET 3.5 SP1 installer, but then pass the `-noffxbap` flag to the installer, preventing its installation.
- .NET FX Assistant 1.0 Firefox Extension (ClickOnce)
    - For .NET 3.5 you can prevent the .NET FX Assistant 1.0 Firefox extension (ClickOnce) from being installed.
    - Update `KB963707` is responsible for providing the latest version of this extension, and ReSNM requires it if this setting is not defined in `ReSNM.ini`. Therefore, I would personally recommend having this update placed in the `\HFXS` directory but defining said setting in `ReSNM.ini`.
    - If you are not sure whether you want it installed, you can have this setting not defined in `ReSNM.ini` and create your custom .NET 3.5 SP1 installer, but then pass the `-noffclickonce` flag to the installer, preventing its installation.
    - You can download [`KB963707`](https://www.catalog.update.microsoft.com/Search.aspx?q=963707) from the Microsoft Update Catalog.

## Usage

Download the entire repository and extract it to wherever you want.

Download the latest `7za.exe` file from [7-zip.org's](https://www.7-zip.org/download.html) "7-Zip Extra" package, and the latest `7zSD.sfx` file from the "LZMA SDK" package (located under the `\bin` directory). Extract both to your ReSNM folder.

Dump all of your redists, updates, and language packs into the `\HFXS` directory inside the ReSNM folder.

Configure ReSNM settings via `ReSNM.ini`.

Add the updates to want to apply to a given .NET version to the appropriate `??ORDER.txt` file. I provided the ones I used for testing which include all the updates needed to make Windows Update happy. Do note that there is no support for per-OS `ORDER.txt` files, so for the provided Windows 2000 files, you have to rename them to remove the "2K" from their names in order for ReSNM to read from them. Language packs are automatically detected from the `\HFXS` directory and processed, so do not include them in an `ORDER.txt` file.

Finally, run `ReSNM.cmd` and watch as your installer gets built. :)

## Considerations and Credits

There are still questions I have regarding some of the code inside ReSNM, so if you are interested in helping me check out the `TODO`'s I left inside the script. I also have left plenty of comments scattered all around the code to help you understand it better. :)

Thanks to Tomcat76 for creating the original script, and strel, yumeyao, and all those who contributed to this project prior.

Shout-out to [ss64.com](https://ss64.com/nt/) for the useful batch scripting documentation.

## Older Download Links

If you are curious about looking at the older versions of SNM, here are links to where you can find them:

 - [SNM](https://msfn.org/board/topic/90779-silent-net-maker-latest-update-20080603/) (original by Tomcat76)
 - [SNMsynth](https://msfn.org/board/topic/127790-silent-net-maker-synthesized-20100118-w2kxp2k3-x86/) (updated fork by strel)
 - [SNMsynth (2013)](https://msfn.org/board/topic/127790-silent-net-maker-synthesized-20100118-w2kxp2k3-x86/page/67/#findComment-1060116) (update by Zilver & gora)
