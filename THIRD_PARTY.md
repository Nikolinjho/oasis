# Third-party materials

The MIT license in `LICENSE` applies to original Oasis code and documentation.
It does not relicense third-party materials, artwork, logos, trademarks, or
screenshots of other products. Their respective owners retain their rights.

- **Soon icon:** `app/Resources/Soon/Icon.png` comes from
  [Nikolinjho/Soon](https://github.com/Nikolinjho/Soon), revision `991dac8`.
  See [source information](app/Resources/Soon/SOURCE.md) and the included
  [GNU GPL v2 license](app/Resources/Soon/LICENSE.txt).
- **Codex mark:** `app/Resources/Codex/mark.svg` and its PNG conversion are
  third-party branding. See [source information](app/Resources/Codex/SOURCE.md).
  No MIT license or trademark rights are granted for this mark.
- **Vecteezy artwork:** the `vecteezy_green-palm-trees-on-a-small-island_75263062_939/`
  directory contains third-party source artwork and its original
  `Vecteezy-License-Information.pdf`. These files are excluded from the Oasis
  MIT license.
- **Alcove reference materials:** screenshots, measurements and research about
  Alcove document another product. Alcove branding and artwork belong to their
  respective owners. The local `assets/` and `site/` directories are excluded
  from Git. `app/Scripts/bundle.sh` can optionally include local Alcove sounds
  and a Google Meet icon, as well as an icon from an installed Claude app.
  The Oasis MIT license grants no rights to redistribute those resources.
- **MediaRemote adapter:** the optional build dependency is
  [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
  distributed under its own BSD-3-Clause license. It is downloaded into the
  ignored `app/Vendor/` directory by `app/Scripts/fetch-adapter.sh`.

Product names and trademarks identify the integrations and reference products
only. This project is not affiliated with or endorsed by their owners.
