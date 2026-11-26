# Chameleon96 de Aitor: estado del HDMI

Referencia sobre el estado de esta placa y sobre lo que necesita un core
para dar imagen HDMI en ella. Recoge solo hechos comprobados; lo que aún no se
sabe está en "Preguntas abiertas".

## Resumen

- El fPLL **FRACTIONALPLL_X0_Y1_N0** de la FPGA de esta placa está muerto. Ahí es
  donde todos los cores colocan `pll_hdmi`, así que con las builds estándar
  no hay imagen HDMI.
- Configuración que funciona con todos los modos HDMI probados (640x480,
  800x600, 1024x768, 720p y 1080p; 1280x1024 sin confirmar):
  - **FPGA**: `pll_hdmi` en `FRACTIONALPLL_X89_Y1_N0` con su contador de salida
    fijado en `PLLOUTPUTCOUNTER_X89_Y5_N1`. Reconfiguración activa y valor de C
    escrito en los 18 contadores del bloque. Sin el mux `hdmi_clk_sw`. Ningún
    otro PLL en X89_Y1 ni en X0_Y1.
  - **Main_MiSTer**: TDA19988 en modo SYNC_HS, con la polaridad aplicada a la
    salida del TBG y la AVI InfoFrame corregida para los modos sin VIC (binario
    `MiSTer.synchs_pol`).
- Hoy la tiene el Menu (`menu_reconf_bcast.rbf`) y el PCXT `PCXT_reconf_fixpll.rbf`
  (probado en la placa el 26/11/2026: todo funciona). En el repositorio, los
  cambios de FPGA están directamente en la revisión estándar `PCXT_ch96` de la
  rama `ch96-placa-aitor` (sin revisión `PCXT_ch96_fixpll` ni macro
  `MISTER_CH96_FIXPLL`), y el parche de Main en `platform/ch96/main/`. Los demás
  cores fixpll (PCXT anteriores, PCAT) dejan `pll_hdmi` fijo a 74,25 MHz: solo
  sirven en 720p.

## La avería

- Empezó el 23/11/2026, entre las 07:45 y las 14:44. Desde entonces ningún core
  estándar da imagen HDMI, con cualquier tarjeta, monitor, cable o
  resolución. Otras Chameleon96 funcionan con las mismas builds.
- La imagen de fábrica de Arrow sigue dando 720p. El TDA19988, el conector y el
  cable están bien.
- Linux y Main arrancan con normalidad. El TDA19988 responde en i2c-2 (0x37/0x73,
  rev 0x0301), con HPD y RXSENS en alto. El timeout de DDC al leer el EDID es un
  defecto conocido del port, no tiene que ver con esto.
- La avería está dentro de la FPGA: los demás fPLL del lado izquierdo, con la misma
  alimentación, funcionan. No tiene reparación. Medir las tensiones de la FPGA
  (1,1 V núcleo, 2,5 V aux/PLL, E/S, DDR3) solo serviría para buscar la causa.

## Sitios de fPLL de la FPGA (5CSEBA6)

El fitter acepta seis sitios:

| Sitio | Estado en esta placa | Uso en las builds que funcionan |
|---|---|---|
| X0_Y1 | **muerto** | ninguno |
| X0_Y15 | funciona | `pll_audio` |
| X0_Y32 | funciona | `pll_hdmi` en las builds fixpll de 720p fijo |
| X0_Y56 | funciona | PLL del core (`emu|pll`) |
| X0_Y74 | funciona | `pll_system` en `PCXT_reconf_fixpll` y en la rama `ch96-placa-aitor` |
| X89_Y1 | funciona | `pll_hdmi` reconfigurable |

Contadores de salida que asigna el fitter:

| PLL | Contadores |
|---|---|
| X0_Y1 (pll_hdmi estándar) | X0_Y5_N1 (fijado en el qsf; índice físico 5) |
| X0_Y15 (pll_audio) | X0_Y19_N1 / X0_Y20_N1 |
| X0_Y32 (pll_hdmi fixpll) | X0_Y31_N1 (Menu), X0_Y32_N1 (PCXT) |
| X0_Y56 (PLL del core) | X0_Y60_N1, X0_Y61_N1, X0_Y62_N1 |
| X89_Y1 (pll_hdmi reconfigurable) | X89_Y5_N1 (fijado en el qsf; en el PCXT, en `files.qip`) |

## Lado FPGA: cómo se ajusta el reloj de píxel HDMI

- `pll_hdmi` arranca con su configuración compilada: en Chameleon96, 74,25 MHz
  (720p60), VCO 445,5 MHz, M=8, N=1, C=6 (hi 3 / lo 3). Es un PLL de tipo
  "Reconfigurable" con `reconfig_to_pll`/`reconfig_from_pll`.
- Main_MiSTer lo reprograma para cada modo a través de `sys/pll_cfg/pll_cfg_hdmi.v`
  (versión recortada de `altera_pll_reconfig`): registro 4 = M, 3 = N,
  7 = K (fraccional), 5 = C.
- M, N y K son del propio PLL: esas escrituras funcionan esté donde esté el PLL.
- C es distinto. Main solo escribe el divisor, y los bits de selección de contador
  [22:18] van a 0. El `pll_cfg_hdmi.v` original siempre programa el **contador
  físico 5** del bloque (`c_cnt_changed[5]`, bucles desde `i = 5`). Para X0_Y1 ese
  índice es X0_Y5_N1. Para cualquier otro sitio, el contador de `pll_hdmi` no tiene
  por qué ser el índice 5, y la escritura de C se pierde.
- Para el fPLL de arriba de una pareja, la tabla `fpll_1` de `pll_cfg_hdmi.v`
  invierte el número de contador (5 pasa a ser 17-5 = 12).
- El Main de teiram (`video.cpp`, `findPLLpar`, `#ifdef CHAMELEON96`) nunca baja C
  de 6 y lo deja siempre par:
  - 720p60 (74,25 MHz) y 1080p60 (148,5 MHz): C=6, solo cambian M y K.
  - 1024x768@60 (65 MHz) y 1280x1024@60 (108 MHz): C=8.
  - 640x480 y 800x600 necesitan C mayor que 6.

### Cambios necesarios en la FPGA (rama `ch96-placa-aitor`)

1. **`pll_hdmi` en X89_Y1**, con `counter[0].output_counter` fijado en
   `PLLOUTPUTCOUNTER_X89_Y5_N1`.
2. **Reconfiguración activa**: `pll_cfg_hdmi` conectado con `mgmt_write(cfg_write)`
   (no atado a 0).
3. **C escrito en los 18 contadores**: en `pll_cfg_hdmi.v`, siempre (sin macro),
   `number_of_counters = 18`, bucles desde `i = 0` y `c_cnt_changed <= 18'h3FFFF`.
   El original solo escribe el contador 5. Por eso **ningún otro
   PLL puede usar contadores del bloque X89_Y1**. Que 640x480 y 800x600 (C > 6)
   funcionen demuestra que la escritura de C llega al PLL.
4. **Sin `hdmi_clk_sw`**: `assign hdmi_tx_clk = hdmi_clk_out`. El mux
   `cyclonev_clkselect` obliga a colocar juntos los PLL que lo alimentan, y eso
   arrastra los PLL a X0_Y1. Consecuencia: **no hay direct_video por HDMI**.
5. **Nada en X0_Y1**: todos los PLL fijados (en el Menu: emu X0_Y56, audio
   X0_Y15; en el PCXT, en `files.qip`: emu X0_Y56, audio X0_Y15, `pll_system`
   X0_Y74).

Referencia: diff de `Menu_reconf_bcast` frente a `Menu_fixpll` en WSL
(`~/ch96test/menu_bcast.diff` y `~/ch96test/patch_bcast.py` para `pll_cfg_hdmi.v`).

### Builds fixpll de 720p fijo

Las builds fixpll anteriores (`PCXT_splash_fixpll`, de la revisión
`PCXT_ch96_fixpll` ya retirada, y la del PCAT) ponen `pll_hdmi` en
X0_Y32 con `mgmt_write` a 0 y sin `hdmi_clk_sw`. Dan 720p, pero el reloj de píxel
no cambia nunca. Con un `video_mode` distinto de 720p, Main manda los tiempos del
modo nuevo con un reloj de 74,25 MHz: el monitor pierde la señal y el pincho
HDMI-USB, que acepta casi cualquier cosa, sigue mostrando imagen.

## Lado Main_MiSTer: configuración del TDA19988

Main programa el TDA19988 en `tda_config_set_mode` (`video.cpp`). Con el Main
original de teiram (d9799de), que usa el modo SYNC_DE, en esta placa solo salían
en el monitor los modos predefinidos con VIC CEA (720p VIC 4, 1080p VIC 16). Los
modos con VIC 0 (1024x768, 1280x1024, modelines) se quedaban sin señal en el
monitor, incluso un modeline idéntico a 1080p.

El binario que funciona con todos los modos (`MiSTer.synchs_pol`, parche
`platform/ch96/main/0003-tda19988-synchs-pol-avi.patch` sobre ese Main, con
instrucciones de compilación en `platform/ch96/main/README.md`) cambia:

- **SYNC_HS** (`VIP_CNTRL_3` = 0x20, sin invertir la entrada), como los drivers de
  Linux (tda998x) y u-boot: el TBG se engancha a los flancos de HS/VS y regenera
  DE con `DE_START` = htotal - hact y `DE_STOP` = htotal. No usa el pin DE.
- **Polaridad en la salida del TBG**: `TBG_CNTRL_1` = TGL_EN, más H_TGL si
  `hpol` = 0 y V_TGL si `vpol` = 0. La FPGA siempre entrega HS/VS activos en alto
  al TDA. Es lo mismo que hacen los cores estándar con el ADV7513 (DE10-Nano). Si se invierte
  la entrada (lo que hacía `MiSTer.synchs_avi`), el TBG se engancha al flanco
  equivocado y la imagen sale partida, con el borrado horizontal en mitad de la
  pantalla.
- **`VIDFORMAT` = 0x00** siempre, con la temporización completa programada.
- **AVI InfoFrame para VIC 0**: DB1 = 0x10 y DB2 = 0x08 (aspecto "sin datos"). Con
  VIC CEA queda como antes (DB2 = 0x20, 16:9).

Main imprime `TDA19988: AVI VIC=… DB1=… DB2=…` con cada cambio de modo
(`debug=1`).

Otros binarios en `main_avi/`: `MiSTer.stock_avi` (Main original más el cambio de la
AVI: los modos VIC 0 siguen sin señal) y `MiSTer.synchs_avi` (SYNC_HS más el cambio
de la AVI, sin el ajuste de polaridad).

### Notas sobre la captura

- El pincho HDMI-USB ("USB Video") se lee en el PC con
  `ffmpeg -f dshow -i "video=USB Video" -frames:v 1` y siempre entrega 1920x1080
  escalado.
- Muestra desplazamientos de imagen y de OSD que el monitor no tiene. Para saber si
  un modo funciona, lo que cuenta es el monitor.

## Estado de la tarjeta SD (F:)

| Fichero | Contenido |
|---|---|
| `F:\MiSTer` | `MiSTer.synchs_pol` (sha256 30ec72e9…): SYNC_HS + polaridad + AVI VIC 0. **Funciona con todos los modos.** |
| `F:\MiSTer.no_ok` | `MiSTer.stock_avi` (d2947f39…): los modos VIC 0 no van |
| `F:\MiSTer.orig_syncde` | Main original de teiram (90f4d90f…) |
| `F:\menu.rbf` | `menu_reconf_bcast.rbf` (535a9656…): X89_Y1 reconfigurable. **Todos los modos.** |
| `F:\menu.rbf.x89` | `menu_reconf_x89.rbf` (6cd08812…): X89_Y1 reconfigurable, C solo en el contador 5 |
| `F:\menu.rbf.fixpll` | `menu_fixpll.rbf` (8bd491f5…): X0_Y32, 720p fijo |
| `F:\menu.rbf.orig` | Menu estándar (X0_Y1): sin HDMI en esta placa |
| `F:\_Computer\PCXT_reconf_fixpll.rbf` | PCXT fixpll con la configuración del Menu (X89_Y1 reconfigurable, C en los 18 contadores, `pll_system` en X0_Y74; sha256 2abec5f7…). **Probado en la placa el 26/11/2026: todo funciona.** |
| `F:\_Computer\PCXT_splash_fixpll.rbf` | PCXT fixpll, 720p fijo |
| `F:\_Computer\PCXT_20261125b_ch96.rbf` | PCXT estándar (X0_Y1): sin HDMI en esta placa |
| `F:\_Computer\PCAT286_fixpll.rbf` | PCAT fixpll, 720p fijo |
| `F:\MiSTer.ini` | `debug=1`, `direct_video=0`, `video_mode=6` (copias: `.r46`, `.orig_1080p`, `.bak`) |

## Preguntas abiertas

- ¿Hace falta de verdad escribir C en los 18 contadores, o bastaría el contador 5
  (`menu_reconf_x89`) ahora que Main configura bien el TDA19988? No se ha vuelto a
  probar x89 con `MiSTer.synchs_pol`.
- ¿Qué índice físico tiene X89_Y5_N1 en su bloque? Sabiéndolo, se podría escribir
  solo en ese contador y dejar libre el resto del bloque.
- ¿Por qué el modo SYNC_DE solo funciona en esta placa con los modos de VIC CEA?
- Llevar al PCAT la misma configuración que el PCXT (`PCXT_reconf_fixpll` ya
  funciona en la placa).
- ¿Los modos VIC 0 fallan también en placas sanas con el Main de teiram? Si es así,
  el parche 0003 interesaría al port en general.

## Ficheros

- Cambios de FPGA para esta placa: rama `ch96-placa-aitor` (revisión estándar
  `PCXT_ch96`). Parche de Main: `platform/ch96/main/`.
- Bitstreams y parches de prueba: `platform/ch96/hdmi_test/` (sin seguimiento en
  git). Parches de Main de prueba en `main_avi/`.
- Copias de compilación en WSL: `~/ch96test/` (`Menu_reconf_bcast`,
  `Menu_reconf_x89`, `Menu_fixpll`, ...).
- Copias de seguridad:
  - `D:\Backups\fixed_version_01`: imagen completa de la tarjeta de 4 GB y sus
    ficheros, con `copiar_sd.ps1` y `restaurar_sd.ps1`.
  - `D:\Backups\fixed_version_01\sd_cambios_20261125`: ficheros de la tarjeta
    sustituidos durante las pruebas.
  - `D:\Backups\Chameleon96_SD_original_20261123`: la tarjeta original de 15,5 GB.
