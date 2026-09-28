# Main navigation UI

The persistent navigation uses the approved PNG artwork for Collection, Display, Shop,
Goals and Shelves. The shared configuration in `src/client/NavigationConfig.luau` owns
ordering, labels, semantic asset keys and the small per-image scale adjustments.
`NavigationButton.luau` owns the common hover, press, selection and badge behavior. Page
routing remains in `Interface.luau`.

Desktop uses a left rail inside the existing 144-pixel UI safe area. Touch and compact
layouts use a five-item bottom bar inside the existing 76-pixel safe area. The current
daily reward state drives the Goals dot; `Navigation.badge(id, value)` also accepts an
empty string for a dot, text for a short count, or `nil` to clear a badge.

## Missing-image diagnosis

The five source files are present and pass local PNG validation. Rojo maps the Luau
configuration into `ReplicatedStorage`, but it does not upload arbitrary PNG files as
Roblox cloud assets. None of the five `Navigation.*` semantic keys currently has an entry
in generated `src/shared/AssetIds.luau`, so `AssetManifest.resolve()` returns an empty
string. That empty string reaches both navigation `ImageLabel.Image` properties and is the
reason no artwork renders.

The runtime hierarchy itself is valid: each button creates its icon `ImageLabel`, sets
`ImageTransparency` to `0`, uses `ScaleType.Fit`, gives it a nonzero square size, and
places it at ZIndex 10 above the ZIndex 8 button surface. The navigation, surface, icon
stage and artwork frames do not clip descendants. Opening and closing a page only toggles
the navigation root's visibility and does not remove or recreate the images.

## Manual Roblox image import

Upload these five files as **Image** assets under the same user or group that owns the
experience:

| Navigation item | File |
| --- | --- |
| Collection | `assets/ui/navigation/collection_navigation_icon.png` |
| Display | `assets/ui/navigation/display_navigation_icon.png` |
| Shop | `assets/ui/navigation/shop_navigation_icon.png` |
| Goals | `assets/ui/navigation/goals_navigation_icon.png` |
| Shelves | `assets/ui/navigation/shelves_navigation_icon.png` |

In Roblox Studio, open the target experience, choose **View > Asset Manager**, select the
**Images** category, click **Import**, and select all five PNGs. If Asset Manager is not
available, publish the experience first. Wait for moderation; images still under review do
not render to players.

To copy each ID in Creator Hub, open **Creations > Development Items**, choose the image
category, find the imported item, open its overflow menu, and choose **Copy Asset ID**.
Do not use the experience thumbnail ID, a decal from another owner, or a local file path.
Private assets must be owned by or permitted for the experience that loads them.

Paste the five numeric IDs, without the `rbxassetid://` prefix, into the matching fields in
`src/shared/NavigationAssetIds.luau`:

```luau
local ids: { [string]: string } = {
	Collection = "123...",
	Display = "123...",
	Shop = "123...",
	Goals = "123...",
	Shelves = "123...",
}
```

That module validates numeric values and adds `rbxassetid://` centrally. Empty or invalid
values do not resolve to placeholders. The existing generated asset pipeline remains the
fallback, so a later successful `scripts/upload_assets.py` run can populate the same five
semantic assets without scattering IDs through UI code.

After adding the IDs, sync with Rojo, restart Play so the shared module is reloaded, and
test all five images in desktop and device-emulation layouts. Check Studio Output for
permission or moderation failures. The navigation emits one clear warning per missing ID
when it is constructed.
