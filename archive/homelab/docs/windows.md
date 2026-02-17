windows scripts

```powershell
https://www.atera.com/shared-script-library/disable-user-access-control/
```

Use in windows powershell to activate any version of windows/office/etc

```ps1
 irm https://get.activated.win | iex
```

install powershell 7 using powershell admin

```ps1
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
```

use to quickly setup windows and set ideal settings, use powershell admin

```ps1
iwr -useb https://christitus.com/win | iex
```

> https://christitus.com/windows-tool/


Here is how to execute each step safely.

1. The Registry Edit for Auto Login
Warning: This saves your password in plain text in the registry. Since this is a gaming VM on a private server, this is usually acceptable risk.

Press Windows Key + R, type regedit, and press Enter.

Navigate to this path (you can paste it in the top bar): HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

Look for AutoAdminLogon. Double-click it and set it to 1.

Look for DefaultUserName. Ensure it matches your username.

Create the Password Field:

Right-click empty space > New > String Value.

Name it: DefaultPassword (Case sensitive!).

Double-click it and enter your actual password.

(Optional/Verification): Ensure DefaultDomainName is your computer name (usually automilled), or just delete the key if you aren't on a domain.

Alternative (Easier): If you run the Chris Titus Tool (below), it actually has an "Auto Logon" button in the Config tab that does this for you automatically!

2. Disable the "Warning" (SmartScreen)
To stop the "Make sure you trust this file" nag screens:

Open Start and type "App & browser control".

Click Reputation-based protection settings.

Turn OFF "Check apps and files".

Turn OFF "SmartScreen for Microsoft Edge".

Turn OFF "Potentially unwanted app blocking".

3. Should you run the Chris Titus Tool (CTT)?
iwr -useb https://christitus.com/win | iex

YES. This is the gold standard for optimizing Windows gaming VMs.

What to do inside the tool:

Run the command in PowerShell (Admin).

Go to the Tweaks tab.

Select the "Desktop" or "Gaming" preset at the top.

This will disable Telemetry, Wifi Sense, Activity History, etc.

Critical for VM: Look for "Run O&O ShutUp10"? You don't need to run O&O separately if you run CTT; CTT applies many of the same registry fixes.

Click Run Tweaks.

Updates Tab: Select "Security Settings" (This stops feature updates that might break your VM, but keeps security patches).

4. Should you run the Activation Script (MAS)?
irm https://get.activated.win | iex

Technically: Yes, this command launches the "Microsoft Activation Scripts" (MAS). Context: This is the standard open-source tool used by the homelab/enthusiast community to permanently activate Windows using the HWID method. It is widely considered safe and clean (open source).

Instruction: If you choose to run it, select option [1] HWID for a permanent activation.

5. Final Checklist (Do this "Right Now")
Since you are running those tools, here are the exact housekeeping items to hit while you are in PowerShell:

Disable Hibernate (Save Disk Space): Since this is a VM, you don't need "Fast Startup" or Hibernate files cluttering your vDisk.

PowerShell Command: powercfg -h off

Set High Performance Power Plan: Prevent the VM from putting the virtual CPU to sleep.

PowerShell Command: powercfg -s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Verify Sleep Settings: Even with the power plan, double-check:

Start > Power & sleep settings.

Set "Screen" and "Sleep" to Never.

Summary of Order:

Run CTT (Chris Titus) -> Apply "Gaming" Tweaks.

Use CTT to set Auto Logon (easier than Regedit).

Run MAS (Activation) if you choose to.

Run powercfg -h off.

Reboot and enjoy your server!



This is the smartest way to handle a VM setup. You’re building a "Golden Image" — a perfectly configured, clean master file that you can copy infinitely.

Here is your exact roadmap to finish the Master, Clone it, and create your Isolated Sandbox.

### Phase 1: Finish the "Master" VM

Before cloning, let's finalize the RAM disk and remove the installation "training wheels" (ISOs).

#### 1\. Configure the RAM Disk (Inside Windows)

We need to tell Windows to stop writing junk to your NVMe and write it to the Z: drive instead.

  * **Boot the VM** and log in via RDP.
  * **Check the Drive:** Ensure your **Z:** drive (or whatever letter the RAM disk took) is visible in File Explorer.
  * **Create the Folder:** Open Z: and create a folder named `Temp`.
  * **Change Variables:**
    1.  Open Start, type **"Edit the system environment variables"**, and hit Enter.
    2.  Click **Environment Variables** (bottom right).
    3.  **Top Section (User variables):**
          * Select `TEMP` -\> Edit -\> Change value to `Z:\Temp`
          * Select `TMP` -\> Edit -\> Change value to `Z:\Temp`
    4.  **Bottom Section (System variables):**
          * Select `TEMP` -\> Edit -\> Change value to `Z:\Temp`
          * Select `TMP` -\> Edit -\> Change value to `Z:\Temp`
    5.  Click OK -\> OK.
  * *Verification:* Open `Run` (Win+R), type `%temp%`, and hit Enter. It should open your Z: drive folder.

#### 2\. Detach the ISOs (In Unraid)

Now that Windows is installed and drivers are loaded, you don't need the virtual CD-ROMs anymore.

  * **Shut down the VM.**
  * **Edit the VM** in Unraid.
  * **OS Install ISO:** Set to "None" (or delete the path).
  * **VirtIO Drivers ISO:** Set to "None".
  * **Click Update.**
      * *Why:* This stops the "Press any key to boot from CD..." prompt and speeds up boot time.

#### 3\. The Final Headless Test

  * Start the VM.
  * **Do not** open VNC or RDP.
  * Open **Moonlight** on your phone/laptop.
  * Connect to the desktop.
  * *Success Check:* If you see the desktop and can move the mouse, your Master is complete. **Shut it down.**

-----

### Phase 2: Create the "Baseline" (Backup)

You are now going to save this state forever. If you ever break your VM, you can restore this file in seconds.

1.  **Open Unraid Terminal** (top right `>_` button).
2.  Run these commands to create a backup folder and copy your disk:
    ```bash
    # Create a backup directory
    mkdir -p /mnt/user/isos/vm-backups/win10-master

    # Copy the master disk (This ensures we have a pristine copy)
    # Note: Replace the path below with your ACTUAL vdisk path if different
    cp /mnt/nvme/system/vm/Windows\ 10/vdisk1.img /mnt/user/isos/vm-backups/win10-master/vdisk1-master.img
    ```
    *(Note: Using `cp` can take a few minutes for a 64GB file. Wait for the cursor to return).*

-----

### Phase 3: Create the "Sandbox" (Restricted Clone)

Now we create a *separate* VM for testing dangerous files. We will use a copy of your master disk so we don't ruin the original.

#### 1\. Create the Sandbox Disk

Copy your master backup to a *new* folder for the sandbox.

```bash
# Create sandbox folder
mkdir -p /mnt/nvme/system/vm/Windows-Sandbox

# Copy the master image to the sandbox folder
cp /mnt/user/isos/vm-backups/win10-master/vdisk1-master.img /mnt/nvme/system/vm/Windows-Sandbox/vdisk1.img
```

#### 2\. Create the Sandbox VM

1.  Go to **VMs \> Add VM \> Windows 10**.
2.  **Name:** `Windows-Sandbox`
3.  **CPU/RAM:** Give it fewer resources if you want (e.g., 2 cores, 4GB RAM).
4.  **Primary vDisk:**
      * **Select:** Manual.
      * **Path:** `/mnt/nvme/system/vm/Windows-Sandbox/vdisk1.img`
      * **Bus:** `VirtIO` (Important: Must match the Master).

#### 3\. Isolate the Network (The "Malware" Protection)

You want this VM to have Internet (to download files) but **NO access** to your Unraid server or other computers on your home WiFi.

  * **In Unraid VM Settings:**

      * **Network Source:** Change from `br0` to **`virbr0`** (Linux Bridge).
      * *What this does:* This puts the VM behind a "NAT" firewall. It creates a separate subnet (usually 192.168.122.x).

  * **Extra Protection (Inside the Sandbox VM):**
    Even with `virbr0`, a VM *can* sometimes "route" packets to your home network. To be 100% safe, add a Firewall Rule inside the Windows Sandbox:

    1.  Boot the Sandbox VM.
    2.  Open **Windows Defender Firewall with Advanced Security**.
    3.  **Outbound Rules** \> New Rule \> Custom.
    4.  **Scope** \> "These IP addresses" (Remote IP).
    5.  **Add:** `192.168.0.0/16` (or `10.0.0.0/8` if you use 10.x IPs).
    6.  **Action:** **Block the connection**.
    7.  *Result:* This VM can talk to Google/Internet, but if it tries to ping your Unraid server or Laptop, Windows blocks it immediately.

### Summary Checklist

1.  [ ] **Master:** Setup Z: Temp folders & Detach ISOs.
2.  [ ] **Master:** Perform Moonlight test.
3.  [ ] **Backup:** `cp` the vDisk to a safe folder (`/isos/vm-backups`).
4.  [ ] **Sandbox:** Create new VM pointing to a *copy* of that disk.
5.  [ ] **Sandbox:** Set Network to `virbr0` + Block LAN via Windows Firewall.



---
---

The "Silver Bullet" Fix: Autologon.exe
This small tool from Microsoft encrypts your password and forces the Auto-Login to stick, even after updates.

Connect via RDP (or VNC) one last time.

Open Edge in the VM and download Autologon from Microsoft:

Link: https://learn.microsoft.com/en-us/sysinternals/downloads/autologon

(Or search "Sysinternals Autologon").

Run Autologon.exe.

Enter your credentials:

Username: (Usually filled in).

Domain: (Leave as is, usually your PC name).

Password: Enter your password.

Click Enable.

It should say "Autologon successfully configured".

2. Disable the "Lock Screen" (The Picture Screen)
Even with Auto-Login, Windows sometimes shows a "Swipe to Unlock" screen. Let's kill that too.

Open PowerShell (Admin).

Paste this command:

PowerShell

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f
3. Prevent "Relocking" on Disconnect
You don't want the VM to lock itself if your stream drops for a second.

Open Settings > Accounts > Sign-in options.

Scroll to "Require sign-in".

Change it to "Never".

4. The Final "Real" Test
Reboot the VM (Start > Restart).

Wait 30-60 seconds (Do NOT connect with RDP).

Open Moonlight on your phone/laptop.

Launch Desktop.

Result: You should fly straight into the desktop without typing a single password.



---
---


Setting Sunshine to run as administrator is a "double-edged sword" in a headless VM.

### The Short Answer
**No, do not set it to "Run as Administrator" yet.**
Doing so often breaks the "Startup" process because Windows User Account Control (UAC) will pause the launch and wait for you to click "Yes" on a prompt you can't see. This will cause Sunshine to hang indefinitely on boot.

However, running as Admin **is** helpful later if you find that your mouse/controller stops working inside specific games (like *Genshin Impact* or games with Anti-Cheat).

---

### The Recommended "Golden Path"
Since your main goal right now is **getting it to start reliably**, stick to the "User Mode" method (Fix 2) I mentioned, but with one specific tweak to ensure it has the permissions it needs without the UAC block.

#### 1. Do NOT check "Run as Administrator" on the EXE
If you right-click the EXE > Compatibility > "Run as Administrator", **undo that**. It causes more headaches than it solves for headless boot.

#### 2. Use the "Shell:Startup" Method (Safest)
This runs Sunshine with your user's standard permissions, which are sufficient for 99% of games and ensures it loads *after* the desktop/display is ready.

1.  **Stop & Disable the Service:**
    * `services.msc` > **Sunshine Service** > Stop > Startup Type: **Disabled**.
2.  **Create the Shortcut:**
    * Go to `C:\Program Files\Sunshine`.
    * Right-click `sunshine.exe` > **Create Shortcut**.
3.  **Move to Startup Folder:**
    * Win+R > `shell:startup` > Drag the shortcut there.
4.  **Reboot and Test.**

---

### 💡 "What if my mouse doesn't work in a game later?"
If you eventually launch a game and find you can't click anything, **that** is when you need Admin privileges.

**The Workaround (Admin without the Prompt):**
Instead of the Startup folder, you create a **Task Scheduler** entry.
1.  Open **Task Scheduler**.
2.  **Create Task**.
3.  **General Tab:**
    * Name: "Sunshine Auto".
    * Check **"Run with highest privileges"**. (This gives Admin without the pop-up).
    * Configure for: **Windows 10**.
4.  **Triggers Tab:**
    * New > **At log on** > Any user.
    * **Delay task for:** 30 seconds (To let the display driver load).
5.  **Actions Tab:**
    * Start a program > Browse to `sunshine.exe`.

**My Advice:** Stick to the simple **Shell:Startup** method first. Only switch to the Task Scheduler method if you actually hit a permission issue in a game.



---
---

BACKUPS

**Do NOT decrease the allocated size (100GB).**

Shrinking the actual "geometry" of a drive (e.g., forcing it from 100GB down to 30GB) is risky, complicated, and often breaks Windows boot partitions.

Instead, you should perform a **"Sparse Backup."**

Unraid virtual disks are "Sparse Files." This means a 100GB file that only has 20GB of data *should* only take up 20GB of physical space on your drive. However, if you copy it incorrectly, it can "inflate" to the full 100GB.

Here is the safer, faster workflow to verify the size and back it up efficiently.

### 1\. Verify the Actual Size

Open the **Unraid Terminal** and check the "Apparent" size vs. the "Actual" size.

```bash
ls -lh /mnt/nvme/system/vm/Windows\ 10/vdisk1.img
# Shows 100G (This is the "Logical" size Windows sees)

du -sh /mnt/nvme/system/vm/Windows\ 10/vdisk1.img
# Shows ~23G (This is the "Physical" space it actually eats on your NVMe)
```

If the second command (`du`) shows \~23GB, you are already efficient\! You don't need to resize anything. You just need to copy it correctly.

### 2\. How to "Sparse Copy" (The Right Way)

When you make your backup, use the `--sparse=always` flag. This tells Linux: "If you see empty space in this file, don't write 0s to the backup drive; just write a 'hole'."

**The Optimized Backup Command:**

```bash
cp --sparse=always /mnt/nvme/system/vm/Windows\ 10/vdisk1.img /mnt/user/isos/vm-backups/win10-master/vdisk1-master.img
```

  * **Result:** Your backup file will also only take up \~23GB on your array, but Windows will still think it has a 100GB drive when you restore it.

### 3\. Future-Proofing: Enable "Discard"

To ensure the file *stays* small as you delete games in the future, make sure your VM settings support "Discard" (TRIM).

1.  **Edit the VM** in Unraid (toggle Advanced View).
2.  Look at your **Primary vDisk**.
3.  **Discard:** Set to **`unmap`**.
4.  **Inside Windows:**
      * Run **Defragment and Optimize Drives**.
      * Select C: drive and click **Optimize**.
      * This forces Windows to tell Unraid: "I deleted these files, you can free up that physical space now."

### Summary

  * **Resize?** **No.** It’s dangerous and unnecessary.
  * **Backup Command:** Use `cp --sparse=always ...`.
  * **Maintenance:** Ensure **Discard='unmap'** is set in Unraid VM settings.

Proceed with the backup using the sparse command\!


```bash
mkdir -p "/mnt/user/backups/vm/win10-master"
cp --sparse=always "/mnt/nvme/system/vm/Windows 10/vdisk1.img" "/mnt/user/backups/vm/win10-master/vdisk1-master.img"
```
