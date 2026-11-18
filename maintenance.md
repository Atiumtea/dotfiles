## NVIDIA-драйверы в Flatpak

NixOS и Flatpak обслуживают графические драйверы независимо друг от друга.

После обновления NVIDIA в NixOS нужно обновить и два Flatpak-расширения:
- `org.freedesktop.Platform.GL.nvidia-*` — 64-битные библиотеки.
- `org.freedesktop.Platform.GL32.nvidia-*` — 32-битные библиотеки (важно для Wine-игр).

Версия расширений должна совпадать с системным драйвером. Иначе приложения Flatpak могут использовать Mesa/Nouveau вместо проприетарного NVIDIA-драйвера. В результате игры могут сильно тормозить.

**Проверка и установка актуальных расширений:**

```bash
driver="$(tr '.' '-' < /sys/module/nvidia/version)"

flatpak install --system flathub \
  "org.freedesktop.Platform.GL.nvidia-${driver}//1.4" \
  "org.freedesktop.Platform.GL32.nvidia-${driver}//1.4"
```

После установки проверить наличие обоих расширений, перезапустить приложения и удалить старые версии.

Расширениями управлять через Flatpak, не закреплять их версии во flake: они должны соответствовать текущему системному драйверу.