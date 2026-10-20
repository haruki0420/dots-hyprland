# Face unlock

Face unlock is optional and disabled by default. It applies to the Quickshell
lock screen, not Hyprlock, the login greeter, `sudo`, or disk encryption.

1. Install and configure [Howdy](https://github.com/boltgolt/howdy) for your IR
   camera, enroll your own face, and verify recognition. On Arch, see the
   [Howdy guide](https://wiki.archlinux.org/title/Howdy). Prefer a persistent
   `/dev/v4l/by-path/` device name. Keep Howdy's password/input workaround off
   (`[core] workaround = off`): this service only authenticates faces.
2. As an administrator, create `/etc/pam.d/quickshell-face`:

   ```pam
   #%PAM-1.0
   auth [success=done default=die] pam_howdy.so
   ```

   This example requires Howdy's compiled PAM module. Confirm its installed
   path for your distribution. Only a successful face match may authenticate;
   do not add `pam_permit.so` or a password fallback to this dedicated service.
   Keep the existing password PAM service unchanged.
3. The desktop user must be able to open the IR camera and read their enrolled
   model. Keep the model and PAM service owned by root and not user-writable.
   If needed, grant that user read access to their model using an ACL rather
   than making all enrolled models world-readable.
4. To register faces from the settings GUI, install the optional helper as a
   root-owned copy from the repository (do not symlink it into your checkout):

   ```sh
   sudo install -Dm755 sdata/optional/face-unlock/end4-face-enroll /usr/local/libexec/end4-face-enroll
   ```

   This Arch-layout helper uses `/usr/bin/howdy` and `/etc/howdy/models`.
   It accepts only a label, gets the account from `PKEXEC_UID`, and grants only
   that user read access to the root-owned model. **Manage registered faces** in the
   settings opens an unprivileged dialog with names, registration dates and IDs.
   Only metadata is displayed, and opening or refreshing the list needs no
   administrator authentication; administrator authentication applies
   only to the enrollment operation. UPower, `gdbus`, `pkexec`, and `setfacl`
   must be installed. Neither the desktop shell nor the settings GUI runs as root.
5. Enable **Unlock with face authentication** in Settings → Interface → Lock screen →
   Security, or set `lock.security.faceUnlockOnResume` to `true` in
   `~/.config/illogical-impulse/config.json`. Leave `lock.useHyprlock` disabled.
6. The supplied `hypridle.conf` dispatches `quickshell:lockResume` after suspend.
   If you maintain a custom `after_sleep_cmd`, preserve its existing commands
   and add:

   ```sh
   hyprctl dispatch 'hl.dsp.global("quickshell:lockResume")'
   ```

   The equivalent shell IPC is `qs -c ii ipc call lock resume`. It only attempts
   authentication when the screen is already locked. Entering the Quickshell
   lock screen also starts one attempt, including a configured startup lock.
   An unlocked desktop never starts the camera.

On lock entry or after resume, the shell waits 1.5 seconds for the camera and makes one attempt.
Typing, submitting a password, selecting a power action, or leaving the lock
screen cancels it. A closed lid (including clamshell mode) prevents camera
authentication, and closing the lid during an attempt cancels it. The shell
fails closed if the lid state is unknown or UPower disconnects. Enrollment is
also blocked or stopped while the lid is closed. Missing hardware, an unavailable PAM service, a timeout, or
a failed match leaves password unlock available. A ten-second watchdog stops
an unresponsive PAM conversation; there is no automatic retry loop.

Face authentication cannot supply the password needed to unlock an encrypted
keyring. A keyring already unlocked before suspend remains usable; otherwise
enter its password separately. Howdy's upstream warns that face authentication
can be fooled by similar faces or photos. Keep a password available and assess
whether this convenience is appropriate for your device.

## Verification

Run `tests/face-unlock/run.sh` from the repository. The Qt tests exercise the
production component with a simulated PAM conversation; they do not open the
camera or lock the desktop. Also test on the target machine:

`tests/face-unlock/check-settings.sh` additionally checks the actual settings
entrypoint's dynamic page and enrollment-dialog loading in a hidden native
window. It requires a running Wayland session and does not enroll or authenticate.

- Suspend while locked, resume, and verify that an enrolled face unlocks.
- Cover the camera and verify that password unlock still works.
- Type immediately after resume and verify that face authentication stops.
- Repeat suspend/resume while the screen is already locked.
- Verify that manual locking starts one face authentication attempt.
- Close the lid and verify that neither locking nor resume opens the camera.
- Open the registration dialog and verify the saved labels, dates and IDs.
- Verify that face recognition cannot approve password-protected power actions.
