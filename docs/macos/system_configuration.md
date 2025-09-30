# macOS Configuration Notes

* Disable ***ANNOYING*** bouncing dock icon ([source](https://www.reddit.com/r/MacOS/comments/qsf4nh/does_anyone_else_find_the_bouncing_dock_icon/))

  ```bash
  defaults write com.apple.dock no-bouncing -bool TRUE
  killall Dock
  ```

* Configure Dock autohide delay & animation speed ([source](https://www.reddit.com/r/MacOS/comments/1awf1ts/show_the_dock_faster_when_moving_the_cursor_to/))

  ```bash
  defaults write com.apple.dock autohide-time-modifier -float 0.50
  defaults write com.apple.dock autohide-delay -float 0.00
  killall Dock
  ```

* Show tooltip faster, Change the tooltip delay to 300ms

  ```bash
  defaults write -g NSInitialToolTipDelay -int 300 
  ```

  *Note: Application should be restarted to see the changes*

* Enable key repeat

  ```bash
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  ```

  *Note: Application should be restarted to see the changes*

* Disable system alert sound

  ```bash
  osascript -e 'set volume alert volume 0'
  ```
