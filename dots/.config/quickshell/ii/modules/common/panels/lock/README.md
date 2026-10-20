# Face unlock after suspend

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
4. Enable **Face unlock after suspend** in Settings → Interface → Lock screen →
   Security, or set `lock.security.faceUnlockOnResume` to `true` in
   `~/.config/illogical-impulse/config.json`. Leave `lock.useHyprlock` disabled.
5. The supplied `hypridle.conf` dispatches `quickshell:lockResume` after suspend.
   If you maintain a custom `after_sleep_cmd`, preserve its existing commands
   and add:

   ```sh
   hyprctl dispatch 'hl.dsp.global("quickshell:lockResume")'
   ```

   The equivalent shell IPC is `qs -c ii ipc call lock resume`. It only attempts
   authentication when the screen is already locked. Manual locking and shell
   startup do not start the camera.

After resume, the shell waits 1.5 seconds for the camera and makes one attempt.
Typing, submitting a password, selecting a power action, or leaving the lock
screen cancels it. Missing hardware, an unavailable PAM service, a timeout, or
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

- Suspend while locked, resume, and verify that an enrolled face unlocks.
- Cover the camera and verify that password unlock still works.
- Type immediately after resume and verify that face authentication stops.
- Repeat suspend/resume while the screen is already locked.
- Verify that manual locking does not start face authentication.
- Verify that face recognition cannot approve password-protected power actions.
