# Política de privacidad

*Última actualización: 2026-11-16. Se aplica a Diapo para Android e iOS, en todas sus versiones.*

Diapo es una cámara de película: eliges una película, la ves en directo en el visor y disparas. Es gratuita, funciona sin conexión y todo lo que hace ocurre en tu dispositivo. Esta política explica en pocas palabras qué datos se tratan, cuáles no y qué derechos tienes.

## Quién es el responsable

Responsable del tratamiento: Daniel Mont Ferrandiz. Contacto: diapo@mainshai.com.

En la práctica, el responsable no recibe ningún dato tuyo: la app no se comunica con nadie, salvo para pedirle a la tienda su ventana de valoración (ver «Valoraciones en la tienda»), y esa petición no lleva datos tuyos. Lo indicamos para que sepas a quién dirigirte.

## Qué datos se tratan y cuáles no

Todo el tratamiento ocurre en tu dispositivo, dentro de la app, y lo decides tú.

| Datos | Para qué | Dónde se quedan |
| --- | --- | --- |
| Imagen de la cámara | Mostrar el visor con la película aplicada y tomar la foto | En memoria mientras usas la cámara. Las fotos que haces se guardan en tu galería (Android: carpeta `Pictures/Diapo`; iOS: un álbum propio) a resolución completa y sin marca de agua. |
| Original sin película (opcional) | Si activas «Guardar también el original», conservar además la foto tal como la tomó la cámara | En tu galería, en la carpeta `Pictures/Diapo/Originales`. Viene desactivado. |
| Metadatos de la foto (EXIF) | Que la foto conserve la fecha y los datos de la cámara (modelo, exposición, apertura, ISO), como cualquier foto del móvil | Dentro del archivo de la foto, en tu galería. La ubicación solo se escribe si activas «Guardar la ubicación» (fila siguiente). Si no, la app no la escribe y, si la foto de origen trae coordenadas GPS (por ejemplo, una foto que importas), se quitan. |
| Ubicación (opcional) | Si activas «Guardar la ubicación», anotar en cada foto el lugar donde la hiciste, como hace la cámara del móvil | La app pide la posición al sistema de ubicación del móvil (GPS, o redes wifi y antenas cercanas) solo mientras el visor está abierto en pantalla, nunca en segundo plano, y la escribe en los metadatos de la foto (y de su original, si lo guardas), en tu galería. Cómo calcula el sistema esa posición depende de los ajustes de ubicación de tu móvil, no de la app. Si el móvil no da una posición reciente, la foto se guarda sin ubicación. En un carrete sin revelar, las coordenadas se guardan cifradas junto a la foto hasta el revelado. Si importas fotos con la opción activada, se conservan las coordenadas que ya traía la foto; la app no les añade tu posición. Viene desactivado. Ten en cuenta que quien reciba una foto con ubicación puede ver dónde se hizo. |
| Registro de tus fotos | Mostrar tu galería dentro de la app: qué fotos hiciste, con qué película, en qué fecha y en qué carrete | En una base de datos en el almacenamiento privado de la app. Guarda la referencia a cada foto, no una copia. |
| Fotos de un carrete sin revelar | Guardarlas hasta que el carrete se revele, también en el modo desechable | Cifradas (AES-256) en el almacenamiento privado de la app, que ninguna otra app puede leer, con la clave protegida por el almacén seguro del sistema. Al revelar el carrete pasan a tu galería y se borran del almacenamiento cifrado. Nunca llegan a la galería antes. |
| Fotos que importas | Aplicarles una película, si eliges «Revelar fotos del móvil» | Las eliges tú en el selector de fotos del sistema, y la app solo recibe esas. Se copian un momento a su caché para procesarlas y la copia se borra después. El resultado se guarda en tu galería como una foto nueva; la original no se toca. |
| Ajustes | Recordar tus preferencias (cuadrícula, nivel, sonidos, estilo de fecha, idioma, tema, película por defecto) y los ajustes finos de cada película | En el almacenamiento privado de la app. Si usas «Exportar ajustes», se guarda además una copia en un archivo, en el sitio que elijas con el selector del sistema; la copia no contiene fotos ni ubicaciones. Importar una copia nunca activa la ubicación ni el original. |
| Inclinación del móvil | Dibujar el nivel del horizonte en el visor, si lo activas | Se lee del acelerómetro mientras el visor está abierto y no se guarda. Viene desactivado. |

Lo que la app **no hace**:

- No tiene cuentas ni registro, y no pide ningún dato personal.
- No se conecta a internet. Las versiones publicadas no declaran el permiso de red de Android (`INTERNET`), así que no pueden conectarse a internet. El código de la app es abierto (https://github.com/dferrandizmont/diapo), así que cualquiera puede comprobarlo en su manifiesto de Android. No hay analítica, informes de errores, rastreadores ni publicidad.
- No usa el micrófono. Solo usa la ubicación si activas «Guardar la ubicación», y nunca en segundo plano.
- No recorre tu galería: solo ve las fotos que ella misma ha guardado y las que tú eliges al importar.
- No comparte datos con nadie. Si tocas Compartir, la foto se entrega a la app que elijas mediante el menú del sistema; a partir de ahí se aplica la política de esa app. Si valoras la app, tu valoración la recibe la tienda directamente, no nosotros.

## Permisos y para qué sirven

- **Cámara:** solo para mostrar el visor y hacer fotos. Sin este permiso la cámara no puede funcionar.
- **Ubicación (opcional):** solo se pide cuando activas «Guardar la ubicación». Puedes conceder la ubicación aproximada en lugar de la exacta, y entonces las fotos llevan una posición aproximada. La app no la usa nunca en segundo plano. Si retiras el permiso, deja de guardar la ubicación.
- **Galería:** para guardar las fotos. En Android 10 o superior no hace falta permiso: se guardan a través del almacén multimedia del sistema, y la app solo puede ver y borrar las fotos que ella misma ha guardado. En Android 8 y 9 se pide el permiso de almacenamiento clásico, para escribir las fotos y volver a leer las suyas. Ese permiso da acceso técnico a todo el almacenamiento compartido, pero la app solo escribe y lee su propia carpeta.
- **Importar fotos:** no necesita permiso. Usa el selector de fotos del sistema, que solo entrega a la app las fotos que tú eliges.
- **Notificaciones:** para avisarte de que tu carrete está listo para revelar. Son notificaciones locales, programadas por la app en tu dispositivo; no hay ningún servicio de notificaciones externo. Si las rechazas, no recibirás el aviso, pero podrás revelar el carrete desde la app cuando esté listo.
- **Ejecutar al iniciar (Android):** para volver a programar el aviso del carrete si reinicias el móvil. No hace nada más.

## Valoraciones en la tienda

De vez en cuando, después de revelar tu primer carrete o de compartir una hoja de contactos, Diapo puede pedirle a la tienda (Google Play o, en iPhone, la App Store) que te muestre su ventana para valorar la app. Es la tienda quien decide si la enseña, y la app no lo pide más de tres veces. También puedes abrir la ficha de Diapo en la tienda desde Ajustes › Acerca de › «Valorar Diapo». Para eso, en Android la app incluye la biblioteca de valoraciones de Google Play (Play Core) y las bibliotecas de los servicios de Google Play en las que se apoya; en iPhone usa la función del sistema.

Diapo solo le indica a la tienda de qué app se trata: no le pasa tus fotos ni ningún otro dato tuyo, y no sabe si has valorado ni qué has escrito. La ventana la muestra la app de la tienda, que es la que se conecta a internet; Diapo sigue sin permiso de red. Tu puntuación y tu reseña las escribes en esa ventana y las recibe Google o Apple, con tu cuenta de la tienda y según sus condiciones. Puedes borrarlas desde tu cuenta de la tienda.

Para decidir cuándo preguntar, la app guarda en su almacenamiento privado qué día la abriste por primera vez, en cuántos días distintos la has abierto, cuántas veces ha pedido la valoración y cuándo y con qué versión lo hizo la última vez. Esos contadores no salen del móvil: no van en la copia de ajustes que exportas ni en las copias de seguridad del sistema, de las que Diapo excluye sus datos privados (ver «Copias de seguridad»), y se borran al desinstalar la app o borrar sus datos.

## Borrar fotos

Si borras una foto desde la galería de la app, se borra también de la galería del sistema, y con ella su original si lo guardaste; si no se puede borrar, la app te avisa de que sigue en la carpeta `Originales`. Android puede pedirte que lo confirmes. Las fotos que la app no ha guardado no se pueden borrar desde ella.

## Conservación y borrado

Tus fotos están en tu galería y las gestionas tú. Los ajustes, el registro de tus fotos y las fotos de carretes sin revelar viven en el almacenamiento privado de la app. Si desinstalas la app o borras sus datos, todo eso se pierde y **las fotos de carretes sin revelar se pierden sin posibilidad de recuperarlas**. Las fotos ya reveladas o ya guardadas en la galería no se tocan.

Si una foto no se puede terminar de guardar (por ejemplo, porque la app se cerró a mitad), se queda en la caché privada de la app y se reintenta la próxima vez que la abras. Tras tres intentos deja de reintentarse y el archivo permanece ahí hasta que borres la caché o los datos de la app. Durante la captura y el revelado de un carrete existe una copia temporal sin cifrar en esa caché, que se borra al terminar.

## Copias de seguridad

Las fotos de tu galería siguen las copias de seguridad que tengas configuradas en el dispositivo (Google Fotos, iCloud u otras); eso lo decides tú, no la app. Los datos privados de la app (ajustes, registro de fotos, contadores de valoración y fotos de carretes sin revelar con su clave) quedan excluidos de las copias de seguridad en la nube y de la transferencia a un móvil nuevo: la clave solo existe en este dispositivo, así que en un móvil nuevo la app empieza de cero.

## Base jurídica

El único tratamiento ocurre en tu dispositivo, por tu decisión, al usar la app. En los términos del Reglamento (UE) 2016/679, Reglamento General de Protección de Datos (RGPD), y de la Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los derechos digitales (LOPDGDD), el responsable no recoge, almacena ni accede a datos personales tuyos.

## Tus derechos

Tienes derecho a acceder a tus datos, rectificarlos, suprimirlos, limitar u oponerte a su tratamiento y a su portabilidad. Como el responsable no tiene ningún dato tuyo, no puede atender esas solicitudes: todo está en tu dispositivo y lo controlas directamente (borrar fotos desde la galería, borrar los datos de la app, desinstalar, desactivar «Guardar la ubicación» o retirar el permiso; la ubicación ya escrita en una foto sigue en ella hasta que borres la foto). Si tienes dudas, escribe a diapo@mainshai.com. Los derechos sobre una valoración publicada se ejercen ante la tienda (Google o Apple).

Si consideras que tus derechos no se respetan, puedes reclamar ante la Agencia Española de Protección de Datos (AEPD), www.aepd.es, o ante la autoridad de control de tu país.

## Menores

La app no está dirigida a menores, pero sabemos que muchas familias fotografían a sus hijos. Por eso lo decimos sin rodeos: las fotos que haces no salen de tu dispositivo; la app no las analiza ni las envía a ningún sitio. Una vez en tu galería, dependen de los permisos que tú des a otras apps y de tus copias de seguridad. No recogemos datos de nadie, menores incluidos. Si activas «Guardar la ubicación», recuerda que la foto lleva el lugar donde se hizo cuando la compartes.

## Cambios

Si la app cambia de forma que afecte a esta política (por ejemplo, si algún día enviara informes de errores o incluyera publicidad), la actualizaremos antes de publicar esa versión y lo indicaremos en las notas de la versión. La versión vigente está siempre en la app y en diapo.mainshai.com.

## Contacto

Daniel Mont Ferrandiz · diapo@mainshai.com
