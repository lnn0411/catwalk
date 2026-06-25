Rewrite CatCard.tscn and CatCard.gd for better UI feel.

Current files:
- scenes/ui/CatCard.tscn (current)
- scenes/ui/CatCard.gd (current)

## Design Goals

The card looks flat, boxes have no rounded corners, spacing is tight, animations are basic, buttons lack press feedback. Need to polish it like a real production game UI.

## SPEC: CatCard UI Polish

### CardPanel
- Replace ColorRect with Panel (supports StyleBoxFlat for rounded corners + shadow)
- style: bg color #3C2A1C, corner radius top=24px (bottom=0 since it's anchored to screen bottom), shadow
- Size: anchors_preset=12 (bottom anchor), offset_top=-520 (slightly shorter than current -640)

### Cat Display (TextureRect)
- Position: centered top of card, offset_left=160, offset_top=20, offset_right=-160, offset_bottom=250
- Add a thin subtle border/outline (ColorRect behind it, 2px padding, #5C4A3A color, rounded corners 12px)
- Cat centering/stretch: KEEP_CENTERED

### Info Row
- offset_top=270, offset_bottom=310
- CatName: font_size=24, weight=Bold, white
- BreedRarityLabel: font_size=14, color #B8A088 (tan/gold for rarity feel)

### Button Row
- offset_left=20, offset_top=326, offset_right=-20, offset_bottom=386
- separation=10
- Each button size: custom_minimum_size = Vector2(0, 52)
- StyleBoxFlat for buttons: bg=#5C4A3A, corner=12px. Hover=#6D5A48. Press/darken
- Disabled: bg=#2C2218, text=#665544
- Active/interactable: text white
- Font size 16-17

### Status Label
- offset_top=396 to 426
- font_size=13, color #B8A088
- left-aligned, not center
- Icon emoji before text

### Animations (all in gd)

_play_open_animation():
- Scale from 0.8 to 1.0 (not from zero - that looks cheap)
- Fade in from alpha 0 to 1
- Use TRANS_BOUNCE with EASE_OUT
- Duration 0.3s
- The Overlay (semi-transparent top part) should fade in separately (staggered, 0.05s delay)

_play_close_animation():
- Scale to 0.9 + alpha to 0
- Duration 0.15s
- Overlay fades out too

Button press:
- Connect to each button: on button_down, tween scale to 0.95 (0.05s). on button_up, tween back to 1.0 (0.1s)
- This gives tactile feedback

### Layout Structure

CatCard (Control, full rect, mouse_filter=IGNORE)
├── Overlay (ColorRect, top half, anchor_bottom=1.0 offset_bottom=-520, color black 0.35, mouse_filter=STOP)
├── CardPanel (Panel, bottom portion: anchors_preset=12, anchor_top=1.0, offset_top=-520, full width)
│   ├── CatDisplayBg (ColorRect, offset: 155, 16, -155, 254, color #5C4A3A)
│   ├── CatDisplay (TextureRect, offset: 158, 18, -158, 252, unique)
│   ├── InfoRow (HBoxContainer, offset: 24, 268, -24, 308)
│   │   ├── CatName (Label, unique)
│   │   └── BreedRarityLabel (Label, unique)
│   ├── ButtonRow (HBoxContainer, offset: 20, 322, -20, 382)
│   │   ├── FeedButton (Button, unique)
│   │   ├── PetButton (Button, unique)
│   │   ├── PlayButton (Button, unique)
│   │   └── ExploreButton (Button, unique)
│   ├── StatusLabel (Label, offset: 24, 392, -24, 420, unique)
│   └── ExploreStatePanel (VBoxContainer, offset: 24, 320, -24, 380, visible=false, unique)
│       ├── ExploringLabel (Label, unique)
│       ├── CountdownLabel (Label, unique)
│       └── ReturnTimeLabel (Label, unique)

### @onready references (must match unique names)
- %CardPanel (the Panel)
- %CatDisplay (TextureRect)  
- %CatName
- %BreedRarityLabel
- %FeedButton, %PetButton, %PlayButton, %ExploreButton
- %StatusLabel
- %ExploreStatePanel, %ExploringLabel, %CountdownLabel, %ReturnTimeLabel

IMPORTANT: Keep ALL existing game logic exactly as-is (_on_feed_pressed, _on_pet_pressed, _on_play_pressed, _on_explore_button_pressed, _do_interaction, _show_feedback, cooldowns, explore state, relinquish, etc). Only change visual/UI/animation code.

For button styling: use theme_override_styleboxes in _ready or _apply_theme. Create StyleBoxFlat objects in code since Godot Godot tscn can't define them inline.
- Normal: bg=#5C4A3A, corner_radius=12
- Hover: bg=#6D5A48, corner_radius=12
- Pressed: bg=#4A3A2C, corner_radius=12
- Disabled: bg=#2C2218, corner_radius=12

For the CardPanel (Panel node): use theme_override or create StyleBoxFlat with:
- bg_color=#3C2A1C
- corner_radius_top_left=24, corner_radius_top_right=24 (top rounded, bottom flat)
- shadow_size=8, shadow_color=rgba(0,0,0,0.3)
