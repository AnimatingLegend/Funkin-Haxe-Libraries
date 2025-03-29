package json.util;

import json.JSONData;

class ArrayUtil {
    /**
     * Return the list of items which are present in `list` but not in `subtract`.
     * TODO: There should be a `thx.core` function for this.
     * @param list The list of items
     * @param subtract The list of items to subtract
     * @return A list of items which are present in `list` but not in `subtract`.
     */
    public static function subtract<T>(list:Array<T>, subtract:Array<T>):Array<T> {
      return list.filter((item) -> {
        var contains = ArrayUtil.containsExact(subtract, item, thx.Dynamics.equals);
        return !contains;
      });
    }

  /**
   * Return true only if both arrays contain the same elements (possibly in a different order).
   * @param a The first array to compare.
   * @param b The second array to compare.
   * @return Weather both arrays contain the same elements.
   */
   public static function equalsUnordered<T>(a:Array<T>, b:Array<T>):Bool
    {
      if (a.length != b.length) return false;
      for (element in a)
      {
        if (!ArrayUtil.containsExact(b, element, thx.Dynamics.equals)) return false;
      }
      for (element in b)
      {
        if (!ArrayUtil.containsExact(a, element, thx.Dynamics.equals)) return false;
      }
      return true;
    }

    /**
     * Return the list of items which are present in both `list` and `intersect`.
     * @param list 
     * @param intersect 
     * @return
     */
    public static function intersect<T>(list:Array<T>, intersect:Array<T>):Array<T> {
      return list.filter((item) -> {
        var contains = ArrayUtil.containsExact(intersect, item, thx.Dynamics.equals);
        return contains;
      });
    }

    /**
     * Check if an array contains an item using a custom equality function.
     * @param array The array to search.
     * @param item The item to search for.
     * @param equals A function to compare two items for equality.
     * @return True if the item is found in the array, false otherwise.
     */
    private static function containsExact<T>(array:Array<T>, item:T, equals:Dynamic->Dynamic->Bool):Bool {
        for (element in array) {
            if (equals(element, item)) {
                return true;
            }
        }
        return false;
    }
}