package io.github.dferrandizmont.carrete

/** The rule that decides which original may go with a deleted photo (see `MediaChannel.deleteImage`). */
object OriginalRules {
    /**
     * An original is deleted, or asked about, only when this app wrote it: its
     * owner package is ours. A foreign original, or one whose owner is not
     * known, is never touched: the photo goes and the original stays.
     */
    fun isOurs(ownerPackage: String?, ourPackage: String): Boolean =
        ownerPackage != null && ownerPackage == ourPackage
}
