# POSsible Recovery — visual redesign brief

Device: Chainway C72, Android 13, 1080×1920 @ ~2.6x (≈411 dp wide). Used standing, one hand, often gloves or glare, hundreds of reads per day. Design for **speed of the repeated loop** (read → SKU → confirm → result) first, beauty second, and they must not fight.

**Skills to invoke before touching code:** `emil-design-eng` (motion decisions, press feedback, easing, durations), `apple-design` (feedback/haptics harmony, typography hierarchy, wayfinding, reduced motion), `redesign-existing-projects` (audit-first: keep behavior, change presentation). Their examples are web/CSS — translate the principles to Flutter as specified below.

**Hard rules:** Do not change business logic, API calls, DB, RFID channel or state-machine semantics. All strings Spanish. Keep all existing tests passing. No new network fonts (offline device). No commits.

---

## 1. Design tokens — create `lib/ui/theme/tokens.dart` and use ONLY these

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const brand = Color(0xFFF08E19);      // possibleOrange 500
  static const brandPressed = Color(0xFFE57F14); // 600
  static const brandSoft = Color(0xFFFFF0E6);  // 50
  static const ink = Color(0xFF212121);        // header / dark chrome
  // Neutrals
  static const bg = Color(0xFFF6F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF6B6B73);
  // Semantic (never reuse brand orange for a status except "Nueva")
  static const created = Color(0xFF16A34A);   // asignada OK
  static const verified = Color(0xFF2563EB);  // verificada
  static const conflict = Color(0xFFDC2626);  // conflicto
  static const pending = Color(0xFFD97706);   // en cola / sin conexión
  static const tagNew = brand;                // etiqueta nueva sin asignar
}

class AppSpace { static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0; }
class AppRadius { static const sm = 10.0, md = 14.0, lg = 20.0, pill = 999.0; }
class AppSize { static const touch = 56.0; static const primaryButton = 64.0; }

class AppMotion {
  static const fast = Duration(milliseconds: 120);  // press feedback
  static const base = Duration(milliseconds: 180);  // state swaps
  static const slow = Duration(milliseconds: 240);  // sheets
  static const easeOut = Cubic(0.23, 1, 0.32, 1);   // strong ease-out (Emil)
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
}
```
Update `ThemeData` (Material 3, `useMaterial3: true`) to derive from these: `scaffoldBackgroundColor: bg`, `ColorScheme.fromSeed(seedColor: brand, primary: brand)` then override `surface`, `onSurface: textPrimary`, `error: conflict`. Filled inputs (`filled: true, fillColor: surface`, radius md, border `border`, focused border brand 2px). ElevatedButton: height 64, radius md, brand bg, white 18sp w600 text. Remove every hard-coded color/size literal from screens in favor of tokens.

## 2. Typography (system Roboto — no custom font)
- `display` (SKU on confirm/result): 36sp, w700, letterSpacing −0.5, height 1.1.
- `title`: 22sp w600 −0.2; `body`: 16sp w400 0 / 1.4; `label`: 13sp w600 +0.4 uppercase (section labels only).
- EPC: `fontFamily: 'monospace'`, 17sp, `fontFeatures: [FontFeature.tabularFigures()]`, **grouped in blocks of 4 separated by thin spaces** (`3093 73E1 67B0 610B DCE4 3394`); never wrap mid-block; for 32-char EPC show 2 lines of 4 blocks.
- Numbers in counters use tabular figures.
- Respect the system text scale (use `MediaQuery.textScalerOf`), never fixed heights that clip text.

## 3. Motion & feedback (Emil + Apple)
- This loop runs hundreds of times a day ⇒ **no decorative animation**. Only: press feedback, state-to-state swaps, result arrival.
- `PressableScale` widget (create `lib/ui/widgets/pressable_scale.dart`): scales child to 0.97 on pointer-down (not on tap-up) in `AppMotion.fast` with `AppMotion.easeOut`, back on up/cancel. Wrap every primary/secondary button, suggestion row and chip.
- State swaps in the scan screen: one `AnimatedSwitcher` (duration `base`, `switchInCurve: easeOut`, `switchOutCurve: easeOut`, reverse faster: 120ms) with fade + 8 dp upward slide for entering; never scale from 0.
- Result arrival: background tint + icon scale from 0.9→1.0 with opacity, 180ms, easeOut. Haptic + sound fire **in the same frame** the result widget is built (call feedback in the same `setState` tick), matching character: created = `mediumImpact` + click; verified = `selectionClick`; conflict = `heavyImpact` twice 120ms apart; queued/error = `lightImpact`.
- Reading (≈1 s burst): the primary button turns into a determinate `LinearProgressIndicator` filling over the burst duration inside the button + text "Leyendo…". No spinners, no looping pulses.
- Reduced motion: if `MediaQuery.of(context).disableAnimations`, replace slides/scales with 120ms opacity fades only.

## 4. Screen by screen

### Header (all authenticated screens)
- `AppBar` bg `ink`, height 64, **logo `RECOVERY_DARK_TIGHT.png` height 28, left aligned** (not centered), no title text.
- Actions (48 dp targets): queue icon **with a badge** showing pending count (hidden when 0), sync, settings.
- Below header, replace the 4 big counters with one compact **session strip** (height 44, bg surface, bottom border): four inline stats `● 12 Asignadas  ● 3 Verificadas  ● 0 Conflictos  ● 1 Pendiente` with a 8 dp colored dot each, tabular figures, 14sp; tapping it opens the queue.

### Scan — idle
- Content vertically centered in the remaining space: small RFID illustration (72 dp, brand color at 60% opacity), title "Acercá el colector a la etiqueta", body secondary "Apretá el gatillo o el botón".
- **Primary button anchored at the bottom** (thumb zone), full width minus 16 dp margins, 64 dp: icon + "Leer etiqueta". Safe-area aware.

### Scan — tag read (card at top, action at bottom)
- **Tag card** (surface, radius lg, 1px border): label "EPC", grouped EPC (see §2), and a **status pill** on the top-right: `Nueva` (tagNew on brandSoft), `Asignada` (verified tint), with an icon.
- If assigned: show "AF-012917 · Teléfono IP · asignada por Juan el 26/9" as a second row.
- Ambiguous read / no tag: inline card in `pending` tint with the message and the bottom button becomes "Reintentar".

### Scan — SKU input (most time is spent here: optimize)
- Input: large (24sp), **fixed prefix "AF-"** shown as `prefixText`, keyboard `TextInputType.number` so the operator types only digits. Hardware QR scanner (keyboard wedge) still works: on submit/paste, run `parseSku` on the full raw text (URL or `AF-…`).
- Camera button as a 56×56 square (radius md, brandSoft bg, brand icon) to the right of the input.
- **Suggestions must stay visible above the keyboard**: when the input gains focus, scroll so the tag card collapses to a one-line chip (EPC last 8 chars + pill) and the input sits right under the session strip; suggestion list renders between input and keyboard, max 4 rows visible, each row 64 dp: SKU bold 18sp tabular, description 14sp secondary single-line ellipsis, location with pin icon 13sp; exact match row highlighted with brandSoft background and a "Coincidencia exacta" micro-label. Tap → confirm.
- Bottom: secondary text button "Cancelar · otra etiqueta".

### Scan — confirm (modal bottom sheet, not a new page)
- `showModalBottomSheet` with drag handle, radius lg top corners, dim scrim, enters from bottom (240ms easeOut) and exits the same way (spatial consistency).
- Content: label "Asignar etiqueta a", SKU in `display` style, description `title`, location row with pin, divider, small EPC grouped. Buttons: primary "Asignar" (64 dp, brand) and text button "Cambiar SKU". If the SKU is not in the local catalog: amber inline warning + primary becomes "Enviar igual".

### Scan — result (replaces card area; auto-return)
- Full-width card tinted with the semantic color at 10% + 2px left bar of the solid color, 56 dp icon, title (`title`): "Etiqueta asignada" / "Etiqueta verificada" / "Conflicto" / "Guardada sin conexión" / "Error", then the SKU in bold and one line of detail. Conflict shows "Esta etiqueta pertenece a AF-xxxxx · descripción".
- created/verified/queued: auto-return to idle after 1.5 s with a thin countdown bar at the bottom of the card; tapping anywhere or pulling the trigger returns immediately. Conflict/error: stay until "Entendido" is pressed.

### Login (keep it light; logo SMALL)
- Background `bg`. Logo `RECOVERY.png` **max width 180 dp**, top padding 48 dp. Under it a single line 14sp secondary "Re-asociación de etiquetas RFID" (remove the orange pill).
- Fields: email, password (56 dp filled). **Server host collapsed**: a row "Servidor: 127.0.0.1:8001 · Cambiar" that expands the host field (advanced option one level deeper).
- Primary "Iniciar sesión" 64 dp; inline error text under the fields (not snackbar) on 401/400.

### Sync
- Card with big tabular number, subtitle "productos en el colector", last sync relative ("hace 5 min"). During sync: determinate progress if total known, else indeterminate linear bar inside the card + "Descargando catálogo…". On success auto-continue to scan after 800 ms.

### Queue (Cola offline)
- Segmented control: `Pendientes (n)` / `Enviadas`. Rows 64 dp: colored 8 dp status dot, SKU bold, grouped EPC (last 3 blocks) secondary, relative time right-aligned. Empty state: icon + "No hay nada pendiente". Primary "Reintentar envío" bottom-anchored only when pending > 0.

### Settings
- Grouped sections with `label` headers. RFID power: 3 preset chips `Corto 5 · Normal 10 · Largo 20 dBm` + slider for fine tuning showing live value. "Margen de ambigüedad" inside an "Avanzado" `ExpansionTile`. Device ID in monospace with copy button. "Cerrar sesión" as a destructive text button at the bottom with confirmation dialog.

## 5. Code structure
`scan_screen.dart` is 1,150 lines — split presentation into focused widgets in `lib/ui/widgets/`: `session_strip.dart`, `tag_card.dart`, `epc_text.dart` (grouping), `sku_input.dart`, `suggestion_list.dart`, `confirm_sheet.dart`, `result_card.dart`, `primary_action_bar.dart`, `pressable_scale.dart`, `status_pill.dart`. Keep state in the screen; widgets are stateless where possible. Add widget tests for `epc_text` grouping (24 and 32 chars) and `status_pill` colors.

## 6. Done when
`flutter analyze` clean, `flutter test` green, `flutter build apk --release` OK. Report in 2–3 lines. Do not install on the device.
