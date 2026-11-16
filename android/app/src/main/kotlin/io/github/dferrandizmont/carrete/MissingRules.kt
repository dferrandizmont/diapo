package io.github.dferrandizmont.carrete

/** The rules that decide when a photo is reported as gone (see `MediaChannel.missingImages`). */
object MissingRules {
    /**
     * Android 8-9 keep photos as files. One is gone only when the storage is
     * mounted, the album folder can be read and the file is not in it: with
     * the card out, or the folder unreadable, nothing may be reported.
     */
    fun fileIsMissing(storageMounted: Boolean, albumReadable: Boolean, fileExists: Boolean): Boolean =
        storageMounted && albumReadable && !fileExists

    /** The selection that finds the media store rows [ids]. */
    fun idSelection(ids: Collection<Long>): String = "_id IN (${ids.joinToString(",")})"
}
