# CheatSheet — Spanish App Store Connect Metadata

This is metadata copy for App Store Connect, not app code. Nothing here is
consumed by the build; add it manually under the app's "Spanish" localization
in App Store Connect > App Information / App Store tab. Apple offers **Spanish
(Mexico)** and **Spanish (Spain)** as separate metadata locales (there is no
generic "Spanish" or "es-419" option at the App Store Connect metadata level,
unlike the app binary's own runtime `es` resource, which does serve every
Spanish-preferring region generically).

**Recommendation:** add only **Spanish (Mexico)** for now. It is the most
broadly understood choice across Latin American storefronts, and the app has
no region-specific content or vocabulary that would justify maintaining a
second, separately-tuned Spain listing. Add Spanish (Spain) later only if you
want Spain-specific store-listing copy — the runtime app UI itself doesn't
need it either way, since it already ships one neutral `es` translation that
covers both.

## App Name

Keep **CheatSheet** — brand names are not translated.

## Subtitle (30 characters max)

```
Notas y comandos a mano
```
(23 characters. "Notes and commands at hand" — mirrors the README's own
framing of the product.)

## Promotional text (170 characters max, editable anytime without review)

```
Notas breves, comandos y listas de tareas siempre a mano, con widget para
macOS, iOS y iPadOS. Sin cuentas, sin anuncios, sin conexión necesaria.
```

## Description (4000 characters max)

```
CheatSheet es una app de código abierto para macOS, iOS y iPadOS que te
permite guardar notas breves, listas de tareas y comandos que usas todos los
días, siempre a mano.

Con CheatSheet puedes:
• Crear y editar notas breves en texto sencillo.
• Buscar en los títulos y el contenido de tus notas.
• Ver títulos, viñetas y elementos de una lista (pendientes o completados) en
  las vistas previas y en el widget.
• Elegir entre diez colores y cuatro estilos de fuente para cada nota.
• Fijar una nota para mostrarla en el widget de macOS, iOS y iPadOS, en
  tamaño pequeño, mediano o grande.
• Mover notas a la papelera, restaurarlas, eliminarlas de inmediato o dejar
  que se eliminen automáticamente después de 30 días.
• Capturar una nota y abrir las más recientes desde la barra de menús en
  macOS.
• Usar una navegación adaptable: diseño compacto en iPhone y vista dividida
  en iPad y Mac.

CheatSheet guarda tus notas solo en tu dispositivo mediante SwiftData y un
grupo de aplicaciones compartido. No se necesita cuenta ni conexión a
internet, y la app no incluye analítica, publicidad ni servicios de terceros.

Ligera, nativa y pensada para que anotar o consultar algo sea instantáneo.
```

## Keywords (100 characters max, comma-separated, no spaces needed)

```
notas,apuntes,lista,comandos,recordatorio,checklist,git,widget,productividad,codigo
```
(Omit words already in the app name/subtitle per ASO convention; adjust if
the English keyword set is finalized differently and you want closer parity.)

## What's New / release notes (this release)

```
CheatSheet ya está disponible en español. También incluye mejoras generales
de estabilidad.
```

## App Privacy ("Nutrition Label")

This is a questionnaire in App Store Connect, not free text you translate —
Apple renders the resulting labels in the storefront's language automatically.
No action needed beyond keeping the existing "no data collected" answers
accurate (matches `PrivacyInfo.xcprivacy` and `PRIVACY.md`).

## Support / Marketing / Privacy Policy URLs

These fields accept one URL regardless of storefront language; the existing
English URLs (`https://github.com/weskcode/cheatsheet/issues`, etc.) work as-is
for the Spanish listing. If you want the linked privacy policy page itself to
read in Spanish for Spanish-speaking users, that means translating
`PRIVACY.md` (or adding `PRIVACY.es.md` and linking both) — optional polish,
not an App Store requirement. It's a short document; flagging it here as a
reasonable follow-up rather than doing it unprompted, since it's a public repo
doc rather than app-bundled content.

## Screenshots

App Store Connect lets a Spanish (Mexico) localization reuse the same
screenshot images as English if you don't want to caption them separately —
none of this app's screenshots contain burned-in English text per the
existing `Docs/Images/*.png` captures, so no new captures are required purely
for the Spanish listing. Only recapture if you later add Spanish caption
overlays via the `app-store-screenshots` skill.
