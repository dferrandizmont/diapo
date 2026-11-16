package android.util;

/** Test-only value holder: android.jar stubs do not initialize Pair's fields.
 * AndroidX ExifInterface uses this holder while parsing attribute types; its
 * JPEG parsing, rational encoding and file IO remain the real implementation.
 */
public final class Pair<F, S> {
    public final F first;
    public final S second;

    public Pair(F first, S second) {
        this.first = first;
        this.second = second;
    }

    public static <F, S> Pair<F, S> create(F first, S second) {
        return new Pair<>(first, second);
    }
}
