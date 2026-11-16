# Política de privacitat

*Última actualització: 2026-11-16. S'aplica a Diapo per a Android i iOS, en totes les versions.*

Diapo és una càmera de pel·lícula: tries una pel·lícula, la veus en directe al visor i dispares. És gratuïta, funciona sense connexió i tot el que fa passa al teu dispositiu. Aquesta política explica en poques paraules quines dades es tracten, quines no i quins drets tens.

## Qui és el responsable

Responsable del tractament: Daniel Mont Ferrandiz. Contacte: diapo@mainshai.com.

A la pràctica, el responsable no rep cap dada teva: l'app no es comunica amb ningú, llevat de demanar a la botiga la seva finestra de valoració (vegeu «Valoracions a la botiga»), i aquesta petició no porta dades teves. Ho indiquem perquè sàpigues a qui adreçar-te.

## Quines dades es tracten i quines no

Tot el tractament passa al teu dispositiu, dins de l'app, i el decideixes tu.

| Dades | Per a què | On es queden |
| --- | --- | --- |
| Imatge de la càmera | Mostrar el visor amb la pel·lícula aplicada i fer la foto | En memòria mentre fas servir la càmera. Les fotos que fas es desen a la teva galeria (Android: carpeta `Pictures/Diapo`; iOS: un àlbum propi) a resolució completa i sense marca d'aigua. |
| Original sense pel·lícula (opcional) | Si actives «Desa també l'original», conservar a més la foto tal com la va fer la càmera | A la teva galeria, a la carpeta `Pictures/Diapo/Originales`. Ve desactivat. |
| Metadades de la foto (EXIF) | Que la foto conservi la data i les dades de la càmera (model, exposició, obertura, ISO), com qualsevol foto del mòbil | Dins del fitxer de la foto, a la teva galeria. La ubicació només s'escriu si actives «Desa la ubicació» (fila següent). Si no, l'app no l'escriu i, si la foto d'origen porta coordenades GPS (per exemple, una foto que importes), se'n treuen. |
| Ubicació (opcional) | Si actives «Desa la ubicació», anotar a cada foto el lloc on la vas fer, com fa la càmera del mòbil | L'app demana la posició al sistema d'ubicació del mòbil (GPS, o xarxes wifi i antenes properes) només mentre el visor és obert a la pantalla, mai en segon pla, i l'escriu a les metadades de la foto (i del seu original, si el deses), a la teva galeria. Com calcula el sistema aquesta posició depèn dels ajustos d'ubicació del teu mòbil, no de l'app. Si el mòbil no dona una posició recent, la foto es desa sense ubicació. En un carret sense revelar, les coordenades es guarden xifrades amb la foto fins al revelat. Si importes fotos amb l'opció activada, es conserven les coordenades que ja portava la foto; l'app no hi afegeix la teva posició. Ve desactivat. Tingues en compte que qui rebi una foto amb ubicació pot veure on es va fer. |
| Registre de les teves fotos | Mostrar la teva galeria dins de l'app: quines fotos vas fer, amb quina pel·lícula, en quina data i en quin carret | En una base de dades a l'emmagatzematge privat de l'app. Hi guarda la referència a cada foto, no una còpia. |
| Fotos d'un carret sense revelar | Guardar-les fins que el carret es reveli, també en el mode d'un sol ús | Xifrades (AES-256) a l'emmagatzematge privat de l'app, que cap altra app no pot llegir, amb la clau protegida pel magatzem segur del sistema. Quan el carret es revela passen a la teva galeria i s'esborren de l'emmagatzematge xifrat. Mai no hi arriben abans. |
| Fotos que importes | Aplicar-hi una pel·lícula, si tries «Revela fotos del mòbil» | Les tries tu al selector de fotos del sistema, i l'app només rep aquestes. Es copien un moment a la seva memòria cau per processar-les i la còpia s'esborra després. El resultat es desa a la teva galeria com una foto nova; l'original no es toca. |
| Configuració | Recordar les teves preferències (reixeta, nivell, sons, estil de data, idioma, tema, pel·lícula per defecte) i els ajustos fins de cada pel·lícula | A l'emmagatzematge privat de l'app. Si fas servir «Exporta els ajustos», també se'n desa una còpia en un fitxer, al lloc que triïs amb el selector del sistema; la còpia no conté fotos ni ubicacions. Importar una còpia no activa mai la ubicació ni l'original. |
| Inclinació del mòbil | Dibuixar el nivell de l'horitzó al visor, si l'actives | Es llegeix de l'acceleròmetre mentre el visor és obert i no es guarda. Ve desactivat. |

El que l'app **no fa**:

- No té comptes ni registre, i no et demana cap dada personal.
- No es connecta a internet. Les versions publicades no declaren el permís de xarxa d'Android (`INTERNET`), de manera que no poden connectar-se a internet. El codi de l'app és obert (https://github.com/dferrandizmont/diapo), així que qualsevol ho pot comprovar al seu manifest d'Android. No hi ha analítica, informes d'errors, rastrejadors ni publicitat.
- No fa servir el micròfon. Només fa servir la ubicació si actives «Desa la ubicació», i mai en segon pla.
- No recorre la teva galeria: només veu les fotos que ella mateixa ha desat i les que tries en importar.
- No comparteix dades amb ningú. Si toques Comparteix, la foto es lliura a l'app que triïs mitjançant el menú del sistema; a partir d'aquí s'aplica la política d'aquella app. Si valores l'app, la teva valoració la rep la botiga directament, no nosaltres.

## Permisos i per a què serveixen

- **Càmera:** només per mostrar el visor i fer fotos. Sense aquest permís la càmera no pot funcionar.
- **Ubicació (opcional):** només es demana quan actives «Desa la ubicació». Pots concedir la ubicació aproximada en lloc de l'exacta, i aleshores les fotos porten una posició aproximada. L'app no la fa servir mai en segon pla. Si retires el permís, deixa de desar la ubicació.
- **Galeria:** per desar les fotos. A Android 10 o superior no cal cap permís: es desen a través del magatzem multimèdia del sistema, i l'app només pot veure i esborrar les fotos que ella mateixa ha desat. A Android 8 i 9 es demana el permís d'emmagatzematge clàssic, per escriure les fotos i tornar a llegir les seves. Aquest permís dona accés tècnic a tot l'emmagatzematge compartit, però l'app només escriu i llegeix la seva pròpia carpeta.
- **Importar fotos:** no necessita cap permís. Fa servir el selector de fotos del sistema, que només lliura a l'app les fotos que tries.
- **Notificacions:** per avisar-te que el carret és a punt per revelar. Són notificacions locals, programades per l'app al teu dispositiu; no hi ha cap servei de notificacions extern. Si les rebutges, no rebràs l'avís, però podràs revelar el carret des de l'app quan sigui a punt.
- **Executar en iniciar (Android):** per tornar a programar l'avís del carret si reinicies el mòbil. No fa res més.

## Valoracions a la botiga

De tant en tant, després de revelar el teu primer carret o de compartir un full de contactes, Diapo pot demanar a la botiga (Google Play o, a l'iPhone, l'App Store) que et mostri la seva finestra per valorar l'app. És la botiga qui decideix si la mostra, i l'app no ho demana més de tres vegades. També pots obrir la fitxa de Diapo a la botiga des de Configuració › Quant a › «Valora Diapo». Per fer-ho, a Android l'app inclou la biblioteca de valoracions de Google Play (Play Core) i les biblioteques dels serveis de Google Play en què es basa; a l'iPhone fa servir la funció del sistema.

Diapo només indica a la botiga de quina app es tracta: no li passa les teves fotos ni cap altra dada teva, i no sap si has valorat ni què has escrit. La finestra la mostra l'app de la botiga, que és la que es connecta a internet; Diapo continua sense permís de xarxa. La teva puntuació i la teva ressenya les escrius en aquesta finestra i les rep Google o Apple, amb el teu compte de la botiga i segons les seves condicions. Les pots esborrar des del teu compte de la botiga.

Per decidir quan preguntar, l'app desa al seu emmagatzematge privat quin dia la vas obrir per primera vegada, quants dies diferents l'has obert, quantes vegades ha demanat la valoració i quan i amb quina versió ho va fer l'última vegada. Aquests comptadors no surten del mòbil: no van a la còpia de configuració que exportes ni a les còpies de seguretat del sistema, de les quals Diapo exclou les seves dades privades (vegeu «Còpies de seguretat»), i s'esborren en desinstal·lar l'app o esborrar-ne les dades.

## Esborrar fotos

Si esborres una foto des de la galeria de l'app, s'esborra també de la galeria del sistema, i amb ella el seu original si el vas desar; si no es pot esborrar, l'app t'avisa que continua a la carpeta `Originales`. Android et pot demanar que ho confirmis. Les fotos que l'app no ha desat no es poden esborrar des de l'app.

## Conservació i esborrat

Les teves fotos són a la teva galeria i les gestiones tu. La configuració, el registre de les teves fotos i les fotos de carrets sense revelar viuen a l'emmagatzematge privat de l'app. Si desinstal·les l'app o n'esborres les dades, tot això es perd i **les fotos de carrets sense revelar es perden sense possibilitat de recuperar-les**. Les fotos ja revelades o ja desades a la galeria no es toquen.

Si una foto no es pot acabar de desar (per exemple, perquè l'app es va tancar a mig procés), es queda a la memòria cau privada de l'app i es torna a intentar la propera vegada que l'obris. Després de tres intents ja no es torna a provar i el fitxer s'hi queda fins que esborris la memòria cau o les dades de l'app. Durant la captura i el revelat d'un carret hi ha una còpia temporal sense xifrar en aquesta memòria cau, que s'esborra en acabar.

## Còpies de seguretat

Les fotos de la teva galeria segueixen les còpies de seguretat que tinguis configurades al dispositiu (Google Fotos, iCloud o altres); això ho decideixes tu, no l'app. Les dades privades de l'app (configuració, registre de fotos, comptadors de valoració i fotos de carrets sense revelar amb la seva clau) queden excloses de les còpies de seguretat al núvol i de la transferència a un mòbil nou: la clau només existeix en aquest dispositiu, de manera que en un mòbil nou l'app comença de zero.

## Base jurídica

L'únic tractament passa al teu dispositiu, per decisió teva, quan fas servir l'app. En els termes del Reglament (UE) 2016/679, Reglament General de Protecció de Dades (RGPD), i de la Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los derechos digitales (Llei orgànica de protecció de dades i garantia dels drets digitals, LOPDGDD), el responsable no recull, emmagatzema ni accedeix a dades personals teves.

## Els teus drets

Tens dret a accedir a les teves dades, rectificar-les, suprimir-les, limitar-ne el tractament o oposar-t'hi, i a la portabilitat. Com que el responsable no té cap dada teva, no pot atendre aquestes sol·licituds: tot és al teu dispositiu i ho controles directament (esborrar fotos des de la galeria, esborrar les dades de l'app, desinstal·lar, desactivar «Desa la ubicació» o retirar el permís; la ubicació ja escrita en una foto s'hi queda fins que esborris la foto). Si tens dubtes, escriu a diapo@mainshai.com. Els drets sobre una valoració publicada s'exerceixen davant la botiga (Google o Apple).

Si consideres que els teus drets no es respecten, pots reclamar davant l'Agencia Española de Protección de Datos (Agència Espanyola de Protecció de Dades, AEPD), www.aepd.es, o davant l'autoritat de control del teu país.

## Menors

L'app no està dirigida a menors, però sabem que moltes famílies fotografien els seus fills. Per això ho diem sense embuts: les fotos que fas no surten del teu dispositiu; l'app no les analitza ni les envia enlloc. Un cop a la teva galeria, depenen dels permisos que donis a altres apps i de les teves còpies de seguretat. No recollim dades de ningú, menors inclosos. Si actives «Desa la ubicació», recorda que la foto porta el lloc on es va fer quan la comparteixes.

## Canvis

Si l'app canvia de manera que afecti aquesta política (per exemple, si algun dia enviés informes d'errors o incorporés publicitat), l'actualitzarem abans de publicar aquella versió i ho indicarem a les notes de la versió. La versió vigent és sempre a l'app i a diapo.mainshai.com.

## Contacte

Daniel Mont Ferrandiz · diapo@mainshai.com
